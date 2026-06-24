import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'widgets/header.dart';
import 'widgets/navbar.dart';
import 'widgets/floating_notification_banner.dart';
import 'screens/home_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/monitor_screen.dart';
import 'screens/security_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/settings_screen.dart';

import 'services/smarthome_service.dart';
import 'services/system_settings_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/climate_history_service.dart';
import 'models/device_model.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemSettingsService().init();
  await SmartHomeService().init();
  NotificationService().init();
  await ClimateHistoryService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: SystemSettingsService().activeAccent,
      builder: (context, accentColor, _) {
        return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Otter - Smart Home',
          theme: AppTheme.darkTheme,
          home: MainLayout(),
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            final mediaQueryData = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaleFactor: mediaQueryData.textScaleFactor * 0.9,
              ),
              child: Listener(
                onPointerDown: (_) => MainLayout.onUserInteraction?.call(),
                onPointerMove: (_) => MainLayout.onUserInteraction?.call(),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  static VoidCallback? onUserInteraction;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  AudioPlayer? _sirenPlayer;
  bool _isAlarmRunning = false;
  Timer? _alarmDebounceTimer;
  Timer? _autoLockTimer;
  bool _isLocked = true;

  @override
  void initState() {
    super.initState();
    MainLayout.onUserInteraction = _resetAutoLockTimer;
    SmartHomeService().stateNotifier.addListener(_onStateChanged);
    SystemSettingsService().enableAlarmSound.addListener(_onSettingsChanged);
    SystemSettingsService().enableVibration.addListener(_onSettingsChanged);
    SystemSettingsService().lockScreenTrigger.addListener(_onLockTriggered);
    
    // Set initial index based on defaultBootScreen
    final bootScreen = SystemSettingsService().defaultBootScreen.value;
    if (bootScreen == 'Perangkat') {
      _currentIndex = 1;
    } else if (bootScreen == 'Monitor') {
      _currentIndex = 2;
    } else if (bootScreen == 'Keamanan') {
      _currentIndex = 3;
    } else {
      _currentIndex = 0;
    }

    // Start auto-lock timer
    _resetAutoLockTimer();

    // Cek state awal — alarm mungkin sudah aktif sebelum listener ditambahkan
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStateChanged());
  }

  void _lockApp() {
    if (!mounted) return;
    setState(() {
      _isLocked = true;
    });
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      print("Error popping routes on lock: $e");
    }
  }

  void _onLockTriggered() {
    if (SystemSettingsService().lockScreenTrigger.value) {
      SystemSettingsService().lockScreenTrigger.value = false;
      _lockApp();
    }
  }

  @override
  void dispose() {
    if (MainLayout.onUserInteraction == _resetAutoLockTimer) {
      MainLayout.onUserInteraction = null;
    }
    SmartHomeService().stateNotifier.removeListener(_onStateChanged);
    SystemSettingsService().enableAlarmSound.removeListener(_onSettingsChanged);
    SystemSettingsService().enableVibration.removeListener(_onSettingsChanged);
    SystemSettingsService().lockScreenTrigger.removeListener(_onLockTriggered);
    _alarmDebounceTimer?.cancel();
    _autoLockTimer?.cancel();
    _stopAlarmFeedback();
    super.dispose();
  }

  void _resetAutoLockTimer() {
    _autoLockTimer?.cancel();
    if (_isLocked) return;

    final delayMinutes = SystemSettingsService().autoLockDelay.value;
    _autoLockTimer = Timer(Duration(milliseconds: (delayMinutes * 60 * 1000).toInt()), () {
      _lockApp();
    });
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    if (_isAlarmRunning) {
      _stopAlarmFeedback();
      final state = SmartHomeService().stateNotifier.value;
      final bool isAlarmActive = state != null && state.perangkat.buzzerAlrm;
      if (isAlarmActive) {
        _startAlarmFeedback();
      }
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    
    _alarmDebounceTimer?.cancel();
    _alarmDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final state = SmartHomeService().stateNotifier.value;
      final bool isAlarmActive = state != null && state.perangkat.buzzerAlrm;

      if (isAlarmActive && !_isAlarmRunning) {
        _startAlarmFeedback();
      } else if (!isAlarmActive && _isAlarmRunning) {
        _stopAlarmFeedback();
      }
    });
  }

  void _startAlarmFeedback() async {
    _isAlarmRunning = true;
    final settings = SystemSettingsService();

    // 1. Play siren sound
    if (settings.enableAlarmSound.value) {
      try {
        _sirenPlayer ??= AudioPlayer();
        
        // Terpisah try-catch agar jika setAudioContext error, play tetap berjalan
        try {
          await _sirenPlayer?.setAudioContext(AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gainTransient,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: const {
                AVAudioSessionOptions.mixWithOthers,
              },
            ),
          ));
        } catch (ctxError) {
          debugPrint("Gagal menyetel AudioContext (menggunakan default): $ctxError");
        }

        await _sirenPlayer?.setVolume(1.0);
        await _sirenPlayer?.setReleaseMode(ReleaseMode.loop);
        await _sirenPlayer?.play(AssetSource('sounds/siren.wav'));
        debugPrint("Sirine audio dimulai");
      } catch (e) {
        debugPrint("Gagal memutar audio sirine: $e");
      }
    }

    // 2. Trigger strong continuous vibration pattern (repeat: -1 = infinite)
    if (settings.enableVibration.value) {
      try {
        final bool hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) {
          Vibration.vibrate(pattern: [0, 800, 400, 800], repeat: 0);
          debugPrint("Vibrasi dimulai");
        } else {
          debugPrint("Perangkat tidak mendukung vibrasi");
        }
      } catch (e) {
        debugPrint("Gagal menjalankan vibrasi: $e");
      }
    }
  }

  void _stopAlarmFeedback() async {
    _isAlarmRunning = false;

    // 1. Stop audio
    try {
      await _sirenPlayer?.stop();
      await _sirenPlayer?.dispose();
      _sirenPlayer = null;
    } catch (e) {
      debugPrint("Gagal menghentikan audio sirine: $e");
    }

    // 2. Cancel vibration
    try {
      Vibration.cancel();
    } catch (e) {
      debugPrint("Gagal membatalkan vibrasi: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Listener(
      onPointerDown: (_) => _resetAutoLockTimer(),
      onPointerMove: (_) => _resetAutoLockTimer(),
      child: ValueListenableBuilder<SmarthomeState?>(
        valueListenable: SmartHomeService().stateNotifier,
        builder: (context, state, child) {
          final bool isAlarmActive = state != null && state.perangkat.buzzerAlrm;

          return Stack(
            children: [
              Scaffold(
                backgroundColor: Color(AppColors.surface),
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(68 + topPadding),
                  child: Header(
                    onNotificationsPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationScreen()),
                      );
                    },
                    onSettingsPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                ),
                body: _buildBody(),
                bottomNavigationBar: BottomNavBar(
                  currentIndex: _currentIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
              ),
              if (isAlarmActive)
                const IgnorePointer(
                  child: _FullSirenVignette(),
                ),
              if (_isLocked)
                _LockScreenOverlay(
                  onUnlock: () {
                    setState(() {
                      _isLocked = false;
                    });
                    _resetAutoLockTimer();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    // IndexedStack menjaga semua screen tetap hidup di memory,
    // sehingga state tidak reset saat pindah tab atau saat alarm aktif
    return IndexedStack(
      index: _currentIndex,
      children: [
        HomeScreen(
          onTabSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        DevicesScreen(),
        MonitorScreen(),
        SecurityScreen(),
      ],
    );
  }
}

class _LockScreenOverlay extends StatefulWidget {
  final VoidCallback onUnlock;
  const _LockScreenOverlay({required this.onUnlock});

  @override
  State<_LockScreenOverlay> createState() => _LockScreenOverlayState();
}

class _LockScreenOverlayState extends State<_LockScreenOverlay> with TickerProviderStateMixin {
  final _lockPasswordController = TextEditingController();
  String? _errorMessage;
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lockPasswordController.dispose();
    _shakeController.dispose();
    _pulseController.dispose();
    _errorTimer?.cancel();
    super.dispose();
  }

  void triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    HapticFeedback.vibrate();
    triggerShake();
    setState(() {
      _errorMessage = message;
      _lockPasswordController.clear();
    });
    _errorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService();
    final accentColor = SystemSettingsService().activeAccent.value;
    final pinLength = _lockPasswordController.text.length;
    final int totalPinDots = profile.password.value.length;

    // Shake animation definition
    final shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 15.0), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 15.0, end: -15.0), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -15.0, end: 15.0), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 15.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    void handleNumberPress(String val) {
      final pwdLength = profile.password.value.length;
      if (_lockPasswordController.text.length < pwdLength) {
        HapticFeedback.selectionClick();
        setState(() {
          _lockPasswordController.text += val;
          _errorMessage = null;
        });
        
        // Auto submit if it reaches the length of password
        if (_lockPasswordController.text.length == pwdLength) {
          if (_lockPasswordController.text == profile.password.value) {
            HapticFeedback.heavyImpact();
            widget.onUnlock();
          } else {
            _showError('PIN Keamanan Salah!');
          }
        }
      }
    }

    void handleBackspace() {
      if (_lockPasswordController.text.isNotEmpty) {
        HapticFeedback.selectionClick();
        setState(() {
          _lockPasswordController.text = _lockPasswordController.text.substring(0, _lockPasswordController.text.length - 1);
          _errorMessage = null;
        });
      }
    }

    void handleUnlock() {
      if (_lockPasswordController.text == profile.password.value) {
        HapticFeedback.heavyImpact();
        widget.onUnlock();
      } else {
        _showError('PIN Keamanan Salah!');
      }
    }

    Widget buildPinDot(int index) {
      final bool isFilled = index < pinLength;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFilled ? accentColor : Colors.white.withOpacity(0.15),
          border: Border.all(
            color: isFilled ? accentColor : Colors.white.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: isFilled
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
      );
    }

    Widget buildKeypadButton(String label, {VoidCallback? onPressed, IconData? icon}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () => handleNumberPress(label),
          borderRadius: BorderRadius.circular(40),
          splashColor: accentColor.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.03),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.02),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: Colors.white, size: 24)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Material(
        color: const Color(0xFF030508),
        child: Stack(
          children: [
            // Ambient glowing blobs
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -50,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),

            // Top Header Branding
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: accentColor.withOpacity(0.7), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'OTTER SECURE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main UI
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        // Dynamic Avatar with animated glow
                        ValueListenableBuilder<Uint8List?>(
                          valueListenable: profile.avatarBytes,
                          builder: (context, cachedBytes, _) {
                            return ValueListenableBuilder<String>(
                              valueListenable: profile.avatarUrl,
                              builder: (context, avatar, _) {
                                final initials = profile.initials;
                                return AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final double pulse = _pulseController.value;
                                    return Container(
                                      width: 92,
                                      height: 92,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: accentColor.withOpacity(0.5 + pulse * 0.5),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentColor.withOpacity(0.15 + pulse * 0.2),
                                            blurRadius: 15 + pulse * 12,
                                            spreadRadius: pulse * 2,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: avatar.isEmpty
                                            ? Container(
                                                color: const Color(0xFF1E2020),
                                                child: Center(
                                                  child: Text(
                                                    initials,
                                                    style: TextStyle(
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.w800,
                                                      color: accentColor,
                                                      fontFamily: 'Sora',
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : (cachedBytes != null
                                                ? Image.memory(
                                                    cachedBytes,
                                                    fit: BoxFit.cover,
                                                  )
                                                : (avatar.startsWith('data:image') && avatar.contains('base64,')
                                                    ? Image.memory(
                                                        base64Decode(avatar.split('base64,')[1]),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.network(
                                                        avatar,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) => Container(
                                                          color: const Color(0xFF1E2020),
                                                          child: Center(
                                                            child: Text(
                                                              initials,
                                                              style: TextStyle(
                                                                fontSize: 28,
                                                                fontWeight: FontWeight.w800,
                                                                color: accentColor,
                                                                fontFamily: 'Sora',
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ))),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Name
                        ValueListenableBuilder<String>(
                          valueListenable: profile.displayName,
                          builder: (context, name, _) => Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Sora',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Status Text
                        Text(
                          _errorMessage ?? 'Sistem Terkunci',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: _errorMessage != null ? Colors.redAccent : Colors.white.withOpacity(0.45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // PIN Dots Row wrapped with Shake Animation
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final offset = shakeAnimation.value;
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(totalPinDots, (index) => buildPinDot(index)),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Numeric Keypad Layout
                        Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  buildKeypadButton('1'),
                                  buildKeypadButton('2'),
                                  buildKeypadButton('3'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  buildKeypadButton('4'),
                                  buildKeypadButton('5'),
                                  buildKeypadButton('6'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  buildKeypadButton('7'),
                                  buildKeypadButton('8'),
                                  buildKeypadButton('9'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Backspace
                                  buildKeypadButton('', icon: Icons.backspace_outlined, onPressed: handleBackspace),
                                  buildKeypadButton('0'),
                                  // Checkmark Submit
                                  buildKeypadButton('', icon: Icons.check_circle_outline_rounded, onPressed: handleUnlock),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullSirenVignette extends StatefulWidget {
  const _FullSirenVignette();

  @override
  State<_FullSirenVignette> createState() => _FullSirenVignetteState();
}

class _FullSirenVignetteState extends State<_FullSirenVignette> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final double pulse = _animation.value;
        final Color glowColor = const Color(0xFFFF3B30).withValues(alpha: pulse * 0.24);
        return Stack(
          children: [
            // Left glow
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [glowColor, Colors.transparent],
                  ),
                ),
              ),
            ),
            // Right glow
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [glowColor, Colors.transparent],
                  ),
                ),
              ),
            ),
            // Top glow
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [glowColor, Colors.transparent],
                  ),
                ),
              ),
            ),
            // Bottom glow
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [glowColor, Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
