import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> with TickerProviderStateMixin {
  // ─── Security States ───
  bool _isAlarmActive = false;
  bool _isUnlocked = false;
  bool _isAutoLockOn = true;
  String _activeFilter = 'All'; // 'All', 'Alerts', 'Routine'
  bool _isLogExpanded = false;

  // ─── Biometric Scanner States ───
  bool _isBiometricScanning = false;
  String _biometricStatusText = 'Scanning Biometrics...';
  double _biometricProgress = 0.0;
  Timer? _biometricTimer;

  // ─── Animation Controllers ───
  late AnimationController _pulseController;         // Soundwave concentric pulse
  late AnimationController _sirenFlashController;    // Edge flash red vignette
  late AnimationController _biometricScannerController; // Biometric scan line sliding

  // ─── Simulated Log Database ───
  final List<_SecurityLogItem> _allLogs = [
    _SecurityLogItem(
      title: 'Motion Detected (Backyard)',
      subtitle: 'Unrecognized movement recorded by Cam-04. Alert sent to primary device.',
      timestamp: '10:42 PM',
      type: _LogType.alert,
      icon: Icons.sensor_door_rounded,
    ),
    _SecurityLogItem(
      title: 'Front Door Unlocked',
      subtitle: 'RFID tag \'Alex_Keys\' authenticated successfully.',
      timestamp: '06:15 PM',
      type: _LogType.routine,
      icon: Icons.vpn_key_rounded,
    ),
    _SecurityLogItem(
      title: 'System Armed (Away Mode)',
      subtitle: 'Scheduled automation engaged. All external sensors active.',
      timestamp: '08:00 AM',
      type: _LogType.routine,
      icon: Icons.shield_rounded,
    ),
    _SecurityLogItem(
      title: 'Low Battery (Garage Sensor)',
      subtitle: 'Sensor battery at 15%. Recommend replacement soon.',
      timestamp: 'Yesterday',
      type: _LogType.warning,
      icon: Icons.battery_alert_rounded,
    ),
    // Expanded Logs
    _SecurityLogItem(
      title: 'Backyard Cam-04 Recalibrated',
      subtitle: 'Auto-exposure values balanced due to dusk transition.',
      timestamp: 'Yesterday',
      type: _LogType.routine,
      icon: Icons.video_camera_back_rounded,
    ),
    _SecurityLogItem(
      title: 'Fire Alarm System Self-Test',
      subtitle: 'All smoke detector sirens verified online and responsive.',
      timestamp: '2 days ago',
      type: _LogType.routine,
      icon: Icons.local_fire_department_rounded,
    ),
    _SecurityLogItem(
      title: 'Emergency Contacts Updated',
      subtitle: 'Primary user updated primary phone numbers inside application portal.',
      timestamp: '3 days ago',
      type: _LogType.routine,
      icon: Icons.contact_phone_rounded,
    ),
    _SecurityLogItem(
      title: 'RFID Database Synchronized',
      subtitle: 'Local gateway synced 5 keys with secure cloud storage.',
      timestamp: '4 days ago',
      type: _LogType.routine,
      icon: Icons.sync_lock_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 1. Megaphone soundwave pulsing animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // 2. Siren red vignette flash animation
    _sirenFlashController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 3. Biometric scanner glowing horizontal line
    _biometricScannerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sirenFlashController.dispose();
    _biometricScannerController.dispose();
    _biometricTimer?.cancel();
    super.dispose();
  }

  // ─── Custom Alarm Siren Trigger ───
  void _toggleAlarm() {
    if (_isAlarmActive) {
      // Disarm Alarm
      HapticFeedback.heavyImpact();
      _sirenFlashController.stop();
      _sirenFlashController.reset();
      setState(() {
        _isAlarmActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Siren disarmed successfully. System in standby mode.'),
          backgroundColor: Color(AppColors.surfaceContainerHigh),
        ),
      );
    } else {
      // Arm / Trigger active Alarm
      HapticFeedback.vibrate();
      _sirenFlashController.repeat(reverse: true);
      setState(() {
        _isAlarmActive = true;
      });
      // Start a continuous vibration sequence
      _triggerContinuousAlarmHaptics();
    }
  }

  // Periodic vibration when emergency alarm is active
  void _triggerContinuousAlarmHaptics() async {
    while (_isAlarmActive) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!_isAlarmActive) break;
      HapticFeedback.vibrate();
    }
  }

  // ─── Biometric Scanner Unlock Trigger ───
  void _triggerBiometricUnlock() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBiometricScanning = true;
      _biometricProgress = 0.0;
      _biometricStatusText = 'Authenticating RFID & Biometrics...';
    });

    const int totalSteps = 15;
    int currentStep = 0;
    
    _biometricTimer?.cancel();
    _biometricTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      currentStep++;
      setState(() {
        _biometricProgress = currentStep / totalSteps;
      });

      if (currentStep >= totalSteps) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _isBiometricScanning = false;
          _isUnlocked = !_isUnlocked;
        });

        // Trigger Auto-Lock timers if configured
        if (_isUnlocked && _isAutoLockOn) {
          _triggerAutoLockTimer();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isUnlocked 
                ? '🔓 Front door unlocked successfully!' 
                : '🔒 Front door locked successfully!'),
            backgroundColor: _isUnlocked 
                ? const Color(0xFF00F4FE).withOpacity(0.12)
                : const Color(AppColors.surfaceContainerHigh),
          ),
        );
      }
    });
  }

  // Simulates automatic locking after 5 seconds for demonstration,
  // indicating it engages in 5 minutes in a production scenario.
  void _triggerAutoLockTimer() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isUnlocked && _isAutoLockOn) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isUnlocked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Front Door secured automatically (Auto-Lock active).'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    // Filter event log list based on selected filter
    final List<_SecurityLogItem> filteredLogs = _allLogs.where((log) {
      if (_activeFilter == 'All') return true;
      if (_activeFilter == 'Alerts') return log.type == _LogType.alert || log.type == _LogType.warning;
      if (_activeFilter == 'Routine') return log.type == _LogType.routine;
      return true;
    }).toList();

    // Limit active visible items depending on expand/collapse state
    final int displayCount = _isLogExpanded 
        ? filteredLogs.length 
        : math.min(filteredLogs.length, 4);

    return Stack(
      children: [
        // ─── Core Content Scroll ───
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.containerPadding,
              vertical: isMobile ? 16.0 : AppSpacing.stackMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row
                _buildHeader(isMobile),
                
                SizedBox(height: isMobile ? 24.0 : AppSpacing.stackLg),

                // 2. Bento Responsive Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    
                    if (width > 850) {
                      // Desktop Side-by-Side 2 Column Bento Grid
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Alarm Siren & RFID Controls (5/12 cols)
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildBuzzerAlarmCard(),
                                const SizedBox(height: AppSpacing.gutter),
                                _buildRFIDControlCard(),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.gutter),
                          // Right Column: Log Event History (7/12 cols)
                          Expanded(
                            flex: 7,
                            child: _buildEventLogCard(filteredLogs, displayCount),
                          ),
                        ],
                      );
                    } else {
                      // Mobile/Tablet Vertical Stack Bento Grid
                      return Column(
                        children: [
                          _buildBuzzerAlarmCard(),
                          const SizedBox(height: AppSpacing.gutter),
                          _buildRFIDControlCard(),
                          const SizedBox(height: AppSpacing.gutter),
                          _buildEventLogCard(filteredLogs, displayCount),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),

        // ─── Full-screen Flashing Siren Vignette ───
        if (_isAlarmActive)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _sirenFlashController,
              builder: (context, _) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(AppColors.error).withOpacity(_sirenFlashController.value * 0.45),
                      width: 24.0,
                    ),
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        const Color(AppColors.error).withOpacity(_sirenFlashController.value * 0.18),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

        // ─── Biometric Scanner Glass Simulation Overlay ───
        if (_isBiometricScanning)
          _buildBiometricScannerOverlay(),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // A. Header Widget
  // ─────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Core',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: isMobile ? 28 : 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppColors.onSurface),
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // Pulsing status LED dot
                  _BlinkingLedDot(
                    color: _isAlarmActive 
                        ? const Color(AppColors.error) 
                        : const Color(0xFF00F4FE),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isAlarmActive ? 'CRITICAL: EMERGENCY ACTIVE' : 'System Armed & Monitoring',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isAlarmActive 
                          ? const Color(AppColors.error) 
                          : const Color(AppColors.onSurfaceVariant).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Online Pll / Battery level Indicators
        if (!isMobile)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(AppColors.surfaceContainerLow),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF00F4FE)),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(AppColors.onSurfaceVariant).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(AppColors.surfaceContainerLow),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.battery_full_rounded, size: 14, color: Color(0xFF00F4FE)),
                    const SizedBox(width: 6),
                    Text(
                      '100%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(AppColors.onSurfaceVariant).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // B. Bento Card 1: Emergency System Alarm Button
  // ─────────────────────────────────────────────────
  Widget _buildBuzzerAlarmCard() {
    return _SecurityGlassCard(
      glowColor: _isAlarmActive ? const Color(AppColors.error).withOpacity(0.12) : null,
      child: Stack(
        children: [
          // Dynamic red background glow overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _isAlarmActive 
                        ? const Color(AppColors.error).withOpacity(0.12) 
                        : const Color(AppColors.error).withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              // Card Title Headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _isAlarmActive ? const Color(AppColors.error) : const Color(AppColors.tertiary),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'EMERGENCY SYSTEM',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.onSurface),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _isAlarmActive 
                          ? const Color(AppColors.error).withOpacity(0.15) 
                          : const Color(AppColors.surfaceContainerHigh),
                      border: Border.all(
                        color: _isAlarmActive 
                            ? const Color(AppColors.error).withOpacity(0.3) 
                            : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Text(
                      _isAlarmActive ? '🚨 TRIGGERED' : 'Standby',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _isAlarmActive ? const Color(AppColors.error) : const Color(AppColors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              // Concentric Pulsing Soundwave Alarm Button
              Center(
                child: GestureDetector(
                  onTap: _toggleAlarm,
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric waves
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _SoundwavePainter(
                                progress: _pulseController.value,
                                color: _isAlarmActive 
                                    ? const Color(AppColors.error) 
                                    : const Color(AppColors.error).withOpacity(0.5),
                              ),
                              size: const Size(180, 180),
                            );
                          },
                        ),
                        
                        // Central Solid Alarm Button Ring
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isAlarmActive 
                                ? const Color(AppColors.errorContainer) 
                                : const Color(AppColors.surfaceContainerHigh),
                            border: Border.all(
                              color: const Color(AppColors.error).withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(AppColors.error).withOpacity(_isAlarmActive ? 0.45 : 0.08),
                                blurRadius: _isAlarmActive ? 24 : 10,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.campaign_rounded,
                                size: 36,
                                color: _isAlarmActive ? const Color(AppColors.onSurface) : const Color(AppColors.error),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isAlarmActive ? 'DISARM' : 'ALARM',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Triggers high-decibel siren and notifies emergency contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // C. Bento Card 2: Front Door RFID Controller
  // ─────────────────────────────────────────────────
  Widget _buildRFIDControlCard() {
    return _SecurityGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header Lock details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Icon(
                      _isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: const Color(0xFF00F4FE),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FRONT DOOR RFID',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.onSurfaceVariant),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${_isUnlocked ? 'Unlocked' : 'Locked'}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.onSurface),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Lock indicator status LED
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isUnlocked ? const Color(0xFF00F4FE) : const Color(AppColors.error),
                  boxShadow: [
                    BoxShadow(
                      color: (_isUnlocked ? const Color(0xFF00F4FE) : const Color(AppColors.error)).withOpacity(0.6),
                      blurRadius: 8,
                    )
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Auto-Lock toggle sub-card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(AppColors.surfaceContainerLow).withOpacity(0.5),
              border: Border.all(
                color: Colors.white.withOpacity(0.04),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-Lock',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(AppColors.onSurface),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Engages after 5m',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: const Color(AppColors.onSurfaceVariant).withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                
                // Custom stateful Switch toggle sliding pill
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isAutoLockOn = !_isAutoLockOn;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 44,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: _isAutoLockOn 
                          ? const Color(0xFF00F4FE).withOpacity(0.2) 
                          : Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: _isAutoLockOn 
                            ? const Color(0xFF00F4FE).withOpacity(0.5) 
                            : Colors.white.withOpacity(0.12),
                        width: 1.0,
                      ),
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          alignment: _isAutoLockOn ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isAutoLockOn ? const Color(0xFF00F4FE) : const Color(AppColors.tertiary),
                              boxShadow: _isAutoLockOn 
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00F4FE).withOpacity(0.4),
                                        blurRadius: 6,
                                      )
                                    ] 
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Biometric Scan Unlock Button
          GestureDetector(
            onTap: _triggerBiometricUnlock,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(AppColors.surfaceContainerHigh),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 18,
                    color: Color(0xFF00F4FE),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUnlocked ? 'SECURE LOCK DOOR' : 'EMERGENCY UNLOCK',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // D. Bento Card 3: Security Event History Log
  // ─────────────────────────────────────────────────
  Widget _buildEventLogCard(List<_SecurityLogItem> filteredLogs, int displayCount) {
    return _SecurityGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event log Card Header with popup filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Security Event Log',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.onSurface),
                ),
              ),
              
              // Filter Popup selector trigger
              PopupMenuButton<String>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF00F4FE)),
                    const SizedBox(width: 4),
                    Text(
                      _activeFilter,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00F4FE),
                      ),
                    ),
                  ],
                ),
                color: const Color(AppColors.surfaceContainerHigh),
                offset: const Offset(0, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _activeFilter = val;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'All',
                    child: Text('All Events', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'Alerts',
                    child: Text('Alerts & Warnings', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'Routine',
                    child: Text('Routine Actions', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Log list with height-changing animations
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayCount,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final _SecurityLogItem log = filteredLogs[index];
                
                // Styling depends on log type (Alert, Warning, Routine)
                final bool isAlert = log.type == _LogType.alert;
                final bool isWarning = log.type == _LogType.warning;
                
                final Color containerBg = isAlert 
                    ? const Color(AppColors.errorContainer).withOpacity(0.06) 
                    : const Color(AppColors.surfaceContainerLow).withOpacity(0.4);
                
                final Color borderSideColor = isAlert 
                    ? const Color(AppColors.error) 
                    : isWarning 
                        ? const Color(AppColors.tertiary)
                        : const Color(0xFF00F4FE).withOpacity(0.4);

                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: containerBg,
                    border: Border.all(
                      color: isAlert 
                          ? const Color(AppColors.error).withOpacity(0.2) 
                          : Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Red Accent left boundary indicator
                      Container(
                        width: 3.5,
                        height: 72,
                        color: borderSideColor,
                      ),
                      const SizedBox(width: 14),
                      
                      // Icon Indicator
                      Icon(
                        log.icon,
                        size: 20,
                        color: isAlert 
                            ? const Color(AppColors.error) 
                            : isWarning 
                                ? const Color(AppColors.tertiary) 
                                : const Color(0xFF00F4FE),
                      ),
                      
                      const SizedBox(width: 14),
                      
                      // Details texts
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      log.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isAlert ? const Color(AppColors.error) : const Color(AppColors.onSurface),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    log.timestamp,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      color: const Color(AppColors.onSurfaceVariant).withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                log.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: const Color(AppColors.onSurfaceVariant).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // View archive expand trigger
          if (filteredLogs.length > 4)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isLogExpanded = !_isLogExpanded;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Text(
                  _isLogExpanded ? 'Show Recent Only' : 'View Full Archive',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00F4FE),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // E. Biometric Scanner Fullscreen Modal Overlay
  // ─────────────────────────────────────────────────
  Widget _buildBiometricScannerOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: BackdropFilter(
          filter: const ColorFilter.mode(
            Colors.transparent,
            BlendMode.multiply,
          ),
          child: Center(
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(AppColors.surfaceContainerHigh),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F4FE).withOpacity(0.1),
                    blurRadius: 30,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Biometric Scanning visual line container
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Static glowing ring boundary
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00F4FE).withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        
                        // Fingerprint main active center
                        const Icon(
                          Icons.fingerprint_rounded,
                          size: 72,
                          color: Color(0xFF00F4FE),
                        ),

                        // Moving scanning line overlay
                        AnimatedBuilder(
                          animation: _biometricScannerController,
                          builder: (context, _) {
                            // Translate scan line between top and bottom offsets (-40 to 40)
                            final double translation = -36.0 + (_biometricScannerController.value * 72.0);
                            return Transform.translate(
                              offset: Offset(0, translation),
                              child: Container(
                                width: 84,
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      const Color(0xFF00F4FE),
                                      const Color(0xFF00F4FE).withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00F4FE).withOpacity(0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    _biometricStatusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Horizontal mini scanning track bar
                  Container(
                    width: 180,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withOpacity(0.06),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _biometricProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: const Color(0xFF00F4FE),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F4FE).withOpacity(0.5),
                                blurRadius: 4,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// BLINKING LED DOT SIMULATOR
// ─────────────────────────────────────────────────
class _BlinkingLedDot extends StatefulWidget {
  final Color color;
  const _BlinkingLedDot({required this.color});

  @override
  State<_BlinkingLedDot> createState() => _BlinkingLedDotState();
}

class _BlinkingLedDotState extends State<_BlinkingLedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
      animation: _opacity,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_opacity.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_opacity.value * 0.7),
                blurRadius: 6,
                spreadRadius: 1,
              )
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
// SOUNDWAVE PAINTER VECTOR
// ─────────────────────────────────────────────────
class _SoundwavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _SoundwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw three concentric dynamic circles
    for (int i = 0; i < 3; i++) {
      double p = (progress + i / 3.0) % 1.0;
      double radius = p * maxRadius;
      
      // Arc opacity drops as circles expand
      double opacity = (1.0 - p).clamp(0.0, 1.0);
      paint.color = color.withOpacity(opacity * 0.35);
      
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundwavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────
// UNIFORM SECURITY GLASS CONTAINER
// ─────────────────────────────────────────────────
class _SecurityGlassCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;

  const _SecurityGlassCard({
    required this.child,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.0,
        ),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!,
              blurRadius: 24,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Helpers Structs ───
enum _LogType { alert, routine, warning }

class _SecurityLogItem {
  final String title;
  final String subtitle;
  final String timestamp;
  final _LogType type;
  final IconData icon;

  _SecurityLogItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
    required this.icon,
  });
}
