import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'widgets/header.dart';
import 'widgets/navbar.dart';
import 'screens/home_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/monitor_screen.dart';
import 'screens/security_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/settings_screen.dart';

import 'services/firebase_service.dart';
import 'services/system_settings_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'models/device_model.dart';
import 'models/notification_model.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemSettingsService().init();
  await FirebaseService().init();
  NotificationService().init();
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
          debugShowCheckedModeBanner: false,
          title: 'Otter - Smart Home',
          theme: AppTheme.darkTheme,
          home: MainLayout(),
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  AudioPlayer? _sirenPlayer;
  bool _isAlarmRunning = false;
  Timer? _alarmDebounceTimer;
  Timer? _autoLockTimer;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    FirebaseService().stateNotifier.addListener(_onStateChanged);
    SystemSettingsService().enableSound.addListener(_onSettingsChanged);
    SystemSettingsService().enableVibration.addListener(_onSettingsChanged);
    
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

  @override
  void dispose() {
    FirebaseService().stateNotifier.removeListener(_onStateChanged);
    SystemSettingsService().enableSound.removeListener(_onSettingsChanged);
    SystemSettingsService().enableVibration.removeListener(_onSettingsChanged);
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
      setState(() {
        _isLocked = true;
      });
    });
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    if (_isAlarmRunning) {
      _stopAlarmFeedback();
      final state = FirebaseService().stateNotifier.value;
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
      final state = FirebaseService().stateNotifier.value;
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
    if (settings.enableSound.value) {
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
        valueListenable: FirebaseService().stateNotifier,
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
                _buildLockScreenOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLockScreenOverlay() {
    final profile = ProfileService();
    final accentColor = SystemSettingsService().activeAccent.value;
    final passwordController = TextEditingController();
    bool obscureText = true;
    String? errorMessage;

    return StatefulBuilder(
      builder: (context, setStateLock) {
        return Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: 0.85),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dynamic Avatar
                        ValueListenableBuilder<String>(
                          valueListenable: profile.avatarUrl,
                          builder: (context, avatar, _) {
                            final initials = profile.initials;
                            return Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: accentColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
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
                                          )),
                              ),
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
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Sora',
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Role
                        ValueListenableBuilder<String>(
                          valueListenable: profile.role,
                          builder: (context, role, _) => Text(
                            role,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Password Field
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: errorMessage != null
                                  ? Colors.redAccent.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: TextField(
                            controller: passwordController,
                            obscureText: obscureText,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) {
                              // Trigger unlock
                              if (passwordController.text == profile.password.value) {
                                HapticFeedback.heavyImpact();
                                setState(() {
                                  _isLocked = false;
                              });
                                _resetAutoLockTimer();
                              } else {
                                HapticFeedback.vibrate();
                                setStateLock(() {
                                  errorMessage = 'Password salah!';
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Masukkan Password...',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: accentColor, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  size: 18,
                                ),
                                onPressed: () {
                                  setStateLock(() {
                                    obscureText = !obscureText;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),

                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Unlock button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(180, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (passwordController.text == profile.password.value) {
                              HapticFeedback.heavyImpact();
                              setState(() {
                                _isLocked = false;
                              });
                              _resetAutoLockTimer();
                            } else {
                              HapticFeedback.vibrate();
                              setStateLock(() {
                                errorMessage = 'Password salah!';
                              });
                            }
                          },
                          child: const Text(
                            'Buka Kunci',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
      },
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
