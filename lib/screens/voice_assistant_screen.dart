import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/constants.dart';
import '../services/firebase_service.dart';

/// Shows the Voice Assistant overlay as a modal bottom sheet.
Future<void> showVoiceAssistant(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Color(AppColors.surface).withValues(alpha: 0.85),
    builder: (context) => const VoiceAssistantSheet(),
  );
}

class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key});

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet>
    with TickerProviderStateMixin {
  // ─── State ───
  _VoiceState _voiceState = _VoiceState.idle;
  String _transcriptText = '';
  String _feedbackText = '';
  bool _isCommandProcessed = false;

  // ─── Animations ───
  late AnimationController _entryController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _waveController;

  late AnimationController _orbController;

  // ─── Speech To Text ───
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  double _soundLevel = 0.0;
  Timer? _listeningTimeoutTimer;

  // ─── Text To Speech ───
  final FlutterTts _tts = FlutterTts();

  // ─── Audio Player ───
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initTts();

    // Entry animation
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    // Mic pulse
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sound wave
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Orb ring rotation
    _orbController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _entryController.forward();
    _initSpeech();
  }

  void _initTts() async {
    try {
      // Set Google TTS engine on Android for natural Indonesian voice accent
      try {
        await _tts.setEngine('com.google.android.tts');
      } catch (e) {
        print('Google TTS engine not available, using default engine: $e');
      }

      // Set volume to maximum
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);

      // Enforce Indonesian language
      await _tts.setLanguage('id-ID');
    } catch (e) {
      print('TTS initialize exception: $e');
    }
  }

  void _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (val) {
          print('Speech error: ${val.errorMsg}');
          if (val.errorMsg == 'error_speech_timeout' || val.errorMsg == 'error_no_match') {
            try {
              _audioPlayer.play(AssetSource('sounds/error.wav'));
            } catch (e) {
              print('Gagal memutar bunyi error: $e');
            }
          }
          if (mounted) {
            setState(() {
              _voiceState = _VoiceState.idle;
              _transcriptText = '';
              if (val.errorMsg == 'error_speech_timeout' || val.errorMsg == 'error_no_match') {
                _feedbackText = 'Suara tidak terdengar';
                _tts.speak('Suara tidak terdengar');
              } else {
                _feedbackText = 'Gagal mengenali suara, coba lagi';
                _tts.speak('Gagal mengenali suara, silakan coba lagi');
              }
            });
          }
        },
        onStatus: (val) => print('Speech status: $val'),
      );
      if (mounted) {
        setState(() {
          _speechInitialized = available;
        });
      }
    } catch (e) {
      print('SpeechToText initialize exception: $e');
    }
  }

  void _startListening() async {
    if (!_speechInitialized) {
      setState(() {
        _transcriptText = 'Fitur suara tidak tersedia';
      });
      return;
    }

    try {
      _audioPlayer.play(AssetSource('sounds/start.wav'));
    } catch (e) {
      print('Gagal memutar bunyi awalan: $e');
    }

    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = Timer(const Duration(seconds: 9), () {
      if (mounted && _voiceState == _VoiceState.listening) {
        print("Speech timeout: tidak ada respon terdeteksi. Menghentikan...");
        _processVoiceCommand('');
      }
    });
    
    _isCommandProcessed = false;

    HapticFeedback.mediumImpact();
    setState(() {
      _voiceState = _VoiceState.listening;
      _transcriptText = 'Katakan perintah...';
      _feedbackText = '';
      _soundLevel = 0.0;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcriptText = '"${result.recognizedWords}"';
            });
            final recognizedWords = result.recognizedWords;
            if (_checkIfCommandIsMatched(recognizedWords)) {
              _stopListening();
              _processVoiceCommand(recognizedWords);
            } else if (result.finalResult) {
              _processVoiceCommand(recognizedWords);
            }
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
        localeId: 'id_ID', // Set default to Indonesian speech
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(
          onDevice: false,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
        ),
      );
    } catch (e) {
      try {
        await _audioPlayer.play(AssetSource('sounds/error.wav'));
      } catch (err) {
        print('Gagal memutar bunyi error: $err');
      }
      if (mounted) {
        setState(() {
          _voiceState = _VoiceState.idle;
          _transcriptText = 'Mendengarkan gagal';
          _soundLevel = 0.0;
        });
      }
    }
  }

  void _stopListening() async {
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;
    await _speech.stop();
    if (mounted && !_isCommandProcessed) {
      setState(() {
        _voiceState = _VoiceState.processing;
        _soundLevel = 0.0;
      });
    }
  }

  bool _checkIfCommandIsMatched(String command) {
    final cmd = command.toLowerCase().trim();
    if (cmd.isEmpty) return false;

    // Check if it is a general auto or manual mode change command
    final isAutoOrManualCmd = (cmd.contains('auto') || cmd.contains('otomatis') || cmd.contains('manual')) &&
        (cmd.contains('lampu') || cmd.contains('kipas'));

    // Aksi aktif/nyala
    final hasActive = cmd.contains('hidup') ||
        cmd.contains('nyala') ||
        cmd.contains('on') ||
        cmd.contains('buka') ||
        cmd.contains('aktif');

    // Aksi nonaktif/mati
    final hasInactive = cmd.contains('mati') ||
        cmd.contains('tutup') ||
        cmd.contains('off') ||
        cmd.contains('kunci') ||
        cmd.contains('nonaktif');

    if (!hasActive && !hasInactive && !isAutoOrManualCmd) return false;

    // Check device types
    final hasLampu = cmd.contains('lampu');
    final hasKipas = cmd.contains('kipas');
    final hasAlarm = cmd.contains('alarm') || cmd.contains('sirine') || cmd.contains('buzzer');
    final hasPintu = cmd.contains('pintu') || cmd.contains('gerbang') || cmd.contains('kunci');

    if (hasLampu) {
      final hasAuto = cmd.contains('auto') || cmd.contains('otomatis') || cmd.contains('manual');
      final hasMandi = cmd.contains('mandi');
      final hasTamu = cmd.contains('tamu') || cmd.contains('ruang tamu');
      final hasDapur = cmd.contains('dapur');
      final hasKamar = cmd.contains('kamar');

      // Jika ada kata mandi, tamu, dapur, atau auto -> langsung cocok secara parsial
      if (hasAuto || hasMandi || hasTamu || hasDapur) {
        return true;
      }

      // Jika hanya mengandung kata 'kamar' tanpa 'mandi', jangan potong mic di tengah jalan.
      // Kembalikan false agar mic terus merekam suara penuh (siapa tahu pengguna mau bilang 'kamar mandi').
      // Jika pengguna sudah selesai bicara, block finalResult di onResult yang akan mengeksekusi 'lampu kamar'.
      if (hasKamar && !hasMandi) {
        return false;
      }
    }

    if (hasKipas) {
      return true;
    }

    if (hasAlarm || hasPintu) {
      return true;
    }

    return false;
  }

  void _processVoiceCommand(String command) async {
    if (_isCommandProcessed) return;
    _isCommandProcessed = true;

    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = null;
    if (command.isEmpty) {
      try {
        _audioPlayer.play(AssetSource('sounds/error.wav'));
      } catch (e) {
        print('Gagal memutar bunyi error: $e');
      }
      if (mounted) {
        setState(() {
          _voiceState = _VoiceState.idle;
          _transcriptText = '';
          _feedbackText = 'Suara tidak terdengar';
        });
        _tts.speak('Suara tidak terdengar');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _voiceState = _VoiceState.processing;
        _transcriptText = '"$command"';
      });
    }

    final cmd = command.toLowerCase();
    String responseText = 'Perintah tidak dikenali';
    bool recognized = false;

    final currentState = FirebaseService().stateNotifier.value;

    // IoT Control Logic based on voice commands
    // 1. Direct Auto/Otomatis/Manual Mode command without needing active/inactive trigger keywords
    if ((cmd.contains('auto') || cmd.contains('otomatis') || cmd.contains('manual')) &&
        (cmd.contains('lampu') || cmd.contains('kipas'))) {
      // Determine target state (auto = true, manual = false)
      bool targetAutoState = true;
      if (cmd.contains('manual') ||
          cmd.contains('mati') ||
          cmd.contains('off') ||
          cmd.contains('nonaktif') ||
          cmd.contains('non-aktif')) {
        targetAutoState = false;
      }
      
      if (cmd.contains('lampu')) {
        final bool alreadyInState = ((currentState?.otomatisasi.modeAutoLampu ?? false) == targetAutoState);
        await FirebaseService().updateOtomatisasi('mode_auto_lampu', targetAutoState);
        responseText = targetAutoState
            ? (alreadyInState ? 'Mode auto lampu sudah aktif' : 'Mode auto lampu diaktifkan')
            : (alreadyInState ? 'Mode manual lampu sudah aktif' : 'Mode auto lampu dinonaktifkan, beralih ke manual');
        recognized = true;
      } else if (cmd.contains('kipas')) {
        final bool alreadyInState = ((currentState?.otomatisasi.modeAutoKipas ?? false) == targetAutoState);
        await FirebaseService().updateOtomatisasi('mode_auto_kipas', targetAutoState);
        responseText = targetAutoState
            ? (alreadyInState ? 'Mode auto kipas sudah aktif' : 'Mode auto kipas diaktifkan')
            : (alreadyInState ? 'Mode manual kipas sudah aktif' : 'Mode auto kipas dinonaktifkan, beralih ke manual');
        recognized = true;
      }
    } else if (cmd.contains('hidup') ||
        cmd.contains('nyala') ||
        cmd.contains('on') ||
        cmd.contains('buka') ||
        cmd.contains('aktif')) {
      if ((cmd.contains('auto') || cmd.contains('otomatis')) &&
          cmd.contains('lampu')) {
        final bool alreadyOn = currentState?.otomatisasi.modeAutoLampu ?? false;
        await FirebaseService().updateOtomatisasi('mode_auto_lampu', true);
        responseText = alreadyOn
            ? 'Mode auto lampu sudah aktif'
            : 'Mode auto lampu diaktifkan';
        recognized = true;
      } else if ((cmd.contains('auto') || cmd.contains('otomatis')) &&
          cmd.contains('kipas')) {
        final bool alreadyOn = currentState?.otomatisasi.modeAutoKipas ?? false;
        await FirebaseService().updateOtomatisasi('mode_auto_kipas', true);
        responseText = alreadyOn
            ? 'Mode auto kipas sudah aktif'
            : 'Mode auto kipas diaktifkan';
        recognized = true;
      } else if (cmd.contains('lampu') && cmd.contains('mandi')) {
        final bool alreadyOn = currentState?.perangkat.lampuKamarMandi ?? false;
        await FirebaseService().updatePerangkat('lampu_kamar_mandi', true);
        responseText = alreadyOn
            ? 'Lampu kamar mandi sudah menyala'
            : 'Lampu kamar mandi dinyalakan';
        recognized = true;
      } else if (cmd.contains('lampu') && cmd.contains('kamar')) {
        final bool alreadyOn = currentState?.perangkat.lampuKamar ?? false;
        await FirebaseService().updatePerangkat('lampu_kamar', true);
        responseText = alreadyOn
            ? 'Lampu kamar sudah menyala'
            : 'Lampu kamar dinyalakan';
        recognized = true;
      } else if (cmd.contains('lampu') &&
          (cmd.contains('tamu') || cmd.contains('ruang tamu'))) {
        final bool alreadyOn = currentState?.perangkat.lampuTamu ?? false;
        await FirebaseService().updatePerangkat('lampu_tamu', true);
        responseText = alreadyOn
            ? 'Lampu ruang tamu sudah menyala'
            : 'Lampu ruang tamu dinyalakan';
        recognized = true;
      } else if (cmd.contains('lampu') && cmd.contains('dapur')) {
        final bool alreadyOn = currentState?.perangkat.lampuDapur ?? false;
        await FirebaseService().updatePerangkat('lampu_dapur', true);
        responseText = alreadyOn
            ? 'Lampu dapur sudah menyala'
            : 'Lampu dapur dinyalakan';
        recognized = true;
      } else if (cmd.contains('kipas')) {
        final bool alreadyOn = currentState?.perangkat.kipasKamar ?? false;
        await FirebaseService().updatePerangkat('kipas_kamar', true);
        await FirebaseService().updatePerangkat('kecepatan_kipas', 255);
        responseText = alreadyOn
            ? 'Kipas kamar sudah menyala'
            : 'Kipas kamar dinyalakan';
        recognized = true;
      } else if (cmd.contains('alarm') ||
          cmd.contains('sirine') ||
          cmd.contains('buzzer')) {
        final bool alreadyOn = currentState?.perangkat.buzzerAlrm ?? false;
        await FirebaseService().updatePerangkat('buzzer_alrm', true);
        responseText = alreadyOn
            ? 'Alarm darurat sudah aktif'
            : 'Alarm darurat diaktifkan';
        recognized = true;
      } else if (cmd.contains('pintu') ||
          cmd.contains('gerbang') ||
          cmd.contains('kunci')) {
        final bool alreadyOpen =
            !(currentState?.perangkat.kunciPintuRfid ?? true);
        await FirebaseService().updatePerangkat(
          'kunci_pintu_rfid',
          false,
        ); // unlock
        responseText = alreadyOpen
            ? 'Pintu utama sudah dibuka'
            : 'Pintu utama dibuka';
        recognized = true;
      }
    } else if (cmd.contains('mati') ||
        cmd.contains('tutup') ||
        cmd.contains('off') ||
        cmd.contains('kunci') ||
        cmd.contains('nonaktif')) {
      if ((cmd.contains('auto') || cmd.contains('otomatis')) &&
          cmd.contains('lampu')) {
        final bool alreadyOff =
            !(currentState?.otomatisasi.modeAutoLampu ?? true);
        await FirebaseService().updateOtomatisasi('mode_auto_lampu', false);
        responseText = alreadyOff
            ? 'Mode auto lampu sudah mati'
            : 'Mode auto lampu dimatikan';
        recognized = true;
      } else if ((cmd.contains('auto') || cmd.contains('otomatis')) &&
          cmd.contains('kipas')) {
        final bool alreadyOff =
            !(currentState?.otomatisasi.modeAutoKipas ?? true);
        await FirebaseService().updateOtomatisasi('mode_auto_kipas', false);
        responseText = alreadyOff
            ? 'Mode auto kipas sudah mati'
            : 'Mode auto kipas dimatikan';
        recognized = true;
      } else if (cmd.contains('lampu') && cmd.contains('mandi')) {
        final bool alreadyOff =
            !(currentState?.perangkat.lampuKamarMandi ?? true);
        await FirebaseService().updatePerangkat('lampu_kamar_mandi', false);
        responseText = alreadyOff
            ? 'Lampu kamar mandi sudah mati'
            : 'Lampu kamar mandi dimatikan';
        recognized = true;
      } else if (cmd.contains('lampu') && cmd.contains('kamar')) {
        final bool alreadyOff = !(currentState?.perangkat.lampuKamar ?? true);
        await FirebaseService().updatePerangkat('lampu_kamar', false);
        responseText = alreadyOff
            ? 'Lampu kamar sudah mati'
            : 'Lampu kamar dimatikan';
        recognized = true;
      } else if (cmd.contains('lampu') &&
          (cmd.contains('tamu') || cmd.contains('ruang tamu'))) {
        final bool alreadyOff = !(currentState?.perangkat.lampuTamu ?? true);
        await FirebaseService().updatePerangkat('lampu_tamu', false);
        responseText = alreadyOff
            ? 'Lampu ruang tamu sudah mati'
            : 'Lampu ruang tamu dimatikan';
        recognized = true;
      } else if (cmd.contains('lampu') && cmd.contains('dapur')) {
        final bool alreadyOff = !(currentState?.perangkat.lampuDapur ?? true);
        await FirebaseService().updatePerangkat('lampu_dapur', false);
        responseText = alreadyOff
            ? 'Lampu dapur sudah mati'
            : 'Lampu dapur dimatikan';
        recognized = true;
      } else if (cmd.contains('kipas')) {
        final bool alreadyOff = !(currentState?.perangkat.kipasKamar ?? true);
        await FirebaseService().updatePerangkat('kipas_kamar', false);
        responseText = alreadyOff
            ? 'Kipas kamar sudah mati'
            : 'Kipas kamar dimatikan';
        recognized = true;
      } else if (cmd.contains('alarm') ||
          cmd.contains('sirine') ||
          cmd.contains('buzzer')) {
        final bool alreadyOff = !(currentState?.perangkat.buzzerAlrm ?? true);
        await FirebaseService().disarmAllAlarms();
        responseText = alreadyOff
            ? 'Alarm darurat sudah mati'
            : 'Alarm darurat dimatikan';
        recognized = true;
      } else if (cmd.contains('pintu') ||
          cmd.contains('gerbang') ||
          cmd.contains('kunci')) {
        final bool alreadyLocked =
            currentState?.perangkat.kunciPintuRfid ?? false;
        await FirebaseService().updatePerangkat(
          'kunci_pintu_rfid',
          true,
        ); // lock
        responseText = alreadyLocked
            ? 'Pintu utama sudah dikunci'
            : 'Pintu utama dikunci';
        recognized = true;
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _voiceState = recognized ? _VoiceState.success : _VoiceState.idle;
        _feedbackText = responseText;
      });
      _tts.speak(responseText);
    }
  }

  @override
  void dispose() {
    _listeningTimeoutTimer?.cancel();
    _entryController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _orbController.dispose();
    _speech.stop();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(AppColors.surfaceContainer).withValues(alpha: 0.7),
                  Color(AppColors.surface).withValues(alpha: 0.95),
                  Color(AppColors.surface),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding + 24, top: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── Drag Handle ───
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 28),
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Color(
                            AppColors.onSurfaceVariant,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                    ),

                    // ─── Sound Wave / Status Area ───
                    SizedBox(height: 100, child: _buildWaveArea()),

                    const SizedBox(height: 20),

                    // ─── Transcript Text ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _transcriptText.isNotEmpty
                          ? Padding(
                              key: ValueKey(_transcriptText),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                _transcriptText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(AppColors.onSurface),
                                  letterSpacing: -0.5,
                                  height: 1.3,
                                ),
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('empty-transcript'),
                              height: 32,
                            ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Feedback Text ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _feedbackText.isNotEmpty
                          ? Row(
                              key: ValueKey(_feedbackText),
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _voiceState == _VoiceState.success
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  color: _voiceState == _VoiceState.success
                                      ? Color(AppColors.secondaryContainer)
                                      : Colors.orangeAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _feedbackText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _voiceState == _VoiceState.success
                                        ? Color(
                                            AppColors.secondaryContainer,
                                          ).withValues(alpha: 0.85)
                                        : Colors.orangeAccent.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(
                              key: ValueKey('empty-feedback'),
                              height: 20,
                            ),
                    ),

                    const SizedBox(height: 32),

                    // ─── Mic Button ───
                    _buildMicButton(),

                    const SizedBox(height: 20),

                    // ─── Status Label ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusLabel,
                        key: ValueKey(_statusLabel),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(
                            AppColors.onSurfaceVariant,
                          ).withValues(alpha: 0.4),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _statusLabel {
    switch (_voiceState) {
      case _VoiceState.idle:
        return 'KETUK UNTUK BERBICARA';
      case _VoiceState.listening:
        return 'MENDENGARKAN';
      case _VoiceState.processing:
        return 'MEMPROSES';
      case _VoiceState.success:
        return 'SELESAI';
    }
  }

  // ─────────────────────────────────────────────────
  // Sound Wave Visualizer
  // ─────────────────────────────────────────────────
  Widget _buildWaveArea() {
    if (_voiceState == _VoiceState.idle) {
      return Center(
        child: Icon(
          Icons.mic_none_rounded,
          size: 48,
          color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.2),
        ),
      );
    }

    if (_voiceState == _VoiceState.success) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(9, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 5,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Color(AppColors.secondaryContainer).withValues(alpha: 0.3),
              ),
            ),
          );
        }),
      );
    }

    // Listening / Processing — animated wave bars
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(9, (index) {
            final phase = index / 9 * 2 * math.pi;
            final waveValue =
                (math.sin(_waveController.value * 2 * math.pi + phase) + 1) / 2;
                
            double amplitude = 1.0;
            if (_voiceState == _VoiceState.listening) {
              // Noise gate: jika soundLevel di bawah 2.0 dB, anggap hening (hanya detak baseline sangat tipis)
              if (_soundLevel < 2.0) {
                amplitude = 0.05;
              } else {
                // Skala suara aktif dari 2.0 dB ke 10.0 dB
                final clamped = _soundLevel.clamp(2.0, 10.0);
                amplitude = (clamped - 2.0) / 8.0;
                amplitude = amplitude.clamp(0.05, 1.0);
              }
            } else if (_voiceState == _VoiceState.processing) {
              amplitude = 0.20; // Gentle constant wave while thinking
            }

            final heightFactor = 0.08 + (waveValue * 0.92 * amplitude);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 5,
                height: 100 * heightFactor,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(AppColors.secondaryContainer),
                      Color(AppColors.secondaryContainer).withValues(alpha: 0.15),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(
                        AppColors.secondaryContainer,
                      ).withValues(alpha: 0.4 * waveValue),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // Glowing Mic Button
  // ─────────────────────────────────────────────────
  Widget _buildMicButton() {
    final isActive =
        _voiceState == _VoiceState.listening ||
        _voiceState == _VoiceState.processing;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (_voiceState == _VoiceState.success) {
          Navigator.of(context).pop();
        } else if (_voiceState == _VoiceState.listening) {
          _stopListening();
        } else if (_voiceState == _VoiceState.idle) {
          _startListening();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _orbController]),
        builder: (context, child) {
          return SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Outer ping ring (only when active) ──
                if (isActive)
                  AnimatedOpacity(
                    opacity: isActive ? 0.6 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(
                            AppColors.secondaryContainer,
                          ).withValues(alpha: _pulseAnimation.value * 0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // ── Rotating gradient ring ──
                if (isActive)
                  Transform.rotate(
                    angle: _orbController.value * 2 * math.pi,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color(AppColors.secondaryContainer),
                            Color(
                              AppColors.secondaryContainer,
                            ).withValues(alpha: 0.0),
                            Color(AppColors.primary).withValues(alpha: 0.2),
                            Color(
                              AppColors.secondaryContainer,
                            ).withValues(alpha: 0.0),
                            Color(AppColors.secondaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Core button ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.2),
                      radius: 1.0,
                      colors: [
                        Color(AppColors.surfaceContainerHigh),
                        Color(AppColors.surfaceContainer),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(
                          AppColors.secondaryContainer,
                        ).withValues(alpha: isActive ? _pulseAnimation.value : 0.15),
                        blurRadius: isActive ? 60 : 20,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      // Inner glow
                      if (isActive)
                        BoxShadow(
                          color: Color(
                            AppColors.secondaryContainer,
                          ).withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _voiceState == _VoiceState.success
                          ? Icon(
                              Icons.check_rounded,
                              key: const ValueKey('check'),
                              color: Color(AppColors.secondaryContainer),
                              size: 36,
                            )
                          : Icon(
                              Icons.mic_rounded,
                              key: const ValueKey('mic'),
                              color: Color(AppColors.secondaryContainer),
                              size: 40,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _VoiceState { idle, listening, processing, success }
