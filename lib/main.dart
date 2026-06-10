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
import 'models/device_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Otter - Smart Home',
      theme: AppTheme.darkTheme,
      home: const MainLayout(),
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

  @override
  void initState() {
    super.initState();
    FirebaseService().stateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    FirebaseService().stateNotifier.removeListener(_onStateChanged);
    _stopAlarmFeedback();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = FirebaseService().stateNotifier.value;
    final bool isAlarmActive = state != null &&
        (state.perangkat.buzzerTamu || state.perangkat.buzzerDapur);

    if (isAlarmActive && !_isAlarmRunning) {
      _startAlarmFeedback();
    } else if (!isAlarmActive && _isAlarmRunning) {
      _stopAlarmFeedback();
    }
  }

  void _startAlarmFeedback() async {
    _isAlarmRunning = true;

    // 1. Play siren sound with high compatibility and local asset
    try {
      _sirenPlayer ??= AudioPlayer();
      await _sirenPlayer?.setReleaseMode(ReleaseMode.loop);
      // Play local siren WAV
      await _sirenPlayer?.play(AssetSource('sounds/siren.wav'));
    } catch (e) {
      debugPrint("Gagal memutar audio sirine: $e");
    }

    // 2. Trigger strong continuous vibration pattern: wait 0ms, vibrate 1000ms, wait 500ms... repeat forever
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 0);
      }
    } catch (e) {
      debugPrint("Gagal menjalankan vibrasi: $e");
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

    return ValueListenableBuilder<SmarthomeState?>(
      valueListenable: FirebaseService().stateNotifier,
      builder: (context, state, child) {
        final bool isAlarmActive = state != null &&
            (state.perangkat.buzzerTamu || state.perangkat.buzzerDapur);

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
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const DevicesScreen();
      case 2:
        return const MonitorScreen();
      case 3:
        return const SecurityScreen();
      default:
        return const HomeScreen();
    }
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
        final Color glowColor = const Color(0xFFFF3B30).withOpacity(pulse * 0.24);
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
