import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import '../services/smarthome_service.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import '../widgets/quick_status_banner.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> with TickerProviderStateMixin {
  // ─── Security Settings ───
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
  late AnimationController _biometricScannerController; // Biometric scan line sliding

  @override
  void initState() {
    super.initState();

    // 1. Megaphone soundwave pulsing animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // 3. Biometric scanner glowing horizontal line
    _biometricScannerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _biometricScannerController.dispose();
    _biometricTimer?.cancel();
    super.dispose();
  }

  // ─── Custom Alarm Siren Trigger ───
  void _toggleAlarm(bool isCurrentlyActive) {
    debugPrint('DEBUG: _toggleAlarm called. Current active status: $isCurrentlyActive');
    if (isCurrentlyActive) {
      // Disarm Alarm
      HapticFeedback.heavyImpact();
      SmartHomeService().disarmAllAlarms();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(AppColors.surfaceContainerHigh).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color(AppColors.secondaryContainer).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(AppColors.secondaryContainer).withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(AppColors.secondaryContainer).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: Color(AppColors.secondaryContainer),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sirine Dinonaktifkan',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sistem keamanan dalam mode siaga.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Arm / Trigger active Alarm
      HapticFeedback.vibrate();
      SmartHomeService().updatePerangkat('buzzer_alrm', true);
      SmartHomeService().updatePerangkat('led_merah_dapur', true);
    }
  }

  // ─── Biometric Scanner Unlock Trigger ───
  void _triggerBiometricUnlock(bool currentLockedState) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBiometricScanning = true;
      _biometricProgress = 0.0;
      _biometricStatusText = 'Memverifikasi RFID & Biometrik...';
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
        });

        // Toggle state in Firebase
        final nextLockedState = !currentLockedState;
        SmartHomeService().updatePerangkat('kunci_pintu_rfid', nextLockedState);

        // Trigger Auto-Lock timers if configured
        if (!nextLockedState && _isAutoLockOn) {
          _triggerAutoLockTimer();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!nextLockedState 
                ? '🔓 Pintu utama berhasil dibuka!' 
                : '🔒 Pintu utama berhasil dikunci!'),
            backgroundColor: !nextLockedState 
                ? Color(AppColors.secondaryContainer).withValues(alpha: 0.12)
                : const Color(AppColors.surfaceContainerHigh),
          ),
        );
      }
    });
  }

  void _triggerAutoLockTimer() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isAutoLockOn) {
        final state = SmartHomeService().stateNotifier.value;
        if (state != null && !state.perangkat.kunciPintuRfid) {
          HapticFeedback.mediumImpact();
          SmartHomeService().updatePerangkat('kunci_pintu_rfid', true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 Pintu utama terkunci otomatis (Auto-Lock aktif).'),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return ValueListenableBuilder<SmarthomeState?>(
      valueListenable: SmartHomeService().stateNotifier,
      builder: (context, state, child) {
        if (state == null) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(AppColors.secondaryContainer)),
            ),
          );
        }

        final sensor = state.sensor;
        final perangkat = state.perangkat;

        final bool isAlarmActive = perangkat.buzzerAlrm;
        final bool isUnlocked = !perangkat.kunciPintuRfid;

        // Alarm active check done reactively

        // Live telemetry actions log
        return ValueListenableBuilder<List<NotificationModel>>(
          valueListenable: NotificationService().notificationsNotifier,
          builder: (context, notifications, child) {
            // Live telemetry actions log from real-time database notifications
            final List<_SecurityLogItem> dynamicSecurityLogs = notifications
                .where((n) => n.category == NotificationCategory.security)
                .map((n) {
              final icon = _getNotificationIcon(n);
              _LogType logType;
              switch (n.priority) {
                case NotificationPriority.critical:
                  logType = _LogType.alert;
                  break;
                case NotificationPriority.warning:
                  logType = _LogType.warning;
                  break;
                case NotificationPriority.info:
                  logType = _LogType.routine;
                  break;
              }

              String timeStr = 'Baru saja';
              final difference = DateTime.now().difference(n.timestamp);
              if (difference.inMinutes >= 1) {
                if (difference.inMinutes < 60) {
                  timeStr = '${difference.inMinutes}m yang lalu';
                } else if (difference.inHours < 24) {
                  timeStr = '${difference.inHours}j yang lalu';
                } else {
                  timeStr = '${difference.inDays}h yang lalu';
                }
              }

              return _SecurityLogItem(
                title: n.title,
                subtitle: n.message,
                timestamp: timeStr,
                type: logType,
                icon: icon,
              );
            }).toList();

            // Filter event log list based on selected filter
            final List<_SecurityLogItem> filteredLogs = dynamicSecurityLogs.where((log) {
              if (_activeFilter == 'All') return true;
              if (_activeFilter == 'Alerts') return log.type == _LogType.alert || log.type == _LogType.warning;
              if (_activeFilter == 'Routine') return log.type == _LogType.routine;
              return true;
            }).toList();

            final int displayCount = _isLogExpanded 
                ? filteredLogs.length 
                : math.min(filteredLogs.length, 4);

            return Stack(
              children: [
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
                        _buildHeader(isMobile, isAlarmActive),
                        
                        SizedBox(height: isMobile ? 24.0 : AppSpacing.stackLg),

                        // ─── Emergency Status/Warning Banner ───
                        if (sensor.dapurFlame > 0 || sensor.tamuGerak || perangkat.buzzerAlrm) ...[
                          const QuickStatusBanner(alwaysShow: false),
                          const SizedBox(height: 16),
                        ],

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double width = constraints.maxWidth;
                            
                            if (width > 850) {
                              // Desktop Grid
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        _buildBuzzerAlarmCard(isAlarmActive),
                                        const SizedBox(height: AppSpacing.gutter),
                                        _buildRFIDControlCard(perangkat.kunciPintuRfid, isUnlocked),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.gutter),
                                  Expanded(
                                    flex: 7,
                                    child: _buildEventLogCard(filteredLogs, displayCount),
                                  ),
                                ],
                              );
                            } else {
                              // Mobile Layout
                              return Column(
                                children: [
                                  _buildBuzzerAlarmCard(isAlarmActive),
                                  const SizedBox(height: AppSpacing.gutter),
                                  _buildRFIDControlCard(perangkat.kunciPintuRfid, isUnlocked),
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

                // ─── Biometric Scanner Glass Overlay ───
                if (_isBiometricScanning)
                  _buildBiometricScannerOverlay(perangkat.kunciPintuRfid),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile, bool isAlarmActive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Keamanan',
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
                  _BlinkingLedDot(
                    color: isAlarmActive 
                        ? const Color(AppColors.error) 
                        : Color(AppColors.secondaryContainer),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAlarmActive ? 'KRITIS: DARURAT AKTIF' : 'Sistem Terpasang & Memantau',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isAlarmActive 
                          ? const Color(AppColors.error) 
                          : const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isMobile)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(AppColors.surfaceContainerLow),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_rounded, size: 14, color: Color(AppColors.secondaryContainer)),
                    SizedBox(width: 6),
                    Text(
                      'Firebase Terhubung',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
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

  Widget _buildBuzzerAlarmCard(bool isAlarmActive) {
    return _SecurityGlassCard(
      glowColor: isAlarmActive ? const Color(AppColors.error).withValues(alpha: 0.12) : null,
      child: Stack(
        children: [
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
                    isAlarmActive 
                        ? const Color(AppColors.error).withValues(alpha: 0.12) 
                        : const Color(AppColors.error).withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: isAlarmActive ? const Color(AppColors.error) : const Color(AppColors.tertiary),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SISTEM SIRINE DARURAT',
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
                      color: isAlarmActive 
                          ? const Color(AppColors.error).withValues(alpha: 0.15) 
                          : const Color(AppColors.surfaceContainerHigh),
                      border: Border.all(
                        color: isAlarmActive 
                            ? const Color(AppColors.error).withValues(alpha: 0.3) 
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      isAlarmActive ? '🚨 AKTIF' : 'Siaga',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isAlarmActive ? const Color(AppColors.error) : const Color(AppColors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleAlarm(isAlarmActive),
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _SoundwavePainter(
                                progress: _pulseController.value,
                                color: isAlarmActive 
                                    ? const Color(AppColors.error) 
                                    : const Color(AppColors.error).withValues(alpha: 0.5),
                              ),
                              size: const Size(180, 180),
                            );
                          },
                        ),
                        
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAlarmActive 
                                ? const Color(AppColors.errorContainer) 
                                : const Color(AppColors.surfaceContainerHigh),
                            border: Border.all(
                              color: const Color(AppColors.error).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(AppColors.error).withValues(alpha: isAlarmActive ? 0.45 : 0.08),
                                blurRadius: isAlarmActive ? 24 : 10,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.campaign_rounded,
                                size: 36,
                                color: isAlarmActive ? const Color(AppColors.onSurface) : const Color(AppColors.error),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAlarmActive ? 'MATIKAN' : 'ALARM PANIK',
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
                'Mengaktifkan sirine darurat diseluruh penjuru rumah.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRFIDControlCard(bool kunciPintuRfid, bool isUnlocked) {
    return _SecurityGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: Color(AppColors.secondaryContainer),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KUNCI PINTU RFID',
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
                        'Status: ${isUnlocked ? 'Terbuka' : 'Terkunci'}',
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
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked ? Color(AppColors.secondaryContainer) : const Color(AppColors.error),
                  boxShadow: [
                    BoxShadow(
                      color: (isUnlocked ? Color(AppColors.secondaryContainer) : const Color(AppColors.error)).withValues(alpha: 0.6),
                      blurRadius: 8,
                    )
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(AppColors.surfaceContainerLow).withValues(alpha: 0.5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auto-Lock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.onSurface),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kunci pintu setelah 8 detik',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                
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
                          ? Color(AppColors.secondaryContainer).withValues(alpha: 0.2) 
                          : Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: _isAutoLockOn 
                            ? Color(AppColors.secondaryContainer).withValues(alpha: 0.5) 
                            : Colors.white.withValues(alpha: 0.12),
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
                              color: _isAutoLockOn ? Color(AppColors.secondaryContainer) : const Color(AppColors.tertiary),
                              boxShadow: _isAutoLockOn 
                                  ? [
                                      BoxShadow(
                                        color: Color(AppColors.secondaryContainer).withValues(alpha: 0.4),
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

          GestureDetector(
            onTap: () => _triggerBiometricUnlock(kunciPintuRfid),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(AppColors.surfaceContainerHigh),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 18,
                    color: Color(AppColors.secondaryContainer),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    kunciPintuRfid ? 'BUKA BIOMETRIK DARURAT' : 'KUNCI RFID AMAN',
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

  Widget _buildEventLogCard(List<_SecurityLogItem> filteredLogs, int displayCount) {
    return _SecurityGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Log Kejadian Keamanan',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(AppColors.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list_rounded, size: 14, color: Color(AppColors.secondaryContainer)),
                    const SizedBox(width: 4),
                    Text(
                      _activeFilter,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(AppColors.secondaryContainer),
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
                    child: Text('Semua Kejadian', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'Alerts',
                    child: Text('Peringatan & Alarm', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 'Routine',
                    child: Text('Rutinitas Normal', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

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
                
                final bool isAlert = log.type == _LogType.alert;
                final bool isWarning = log.type == _LogType.warning;
                
                final Color containerBg = isAlert 
                    ? const Color(AppColors.errorContainer).withValues(alpha: 0.06) 
                    : const Color(AppColors.surfaceContainerLow).withValues(alpha: 0.4);
                
                final Color borderSideColor = isAlert 
                    ? const Color(AppColors.error) 
                    : isWarning 
                        ? const Color(AppColors.tertiary)
                        : Color(AppColors.secondaryContainer).withValues(alpha: 0.4);

                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: containerBg,
                    border: Border.all(
                      color: isAlert 
                          ? const Color(AppColors.error).withValues(alpha: 0.2) 
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 3.5,
                          color: borderSideColor,
                        ),
                        const SizedBox(width: 14),
                      
                      Icon(
                        log.icon,
                        size: 20,
                        color: isAlert 
                            ? const Color(AppColors.error) 
                            : isWarning 
                                ? const Color(AppColors.tertiary) 
                                : Color(AppColors.secondaryContainer),
                      ),
                      
                      const SizedBox(width: 14),
                      
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
                                      color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.5),
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
                                  color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              );
              },
            ),
          ),

          const SizedBox(height: 12),

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
                  _isLogExpanded ? 'Tampilkan Terbaru' : 'Lihat Semua',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(AppColors.secondaryContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBiometricScannerOverlay(bool currentLockedState) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
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
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(AppColors.secondaryContainer).withValues(alpha: 0.1),
                    blurRadius: 30,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(AppColors.secondaryContainer).withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 72,
                          color: Color(AppColors.secondaryContainer),
                        ),

                        AnimatedBuilder(
                          animation: _biometricScannerController,
                          builder: (context, _) {
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
                                      Color(AppColors.secondaryContainer),
                                      Color(AppColors.secondaryContainer).withValues(alpha: 0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(AppColors.secondaryContainer).withValues(alpha: 0.8),
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

                  Container(
                    width: 180,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _biometricProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Color(AppColors.secondaryContainer),
                            boxShadow: [
                              BoxShadow(
                                color: Color(AppColors.secondaryContainer).withValues(alpha: 0.5),
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

  // Context-aware icon helper to standardize icons
  IconData _getNotificationIcon(NotificationModel notif) {
    final t = notif.title.toLowerCase();

    // ── Lampu ──
    if (t.contains('lampu') && t.contains('menyala')) return Icons.lightbulb_rounded;
    if (t.contains('lampu') && t.contains('mati')) return Icons.lightbulb_outline_rounded;
    if (t.contains('lampu')) return Icons.lightbulb_rounded;

    // ── Kipas ──
    if (t.contains('kipas') && t.contains('mati')) return Icons.mode_fan_off_rounded;
    if (t.contains('kipas')) return Icons.air_rounded;
    if (t.contains('kecepatan kipas')) return Icons.speed_rounded;

    // ── Sirine / Alarm ──
    if (t.contains('sirine') && (t.contains('aktif') || t.contains('menyala'))) return Icons.campaign_rounded;
    if (t.contains('sirine')) return Icons.notifications_off_rounded;

    // ── RFID / Pintu ──
    if (t.contains('rfid') && t.contains('terkunci')) return Icons.lock_rounded;
    if (t.contains('rfid') && t.contains('terbuka')) return Icons.lock_open_rounded;
    if (t.contains('rfid') && t.contains('didaftarkan')) return Icons.add_card_rounded;
    if (t.contains('rfid') && t.contains('dihapus')) return Icons.credit_card_off_rounded;
    if (t.contains('rfid') && t.contains('disetujui')) return Icons.contactless_rounded;
    if (t.contains('rfid') && (t.contains('fisik') || t.contains('menunggu') || t.contains('pendaftaran'))) return Icons.hourglass_empty_rounded;
    if (t.contains('pintu')) return Icons.sensor_door_rounded;

    // ── Kebakaran / Api ──
    if (t.contains('kebakaran') || t.contains('api')) return Icons.local_fire_department_rounded;

    // ── Anomali / Pergerakan / PIR ──
    if (t.contains('anomali') || t.contains('pergerakan') || t.contains('pir')) return Icons.person_off_rounded;

    // ── Sistem Keamanan ──
    if (t.contains('keamanan') && t.contains('dinonaktifkan')) return Icons.shield_rounded;
    if (t.contains('keamanan')) return Icons.security_rounded;

    // ── Otomatisasi Lampu ──
    if (t.contains('otomatisasi') && t.contains('lampu') && t.contains('aktif')) return Icons.auto_awesome_rounded;
    if (t.contains('otomatisasi') && t.contains('lampu')) return Icons.auto_mode_rounded;

    // ── Otomatisasi Kipas ──
    if (t.contains('otomatisasi') && t.contains('kipas')) return Icons.thermostat_auto_rounded;

    // ── Ambang / Threshold ──
    if (t.contains('ambang') && t.contains('cahaya')) return Icons.wb_twilight_rounded;
    if (t.contains('ambang') && t.contains('suhu')) return Icons.thermostat_rounded;
    if (t.contains('ambang')) return Icons.tune_rounded;

    // ── Fallback ──
    switch (notif.category) {
      case NotificationCategory.security:
        return Icons.shield_rounded;
      case NotificationCategory.climate:
        return Icons.thermostat_rounded;
      case NotificationCategory.energy:
        return Icons.bolt_rounded;
      case NotificationCategory.system:
        return Icons.settings_suggest_rounded;
    }
  }
}

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
            color: widget.color.withValues(alpha: _opacity.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _opacity.value * 0.7),
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

class _SoundwavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _SoundwavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw concentric expanding soundwaves (propagating from the button edge)
    for (int i = 0; i < 3; i++) {
      double p = (progress + i / 3.0) % 1.0;
      // Propagate from the button edge (radius 60) to outer edge (maxRadius = 90)
      double radius = 60.0 + (p * (maxRadius - 60.0));

      double opacity = (1.0 - p).clamp(0.0, 1.0);

      // 1. Soft filled ripple
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: opacity * 0.04);
      canvas.drawCircle(center, radius, fillPaint);

      // 2. Soft glowing stroke (blur)
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = color.withValues(alpha: opacity * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(center, radius, glowPaint);

      // 3. Sharp boundary line
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withValues(alpha: opacity * 0.25);
      canvas.drawCircle(center, radius, strokePaint);
    }

    // Draw rotating outer dashed HUD ring (slightly outside the button)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotate slowly (1 full rotation every 8 seconds)
    canvas.rotate(progress * 0.5 * math.pi);

    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const int dashCount = 36;
    const double dashAngle = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 66),
        i * dashAngle,
        dashAngle * 0.4,
        false,
        dashPaint,
      );
    }
    canvas.restore();

    // Draw 4 static corner radar crosshair tick marks
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5;
    for (int angle = 0; angle < 360; angle += 90) {
      final double rad = angle * math.pi / 180;
      final double startDist = 63.0;
      final double endDist = 72.0;
      canvas.drawLine(
        Offset(center.dx + startDist * math.cos(rad), center.dy + startDist * math.sin(rad)),
        Offset(center.dx + endDist * math.cos(rad), center.dy + endDist * math.sin(rad)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoundwavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

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
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!,
              blurRadius: 24,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

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
