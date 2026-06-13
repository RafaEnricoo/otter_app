import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import '../models/notification_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/system_settings_service.dart';
import '../widgets/quick_status_banner.dart';
import '../widgets/animated_temp_text.dart';

class HomeScreen extends StatelessWidget {
  final Function(int)? onTabSelected;
  const HomeScreen({super.key, this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<SmarthomeState?>(
      valueListenable: FirebaseService().stateNotifier,
      builder: (context, state, child) {
        if (state == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(80.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(AppColors.secondaryContainer)),
              ),
            ),
          );
        }

        final sensor = state.sensor;
        final perangkat = state.perangkat;

        // Calculate occupancy or active device count
        int activeCount = 0;
        if (perangkat.lampuKamar) activeCount++;
        if (perangkat.lampuTamu) activeCount++;
        if (perangkat.lampuKamarMandi) activeCount++;
        if (perangkat.lampuDapur) activeCount++;
        if (perangkat.kipasKamar) activeCount++;
        if (perangkat.buzzerAlrm) activeCount++;
        if (perangkat.ledMerahDapur) activeCount++;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: isMobile ? 20 : AppSpacing.stackLg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.containerPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══════════════════════════════════════════
                    // GREETING SECTION with time-based greeting
                    // ═══════════════════════════════════════════
                    _GreetingSection(),

                    const SizedBox(height: 28),

                    // ═══════════════════════════════════════════
                    // QUICK STATUS BANNER
                    // ═══════════════════════════════════════════
                    const QuickStatusBanner(
                      alwaysShow: true,
                    ),

                    const SizedBox(height: 28),

                    // ═══════════════════════════════════════════
                    // SENSOR CARDS (Temperature & Humidity)
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'Lingkungan', trailing: 'Live'),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<bool>(
                      valueListenable: SystemSettingsService().tempScaleCelsius,
                      builder: (context, isCelsius, _) {
                        return Column(
                           children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _SensorCard(
                                    icon: Icons.device_thermostat_rounded,
                                    trend: Icons.trending_up_rounded,
                                    value: '',
                                    valueWidget: AnimatedTempText(
                                      celsiusValue: sensor.kamarSuhu,
                                      isCelsius: isCelsius,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: Color(AppColors.onSurface),
                                        letterSpacing: -1.0,
                                        height: 1.0,
                                      ),
                                    ),
                                    label: 'Suhu Kamar',
                                    trendLabel: 'Optimal',
                                    trendColor: const Color(0xFF81C784),
                                    accentColor: const Color(0xFFFF8A65),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.gutter),
                                Expanded(
                                  child: _SensorCard(
                                    icon: Icons.water_drop_rounded,
                                    trend: Icons.trending_flat_rounded,
                                    value: '${sensor.kamarKelembapan.toInt()}%',
                                    label: 'Kelembapan Kamar',
                                    trendLabel: 'Stabil',
                                    trendColor: Color(AppColors.secondaryContainer),
                                    accentColor: const Color(0xFF4FC3F7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SensorCard(
                                    icon: Icons.device_thermostat_rounded,
                                    trend: Icons.trending_up_rounded,
                                    value: '',
                                    valueWidget: AnimatedTempText(
                                      celsiusValue: sensor.dapurSuhu,
                                      isCelsius: isCelsius,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: Color(AppColors.onSurface),
                                        letterSpacing: -1.0,
                                        height: 1.0,
                                      ),
                                    ),
                                    label: 'Suhu Dapur',
                                    trendLabel: 'Hangat',
                                    trendColor: const Color(0xFFFFB74D),
                                    accentColor: const Color(0xFFFFB74D),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.gutter),
                                Expanded(
                                  child: _SensorCard(
                                    icon: Icons.water_drop_rounded,
                                    trend: Icons.trending_flat_rounded,
                                    value: '${sensor.dapurKelembapan.toInt()}%',
                                    label: 'Kelembapan Dapur',
                                    trendLabel: 'Stabil',
                                    trendColor: const Color(0xFF9FA8DA),
                                    accentColor: const Color(0xFF9FA8DA),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // ═══════════════════════════════════════════
                    // FAVORITE DEVICES
                    // ═══════════════════════════════════════════
                    _SectionHeader(
                      title: 'Perangkat Favorit',
                      trailing: 'Lihat Semua',
                      onTrailingTap: () {
                        if (onTabSelected != null) {
                          onTabSelected!(1);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: isMobile ? 160 : 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        children: [
                          _DeviceCard(
                            icon: Icons.lightbulb_rounded,
                            title: 'Ruang Tamu',
                            subtitle: perangkat.lampuTamu ? 'Lampu • Menyala' : 'Lampu • Mati',
                            isActive: perangkat.lampuTamu,
                            accentColor: const Color(0xFFFFD54F),
                            width: isMobile ? screenWidth * 0.42 : 180,
                            onTap: () {
                              FirebaseService().updatePerangkat('lampu_tamu', !perangkat.lampuTamu);
                            },
                          ),
                          const SizedBox(width: 12),
                          _DeviceCard(
                            icon: Icons.door_front_door_rounded,
                            title: 'Pintu Utama',
                            subtitle: perangkat.kunciPintuRfid ? 'Terkunci' : 'Terbuka',
                            isActive: perangkat.kunciPintuRfid,
                            accentColor: Color(AppColors.secondaryContainer),
                            badgeText: perangkat.kunciPintuRfid ? 'Aman' : 'Terbuka',
                            width: isMobile ? screenWidth * 0.42 : 180,
                            onTap: () {
                              FirebaseService().updatePerangkat('kunci_pintu_rfid', !perangkat.kunciPintuRfid);
                            },
                          ),
                          const SizedBox(width: 12),
                          _DeviceCard(
                            icon: Icons.air_rounded,
                            title: 'AC / Kipas Kamar',
                            subtitle: perangkat.kipasKamar 
                                ? 'Menyala • Kecepatan ${perangkat.kecepatanKipas == 255 ? 3 : perangkat.kecepatanKipas == 170 ? 2 : 1}' 
                                : 'Mati',
                            isActive: perangkat.kipasKamar,
                            accentColor: const Color(0xFF81C784),
                            width: isMobile ? screenWidth * 0.42 : 180,
                            onTap: () {
                              FirebaseService().updatePerangkat('kipas_kamar', !perangkat.kipasKamar);
                            },
                          ),
                          const SizedBox(width: 12),
                          _DeviceCard(
                            icon: Icons.kitchen_rounded,
                            title: 'Lampu Dapur',
                            subtitle: perangkat.lampuDapur ? 'Menyala' : 'Mati',
                            isActive: perangkat.lampuDapur,
                            accentColor: const Color(0xFFFFB74D),
                            width: isMobile ? screenWidth * 0.42 : 180,
                            onTap: () {
                              FirebaseService().updatePerangkat('lampu_dapur', !perangkat.lampuDapur);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ═══════════════════════════════════════════
                    // ROOMS OVERVIEW
                    // ═══════════════════════════════════════════
                    _SectionHeader(
                      title: 'Ruangan',
                      trailing: 'Kelola',
                      onTrailingTap: () {
                        if (onTabSelected != null) {
                          onTabSelected!(1);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: isMobile ? 2 : 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isMobile ? 1.6 : 1.8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _RoomTile(
                          icon: Icons.weekend_rounded,
                          name: 'Ruang Tamu',
                          deviceCount: 3, // Tamu light, buzzer, motion
                          accentColor: const Color(0xFF81C784),
                        ),
                        _RoomTile(
                          icon: Icons.bed_rounded,
                          name: 'Kamar Tidur',
                          deviceCount: 2, // Room light, fan
                          accentColor: const Color(0xFF9FA8DA),
                        ),
                        _RoomTile(
                          icon: Icons.kitchen_rounded,
                          name: 'Dapur',
                          deviceCount: 3, // Kitchen light, warning LED, gas sensor
                          accentColor: const Color(0xFFFFB74D),
                        ),
                        _RoomTile(
                          icon: Icons.bathtub_rounded,
                          name: 'Kamar Mandi',
                          deviceCount: 1, // Bathroom light
                          accentColor: const Color(0xFF4DD0E1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ═══════════════════════════════════════════
                    // CLIMATE HISTORY
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'Riwayat Iklim', trailing: 'Live'),
                    const SizedBox(height: 14),
                    _ClimateHistoryCard(
                      kamarTemp: sensor.kamarSuhu,
                      dapurTemp: sensor.dapurSuhu,
                      kamarHumid: sensor.kamarKelembapan,
                      dapurHumid: sensor.dapurKelembapan,
                    ),

                    const SizedBox(height: 32),

                    // ═══════════════════════════════════════════
                    // RECENT ACTIVITY
                    // ═══════════════════════════════════════════
                     _SectionHeader(title: 'Aktivitas Terkini'),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<List<NotificationModel>>(
                      valueListenable: NotificationService().notificationsNotifier,
                      builder: (context, notifications, child) {
                        if (notifications.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text(
                                'Tidak ada aktivitas terbaru',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          );
                        }

                        // Display top 5 recent activities
                        final displayList = notifications.take(5).toList();
                        return Column(
                          children: displayList.map((n) {
                            final icon = _getNotificationIcon(n);
                            Color accentColor;
                            switch (n.priority) {
                              case NotificationPriority.critical:
                                accentColor = const Color(0xFFFF4963);
                                break;
                              case NotificationPriority.warning:
                                accentColor = const Color(0xFFFFB300);
                                break;
                              case NotificationPriority.info:
                                accentColor = Color(AppColors.secondaryContainer);
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

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _ActivityTile(
                                icon: icon,
                                title: n.title,
                                subtitle: '$timeStr • ${n.message}',
                                accentColor: accentColor,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

// ═══════════════════════════════════════════════════════════
// GREETING SECTION
// ═══════════════════════════════════════════════════════════
class _GreetingSection extends StatefulWidget {
  @override
  State<_GreetingSection> createState() => _GreetingSectionState();
}

class _GreetingSectionState extends State<_GreetingSection> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = _currentTime.hour;
    if (hour >= 0 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '$_greeting,',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Color(AppColors.onSurfaceVariant),
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _greeting == 'Selamat Pagi' 
                      ? '☀️' 
                      : _greeting == 'Selamat Siang' 
                          ? '⛅' 
                          : _greeting == 'Selamat Sore' 
                              ? '🌆' 
                              : '🌙',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            // Real-time clock widget on the right
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                _formatTime(_currentTime),
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(AppColors.secondaryContainer),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Mimah Dudim',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: Color(AppColors.onSurface),
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}



// ═══════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(AppColors.onSurface),
            letterSpacing: -0.3,
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Text(
                trailing!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.secondaryContainer),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SENSOR CARD (Temperature / Humidity)
// ═══════════════════════════════════════════════════════════
class _SensorCard extends StatefulWidget {
  final IconData icon;
  final IconData trend;
  final String value;
  final Widget? valueWidget;
  final String label;
  final String trendLabel;
  final Color trendColor;
  final Color accentColor;

  const _SensorCard({
    required this.icon,
    required this.trend,
    required this.value,
    this.valueWidget,
    required this.label,
    required this.trendLabel,
    required this.trendColor,
    required this.accentColor,
  });

  @override
  State<_SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<_SensorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + trend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.accentColor.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.accentColor,
                    size: 20,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: widget.trendColor.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.trend, color: widget.trendColor, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      widget.trendLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.trendColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Value
          widget.valueWidget ?? Text(
            widget.value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(AppColors.onSurface),
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          // Mini sparkline (decorative)
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(double.infinity, 24),
                painter: _SparklinePainter(
                  color: widget.accentColor,
                  progress: _shimmerController.value,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SPARKLINE PAINTER (decorative mini chart)
// ═══════════════════════════════════════════════════════════
class _SparklinePainter extends CustomPainter {
  final Color color;
  final double progress;

  _SparklinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final points = <Offset>[];
    const segments = 8;
    final segWidth = size.width / segments;

    // Generate a smooth wave
    for (int i = 0; i <= segments; i++) {
      final x = i * segWidth;
      final y = size.height * 0.5 +
          math.sin((i / segments * 2 * math.pi) + (progress * 2 * math.pi)) *
              size.height *
              0.35;
      points.add(Offset(x, y));
    }

    // Draw smooth path
    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Glowing dot at the end
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 3, dotPaint);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 6, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════
// DEVICE CARD (horizontal scrollable)
// ═══════════════════════════════════════════════════════════
class _DeviceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final Color accentColor;
  final String? badgeText;
  final double width;
  final VoidCallback? onTap;

  const _DeviceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.accentColor,
    this.badgeText,
    required this.width,
    this.onTap,
  });

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.isActive
                ? widget.accentColor.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: widget.isActive
                  ? widget.accentColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon + badge row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: widget.isActive
                          ? widget.accentColor.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        color: widget.isActive
                            ? widget.accentColor
                            : Color(AppColors.onSurfaceVariant),
                        size: 22,
                      ),
                    ),
                  ),
                  if (widget.isActive)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.accentColor,
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(AppColors.onSurface),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (widget.badgeText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: widget.accentColor.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            widget.badgeText!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: widget.accentColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ] else
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.isActive
                                ? widget.accentColor.withValues(alpha: 0.8)
                                : Color(AppColors.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ROOM TILE
// ═══════════════════════════════════════════════════════════
class _RoomTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final int deviceCount;
  final Color accentColor;

  const _RoomTile({
    required this.icon,
    required this.name,
    required this.deviceCount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accentColor.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: 18),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(AppColors.onSurface),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$deviceCount perangkat',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CLIMATE HISTORY CARD
// ═══════════════════════════════════════════════════════════
class _ClimateHistoryCard extends StatefulWidget {
  final double kamarTemp;
  final double dapurTemp;
  final double kamarHumid;
  final double dapurHumid;

  const _ClimateHistoryCard({
    required this.kamarTemp,
    required this.dapurTemp,
    required this.kamarHumid,
    required this.dapurHumid,
  });

  @override
  State<_ClimateHistoryCard> createState() => _ClimateHistoryCardState();
}

class _ClimateHistoryCardState extends State<_ClimateHistoryCard> {
  bool _showTemp = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SystemSettingsService().tempScaleCelsius,
      builder: (context, isCelsius, _) {
        // Generate historic data ending with the live values
        final List<double> kamarTempValues = [
          isCelsius ? 26.5 : (26.5 * 1.8 + 32),
          isCelsius ? 27.2 : (27.2 * 1.8 + 32),
          isCelsius ? 28.0 : (28.0 * 1.8 + 32),
          isCelsius ? 27.5 : (27.5 * 1.8 + 32),
          isCelsius ? 28.5 : (28.5 * 1.8 + 32),
          isCelsius ? 27.8 : (27.8 * 1.8 + 32),
          isCelsius ? widget.kamarTemp : (widget.kamarTemp * 1.8 + 32),
        ];
        final List<double> dapurTempValues = [
          isCelsius ? 30.0 : (30.0 * 1.8 + 32),
          isCelsius ? 31.2 : (31.2 * 1.8 + 32),
          isCelsius ? 31.8 : (31.8 * 1.8 + 32),
          isCelsius ? 30.5 : (30.5 * 1.8 + 32),
          isCelsius ? 32.0 : (32.0 * 1.8 + 32),
          isCelsius ? 31.5 : (31.5 * 1.8 + 32),
          isCelsius ? widget.dapurTemp : (widget.dapurTemp * 1.8 + 32),
        ];

        final List<double> kamarHumidValues = [58.0, 56.0, 54.0, 55.0, 53.0, 56.0, widget.kamarHumid];
        final List<double> dapurHumidValues = [62.0, 60.0, 61.5, 59.0, 63.0, 60.5, widget.dapurHumid];

        final List<String> intervals = ['04:00', '08:00', '12:00', '16:00', '20:00', '24:00', 'Live'];

        final Color kamarColor = _showTemp ? const Color(0xFFFF8A65) : Color(AppColors.secondaryContainer); // Coral vs Cyan
        final Color dapurColor = _showTemp ? const Color(0xFFFFB74D) : const Color(0xFF9FA8DA); // Amber vs Indigo

        final String title = _showTemp ? 'Suhu Lingkungan' : 'Kelembapan Lingkungan';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header of the card with toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.onSurfaceVariant),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _showTemp
                          ? Row(
                              children: [
                                AnimatedTempText(
                                  celsiusValue: widget.kamarTemp,
                                  isCelsius: isCelsius,
                                  showUnit: false,
                                  style: const TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(AppColors.onSurface),
                                  ),
                                ),
                                const Text(
                                  '° / ',
                                  style: TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(AppColors.onSurface),
                                  ),
                                ),
                                AnimatedTempText(
                                  celsiusValue: widget.dapurTemp,
                                  isCelsius: isCelsius,
                                  style: const TextStyle(
                                    fontFamily: 'Sora',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(AppColors.onSurface),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '${widget.kamarHumid.toInt()}% / ${widget.dapurHumid.toInt()}%',
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(AppColors.onSurface),
                              ),
                            ),
                    ],
                  ),
                  // Tab Pill Selector
                  Container(
                    height: 32,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.03),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showTemp = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _showTemp
                                  ? const Color(0xFFFF8A65).withValues(alpha: 0.12)
                                  : Colors.transparent,
                            ),
                            child: const Text(
                              'Suhu',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF8A65),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showTemp = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: !_showTemp
                                  ? Color(AppColors.secondaryContainer).withValues(alpha: 0.12)
                                  : Colors.transparent,
                            ),
                            child: Text(
                              'Kelembapan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(AppColors.secondaryContainer),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),

              // Legend
              Row(
                children: [
                  _buildLegendDot(kamarColor),
                  const SizedBox(width: 4),
                  _showTemp
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Suhu Kamar (',
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            ),
                            AnimatedTempText(
                              celsiusValue: widget.kamarTemp,
                              isCelsius: isCelsius,
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            ),
                            Text(
                              ')',
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            ),
                          ],
                        )
                      : Text(
                          'Kelembapan Kamar (${widget.kamarHumid.toInt()}%)',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                        ),
                  const SizedBox(width: 16),
                  _buildLegendDot(dapurColor),
                  const SizedBox(width: 4),
                  _showTemp
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Suhu Dapur (',
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            ),
                            AnimatedTempText(
                              celsiusValue: widget.dapurTemp,
                              isCelsius: isCelsius,
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            ),
                            Text(
                              ')',
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                            ),
                          ],
                        )
                      : Text(
                          'Kelembapan Dapur (${widget.dapurHumid.toInt()}%)',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                        ),
                ],
              ),

              const SizedBox(height: 20),

              // Chart
              SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ClimateChartPainter(
                    values1: _showTemp ? kamarTempValues : kamarHumidValues,
                    values2: _showTemp ? dapurTempValues : dapurHumidValues,
                    color1: kamarColor,
                    color2: dapurColor,
                    minVal: _showTemp ? (isCelsius ? 15.0 : (15.0 * 1.8 + 32)) : 0.0,
                    maxVal: _showTemp ? (isCelsius ? 38.0 : (38.0 * 1.8 + 32)) : 100.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // X-axis labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: intervals.map((label) {
                  final isLive = label == 'Live';
                  return Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
                      color: isLive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _ClimateChartPainter extends CustomPainter {
  final List<double> values1;
  final List<double> values2;
  final Color color1;
  final Color color2;
  final double minVal;
  final double maxVal;

  _ClimateChartPainter({
    required this.values1,
    required this.values2,
    required this.color1,
    required this.color2,
    required this.minVal,
    required this.maxVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values1.isEmpty || values2.isEmpty) return;

    // Draw grid lines first
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;
    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Paint line 1 (Kamar)
    _drawLine(canvas, size, values1, color1);

    // Paint line 2 (Dapur)
    _drawLine(canvas, size, values2, color2);
  }

  void _drawLine(Canvas canvas, Size size, List<double> values, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.12),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final double stepX = size.width / (values.length - 1);
    final double range = maxVal - minVal;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalized = ((values[i] - minVal) / range).clamp(0.0, 1.0);
      final y = size.height - (normalized * size.height);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Glowing dot at the live value
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 4, dotPaint);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 8, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ClimateChartPainter oldDelegate) {
    return oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.values1 != values1 ||
        oldDelegate.values2 != values2;
  }
}

// ═══════════════════════════════════════════════════════════
// ACTIVITY TILE
// ═══════════════════════════════════════════════════════════
class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accentColor.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(AppColors.onSurface),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.4),
            size: 18,
          ),
        ],
      ),
    );
  }
}
