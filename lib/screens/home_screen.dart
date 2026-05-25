import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import '../services/firebase_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<SmarthomeState?>(
      valueListenable: FirebaseService().stateNotifier,
      builder: (context, state, child) {
        if (state == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(80.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F4FE)),
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
        if (perangkat.buzzerDapur) activeCount++;
        if (perangkat.buzzerTamu) activeCount++;
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
                    _QuickStatusBanner(
                      activeCount: activeCount,
                      isLocked: perangkat.kunciPintuRfid,
                      hasSiren: perangkat.buzzerDapur || perangkat.buzzerTamu,
                      hasGas: sensor.dapurAsapApi > 0,
                    ),

                    const SizedBox(height: 28),

                    // ═══════════════════════════════════════════
                    // SENSOR CARDS (Temperature & Humidity)
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'Environment', trailing: 'Live'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SensorCard(
                            icon: Icons.device_thermostat_rounded,
                            trend: Icons.trending_up_rounded,
                            value: '${sensor.kamarSuhu.toStringAsFixed(1)}°C',
                            label: 'Room Temp',
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
                            label: 'Room Humidity',
                            trendLabel: 'Stable',
                            trendColor: const Color(0xFF00F4FE),
                            accentColor: const Color(0xFF4FC3F7),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ═══════════════════════════════════════════
                    // FAVORITE DEVICES
                    // ═══════════════════════════════════════════
                    _SectionHeader(
                      title: 'Favorite Devices',
                      trailing: 'See All',
                      onTrailingTap: () {},
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
                            title: 'Living Room',
                            subtitle: perangkat.lampuTamu ? 'Lights • On' : 'Lights • Off',
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
                            title: 'Main Door',
                            subtitle: perangkat.kunciPintuRfid ? 'Locked' : 'Unlocked',
                            isActive: perangkat.kunciPintuRfid,
                            accentColor: Color(AppColors.secondaryContainer),
                            badgeText: perangkat.kunciPintuRfid ? 'Secured' : 'Open',
                            width: isMobile ? screenWidth * 0.42 : 180,
                            onTap: () {
                              FirebaseService().updatePerangkat('kunci_pintu_rfid', !perangkat.kunciPintuRfid);
                            },
                          ),
                          const SizedBox(width: 12),
                          _DeviceCard(
                            icon: Icons.air_rounded,
                            title: 'AC / Fan Room',
                            subtitle: perangkat.kipasKamar 
                                ? 'On • Speed ${perangkat.kecepatanKipas == 255 ? 3 : perangkat.kecepatanKipas == 170 ? 2 : 1}' 
                                : 'Off',
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
                            title: 'Kitchen Light',
                            subtitle: perangkat.lampuDapur ? 'On' : 'Off',
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
                    _SectionHeader(title: 'Rooms', trailing: 'Manage'),
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
                          name: 'Living Room',
                          deviceCount: 3, // Tamu light, buzzer, motion
                          accentColor: const Color(0xFF81C784),
                        ),
                        _RoomTile(
                          icon: Icons.bed_rounded,
                          name: 'Bedroom',
                          deviceCount: 2, // Room light, fan
                          accentColor: const Color(0xFF9FA8DA),
                        ),
                        _RoomTile(
                          icon: Icons.kitchen_rounded,
                          name: 'Kitchen',
                          deviceCount: 4, // Kitchen light, warning LED, buzzer, gas sensor
                          accentColor: const Color(0xFFFFB74D),
                        ),
                        _RoomTile(
                          icon: Icons.bathtub_rounded,
                          name: 'Bathroom',
                          deviceCount: 1, // Bathroom light
                          accentColor: const Color(0xFF4DD0E1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ═══════════════════════════════════════════
                    // ENERGY USAGE
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'Energy Usage', trailing: 'This Week'),
                    const SizedBox(height: 14),
                    _EnergyCard(),

                    const SizedBox(height: 32),

                    // ═══════════════════════════════════════════
                    // RECENT ACTIVITY
                    // ═══════════════════════════════════════════
                    _SectionHeader(title: 'Recent Activity'),
                    const SizedBox(height: 14),
                    _ActivityTile(
                      icon: Icons.lock_rounded,
                      title: perangkat.kunciPintuRfid ? 'Front door locked' : 'Front door unlocked',
                      subtitle: 'Live Telemetry',
                      accentColor: Color(AppColors.secondaryContainer),
                    ),
                    const SizedBox(height: 8),
                    _ActivityTile(
                      icon: Icons.lightbulb_outline_rounded,
                      title: perangkat.lampuTamu ? 'Living room lights turned on' : 'Living room lights turned off',
                      subtitle: 'Synced with Firebase',
                      accentColor: const Color(0xFFFFD54F),
                    ),
                    const SizedBox(height: 8),
                    _ActivityTile(
                      icon: Icons.thermostat_rounded,
                      title: 'Room Temp calibrated at ${sensor.kamarSuhu.toStringAsFixed(1)}°C',
                      subtitle: 'Live Sensor Telemetry',
                      accentColor: const Color(0xFFFF8A65),
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
}

// ═══════════════════════════════════════════════════════════
// GREETING SECTION
// ═══════════════════════════════════════════════════════════
class _GreetingSection extends StatelessWidget {
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              '👋',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Alex Rivers',
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
// QUICK STATUS BANNER
// ═══════════════════════════════════════════════════════════
class _QuickStatusBanner extends StatelessWidget {
  final int activeCount;
  final bool isLocked;
  final bool hasSiren;
  final bool hasGas;

  const _QuickStatusBanner({
    required this.activeCount,
    required this.isLocked,
    required this.hasSiren,
    required this.hasGas,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAlert = hasGas || hasSiren;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isAlert
              ? [
                  const Color(AppColors.error).withOpacity(0.12),
                  const Color(AppColors.error).withOpacity(0.04),
                ]
              : [
                  Color(AppColors.secondaryContainer).withOpacity(0.08),
                  Color(AppColors.primary).withOpacity(0.04),
                ],
        ),
        border: Border.all(
          color: isAlert
              ? const Color(AppColors.error).withOpacity(0.35)
              : Color(AppColors.secondaryContainer).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Shield / Warning icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isAlert
                  ? const Color(AppColors.error).withOpacity(0.12)
                  : Color(AppColors.secondaryContainer).withOpacity(0.12),
            ),
            child: Center(
              child: Icon(
                isAlert ? Icons.warning_rounded : Icons.verified_user_rounded,
                color: isAlert ? const Color(AppColors.error) : Color(AppColors.secondaryContainer),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasGas 
                      ? 'CRITICAL: Gas/Smoke detected!'
                      : hasSiren
                          ? 'EMERGENCY: Siren Active!'
                          : 'Home is secure',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isAlert ? const Color(AppColors.error) : Color(AppColors.onSurface),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasGas
                      ? 'Kitchen gas levels are abnormal. Act immediately!'
                      : hasSiren
                          ? 'Emergency sirens are active.'
                          : '$activeCount devices active • RFID lock ${isLocked ? "engaged" : "released"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAlert ? const Color(AppColors.error) : const Color(0xFF66BB6A),
              boxShadow: [
                BoxShadow(
                  color: (isAlert ? const Color(AppColors.error) : const Color(0xFF66BB6A)).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
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
                color: Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
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
  final String label;
  final String trendLabel;
  final Color trendColor;
  final Color accentColor;

  const _SensorCard({
    required this.icon,
    required this.trend,
    required this.value,
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
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
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
                  color: widget.accentColor.withOpacity(0.12),
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
                  color: widget.trendColor.withOpacity(0.1),
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
          Text(
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
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.15),
          color.withOpacity(0.0),
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
      ..color = color.withOpacity(0.3)
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
                ? widget.accentColor.withOpacity(0.06)
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: widget.isActive
                  ? widget.accentColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.08),
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
                          ? widget.accentColor.withOpacity(0.15)
                          : Colors.white.withOpacity(0.06),
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
                            color: widget.accentColor.withOpacity(0.6),
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
                            color: widget.accentColor.withOpacity(0.15),
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
                                ? widget.accentColor.withOpacity(0.8)
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
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
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
              color: accentColor.withOpacity(0.12),
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
                '$deviceCount devices',
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
// ENERGY CARD
// ═══════════════════════════════════════════════════════════
class _EnergyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Top stats row
          Row(
            children: [
              Expanded(
                child: _EnergyMetric(
                  label: 'Today',
                  value: '12.4',
                  unit: 'kWh',
                  color: Color(AppColors.secondaryContainer),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.08),
              ),
              Expanded(
                child: _EnergyMetric(
                  label: 'This Week',
                  value: '84.2',
                  unit: 'kWh',
                  color: const Color(0xFF81C784),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.08),
              ),
              Expanded(
                child: _EnergyMetric(
                  label: 'Cost',
                  value: '\$18.5',
                  unit: '',
                  color: const Color(0xFFFFB74D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Bar chart
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final values = [0.6, 0.75, 0.5, 0.85, 0.7, 0.9, 0.45];
                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final isToday = index == 5;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: values[index],
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: isToday
                                    ? Color(AppColors.secondaryContainer)
                                    : Color(AppColors.secondaryContainer)
                                        .withOpacity(0.2),
                                boxShadow: isToday
                                    ? [
                                        BoxShadow(
                                          color: Color(
                                            AppColors.secondaryContainer,
                                          ).withOpacity(0.4),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          days[index],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isToday
                                ? Color(AppColors.secondaryContainer)
                                : Color(AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _EnergyMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(AppColors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
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
        color: Colors.white.withOpacity(0.03),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
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
              color: accentColor.withOpacity(0.1),
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
            color: Color(AppColors.onSurfaceVariant).withOpacity(0.4),
            size: 18,
          ),
        ],
      ),
    );
  }
}
