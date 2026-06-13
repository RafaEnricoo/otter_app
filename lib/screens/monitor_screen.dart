import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import '../models/notification_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../widgets/quick_status_banner.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  // ─── Timeline State ───
  String _selectedTimeline = '7D'; // '24H', '7D', '30D'
  String _selectedTempRoom = 'Kamar'; // 'Kamar' atau 'Dapur'

  // ─── Chart Tooltip Hover State ───
  int _hoveredBarIndex = -1;

  // ─── Interactive Luminance Local State (to avoid Firebase sync lag) ───
  double? _localLuminance;
  double _lastHapticPercent = 75.0;

  // ─── Activity Log Expansion State ───
  bool _isLogExpanded = false;

  // ─── Static / Simulated Chart Data Sets ───
  final Map<String, _ChartData> _datasets = {
    '24H': _ChartData(
      avgText: '28.2°C',
      deltaText: '+0.4°',
      isDeltaPositive: true,
      values: [26.0, 27.5, 29.0, 28.5, 27.2, 26.8],
      labels: ['04:00', '08:00', '12:00', '16:00', '20:00', '24:00'],
    ),
    '24H_Kitchen': _ChartData(
      avgText: '29.5°C',
      deltaText: '+0.8°',
      isDeltaPositive: true,
      values: [27.5, 28.8, 30.2, 29.8, 28.5, 28.0],
      labels: ['04:00', '08:00', '12:00', '16:00', '20:00', '24:00'],
    ),
    '7D': _ChartData(
      avgText: '28.0°C',
      deltaText: '+1.2°',
      isDeltaPositive: true,
      values: [26.5, 27.0, 28.2, 27.8, 28.8, 29.5, 28.1],
      labels: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
    ),
    '7D_Kitchen': _ChartData(
      avgText: '29.1°C',
      deltaText: '+1.5°',
      isDeltaPositive: true,
      values: [28.0, 28.5, 29.3, 29.0, 30.1, 30.5, 29.2],
      labels: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
    ),
    '30D': _ChartData(
      avgText: '27.6°C',
      deltaText: '-0.6°',
      isDeltaPositive: false,
      values: [27.2, 28.0, 28.5, 27.9, 27.1, 26.8],
      labels: ['Mg 1', 'Mg 2', 'Mg 3', 'Mg 4', 'Mg 5', 'Mg 6'],
    ),
    '30D_Kitchen': _ChartData(
      avgText: '28.8°C',
      deltaText: '-0.4°',
      isDeltaPositive: false,
      values: [28.2, 29.1, 29.5, 28.9, 28.3, 28.0],
      labels: ['Mg 1', 'Mg 2', 'Mg 3', 'Mg 4', 'Mg 5', 'Mg 6'],
    ),
  };

  // Drag logic calculations for Dial Circular gesture
  void _updateDialGesture(Offset localPosition, Size size) {
    final double center = size.width / 2;
    final double dx = localPosition.dx - center;
    final double dy = localPosition.dy - center;

    // Rotational angle in radians (-pi to pi)
    double angle = math.atan2(dy, dx);

    // Shift so 12 o'clock is 0 radians (starts top instead of 3 o'clock)
    double adjustedAngle = angle + math.pi / 2;
    if (adjustedAngle < 0) {
      adjustedAngle += 2 * math.pi;
    }

    // Convert from angle to percentage [0..100]
    double percentage = (adjustedAngle / (2 * math.pi)) * 100;
    
    // Clip limits
    percentage = percentage.clamp(0.0, 100.0);

    // Call light haptics ticking at every full integer value step
    if ((percentage - _lastHapticPercent).abs() >= 1.5) {
      HapticFeedback.selectionClick();
      _lastHapticPercent = percentage;
    }

    setState(() {
      _localLuminance = percentage;
    });

    FirebaseService().updateSensor('cahaya_atap', percentage.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return ValueListenableBuilder<SmarthomeState?>(
      valueListenable: FirebaseService().stateNotifier,
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

        // Initialize local dial value if not set
        _localLuminance ??= sensor.cahayaAtap.toDouble();

        final double liveTemp = _selectedTempRoom == 'Kamar' ? sensor.kamarSuhu : sensor.dapurSuhu;
        final String dataKey = _selectedTempRoom == 'Kamar' ? _selectedTimeline : '${_selectedTimeline}_Kitchen';
        final _ChartData activeData = _datasets[dataKey]!;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.containerPadding,
              vertical: isMobile ? 16.0 : AppSpacing.stackMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header Section ───
                _buildHeader(isMobile),
                
                const SizedBox(height: 16),

                // ─── Quick Analytics Summary ───
                _buildQuickAnalyticsRow(sensor, perangkat),

                SizedBox(height: isMobile ? 20.0 : AppSpacing.stackMd),

                // ─── Emergency Status/Warning Banner ───
                if (sensor.dapurFlame > 0 || sensor.tamuGerak || perangkat.buzzerAlrm) ...[
                  const QuickStatusBanner(alwaysShow: false),
                  const SizedBox(height: 16),
                ],

                // ─── Responsive Bento Grid ───
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;

                    if (width > 900) {
                      // Desktop 2-Row Bento Grid
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTempChartCard(activeData, liveTemp),
                              ),
                              const SizedBox(width: AppSpacing.gutter),
                              Expanded(
                                flex: 1,
                                child: _buildLuminanceCard(_localLuminance!),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.gutter),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: _buildHumidityCard(sensor.kamarKelembapan, sensor.dapurKelembapan),
                              ),
                              const SizedBox(width: AppSpacing.gutter),
                              Expanded(
                                flex: 2,
                                child: _buildActivityCard(),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else if (width > 600) {
                      // Tablet Layout
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildTempChartCard(activeData, liveTemp),
                                const SizedBox(height: AppSpacing.gutter),
                                _buildHumidityCard(sensor.kamarKelembapan, sensor.dapurKelembapan),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.gutter),
                          Expanded(
                            child: Column(
                              children: [
                                _buildLuminanceCard(_localLuminance!),
                                const SizedBox(height: AppSpacing.gutter),
                                _buildActivityCard(),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Mobile Layout
                      return Column(
                        children: [
                          _buildTempChartCard(activeData, liveTemp),
                          const SizedBox(height: AppSpacing.gutter),
                          _buildLuminanceCard(_localLuminance!),
                          const SizedBox(height: AppSpacing.gutter),
                          _buildHumidityCard(sensor.kamarKelembapan, sensor.dapurKelembapan),
                          const SizedBox(height: AppSpacing.gutter),
                          _buildActivityCard(),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.gutter),

                // ─── Room Status Summary ───
                _buildRoomStatusSummary(sensor, perangkat),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
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
                'Lingkungan',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: isMobile ? 28 : 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppColors.onSurface),
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Telemetri real-time dan analisis riwayat.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        // Timeline Tab Pill selector
        Container(
          height: 38,
          padding: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(AppColors.surfaceContainerLow),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1.0,
            ),
          ),
          child: Row(
            children: ['24H', '7D', '30D'].map((tab) {
              final bool isSelected = _selectedTimeline == tab;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedTimeline = tab;
                    _hoveredBarIndex = -1; // reset hover tooltip
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isSelected
                        ? Color(AppColors.secondaryContainer).withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Color(AppColors.secondaryContainer).withValues(alpha: 0.35)
                          : Colors.transparent,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    tab,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Color(AppColors.secondaryContainer)
                          : const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // B. Card 1: Temperature Chart Card
  // ─────────────────────────────────────────────────
  Widget _buildTempChartCard(_ChartData activeData, double liveTemp) {
    return _MonitorGlassCard(
      child: Stack(
        children: [
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(AppColors.secondaryContainer).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
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
                          color: Color(AppColors.secondaryContainer).withValues(alpha: 0.08),
                          border: Border.all(
                            color: Color(AppColors.secondaryContainer).withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          Icons.device_thermostat_rounded,
                          color: Color(AppColors.secondaryContainer),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SUHU RUANGAN LIVE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(AppColors.onSurfaceVariant),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${liveTemp.toStringAsFixed(1)}°C',
                                style: const TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(AppColors.onSurface),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                activeData.deltaText,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: activeData.isDeltaPositive
                                      ? Color(AppColors.secondaryContainer)
                                      : const Color(AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    height: 28,
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.03),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: ['Kamar', 'Dapur'].map((room) {
                        final bool isSel = _selectedTempRoom == room;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _selectedTempRoom = room;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: isSel
                                  ? Color(AppColors.secondaryContainer).withValues(alpha: 0.1)
                                  : Colors.transparent,
                            ),
                            child: Text(
                              room == 'Kamar' ? 'Kamar' : 'Dapur',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSel
                                    ? Color(AppColors.secondaryContainer)
                                    : const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(activeData.values.length, (index) {
                    final double originalVal = activeData.values[index];
                    final double normalizedHeight = ((originalVal - 15.0) / 20.0).clamp(0.15, 1.0) * 96;
                    final String label = activeData.labels[index];
                    final bool isHovered = _hoveredBarIndex == index;

                    return Expanded(
                      child: GestureDetector(
                        onTapDown: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _hoveredBarIndex = isHovered ? -1 : index;
                          });
                        },
                        child: Container(
                          color: Colors.transparent,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: isHovered ? 1.0 : 0.0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(AppColors.secondaryContainer),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(AppColors.secondaryContainer).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    '${originalVal.toStringAsFixed(1)}°',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(AppColors.surface),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutCubic,
                                  height: normalizedHeight,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        isHovered 
                                            ? Color(AppColors.secondaryContainer) 
                                            : Color(AppColors.secondaryContainer).withValues(alpha: 0.85),
                                        Color(AppColors.secondaryContainer).withValues(alpha: 0.02),
                                      ],
                                    ),
                                    boxShadow: isHovered 
                                        ? [
                                            BoxShadow(
                                              color: Color(AppColors.secondaryContainer).withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            )
                                          ] 
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isHovered 
                                      ? Color(AppColors.secondaryContainer) 
                                      : const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // C. Card 2: Interactive circular dial
  // ─────────────────────────────────────────────────
  Widget _buildLuminanceCard(double activeLuminance) {
    final String statusText = activeLuminance < 30.0 
        ? 'Cahaya Rendah' 
        : activeLuminance < 70.0 
            ? 'Optimal' 
            : 'Sangat Terang';

    final Color statusColor = activeLuminance < 30.0
        ? const Color(AppColors.tertiary)
        : activeLuminance < 70.0
            ? Color(AppColors.secondaryContainer)
            : const Color(AppColors.error);

    return _MonitorGlassCard(
      glowColor: Color(AppColors.secondaryContainer).withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: Color(AppColors.secondaryContainer),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'INTENSITAS CAHAYA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Center(
            child: GestureDetector(
              onPanUpdate: (details) {
                _updateDialGesture(details.localPosition, const Size(140, 140));
              },
              onTapDown: (details) {
                _updateDialGesture(details.localPosition, const Size(140, 140));
              },
              child: Container(
                width: 140,
                height: 140,
                color: Colors.transparent,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 124,
                      height: 124,
                      child: CustomPaint(
                        painter: _RadialDialPainter(
                          percentage: activeLuminance,
                          trackColor: Colors.white.withValues(alpha: 0.04),
                          progressColor: Color(AppColors.secondaryContainer),
                        ),
                      ),
                    ),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${activeLuminance.toInt()}',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(AppColors.onSurface),
                                shadows: [
                                  Shadow(
                                    color: Color(AppColors.secondaryContainer),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                            ),
                            Text(
                              '%',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(AppColors.secondaryContainer),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Center(
            child: Text(
              'Geser dial untuk mensimulasikan cahaya matahari',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // D. Card 3: Humidity Gradient Progress Card
  // ─────────────────────────────────────────────────
  Widget _buildHumidityCard(double kamarHumid, double dapurHumid) {
    return _MonitorGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_rounded,
                    color: Color(AppColors.onSurfaceVariant),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'KELEMBAPAN',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(AppColors.surfaceContainerLow),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: const Text(
                  'Multi-Ruangan',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(AppColors.onSurface),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Room 1: Kamar Tidur
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kamar Tidur',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.onSurfaceVariant),
                ),
              ),
              Text(
                '${kamarHumid.toInt()}% RH',
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: kamarHumid / 100.0),
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return Container(
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(AppColors.surfaceContainer),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1.0,
                  ),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: val,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Color(AppColors.surfaceVariant),
                          Color(AppColors.secondaryContainer),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Room 2: Dapur
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dapur',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.onSurfaceVariant),
                ),
              ),
              Text(
                '${dapurHumid.toInt()}% RH',
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: dapurHumid / 100.0),
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return Container(
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(AppColors.surfaceContainer),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1.0,
                  ),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: val,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [
                          Color(AppColors.surfaceVariant),
                          Color(AppColors.tertiary),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // E. Card 4: Recent Action Logs
  // ─────────────────────────────────────────────────
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

  Widget _buildActivityCard() {
    return ValueListenableBuilder<List<NotificationModel>>(
      valueListenable: NotificationService().notificationsNotifier,
      builder: (context, notifications, child) {
        final List<_LogItem> activeLogs = notifications.map((n) {
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

          return _LogItem(
            icon: icon,
            title: n.title,
            subtitle: '$timeStr • ${n.message}',
            accentColor: accentColor,
            isVoice: false,
          );
        }).toList();

        final int displayCount = _isLogExpanded ? activeLogs.length : 3;
        final int actualCount = math.min(displayCount, activeLogs.length);

        return _MonitorGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: Color(AppColors.onSurfaceVariant),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AKTIVITAS TERKINI',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (activeLogs.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _isLogExpanded = !_isLogExpanded;
                        });
                      },
                      child: Text(
                        _isLogExpanded ? 'Lebih Sedikit' : 'Lihat Semua',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.secondaryContainer),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (activeLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text(
                      'Tidak ada aktivitas terbaru',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              else
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: actualCount,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final _LogItem item = activeLogs[index];

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.transparent,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: item.accentColor.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: item.accentColor.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  item.icon,
                                  size: 18,
                                  color: item.accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(AppColors.onSurface),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── E. Helper: Quick Analytics Summary Row ───
  Widget _buildQuickAnalyticsRow(SmarthomeSensor sensor, SmarthomePerangkat perangkat) {
    int activeCount = 0;
    if (perangkat.lampuKamar) activeCount++;
    if (perangkat.lampuTamu) activeCount++;
    if (perangkat.lampuKamarMandi) activeCount++;
    if (perangkat.lampuDapur) activeCount++;
    if (perangkat.kipasKamar) activeCount++;
    if (perangkat.ledMerahDapur) activeCount++;
    if (perangkat.buzzerAlrm) activeCount++;
    if (!perangkat.kunciPintuRfid) activeCount++; // unlocked is considered active / open

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isSmall = width < 600;

        final List<Widget> items = [
          _buildMiniAnalyticCard(
            title: 'PERANGKAT AKTIF',
            value: '$activeCount dari 8',
            subtitle: 'Lampu, Kipas, Alarm',
            icon: Icons.bolt_rounded,
            iconColor: Color(AppColors.secondaryContainer),
          ),
          _buildMiniAnalyticCard(
            title: 'KEAMANAN AREA',
            value: sensor.tamuGerak ? 'ADA GERAKAN' : 'KONDISI AMAN',
            subtitle: perangkat.kunciPintuRfid ? 'RFID: Terkunci' : 'RFID: Terbuka',
            icon: sensor.tamuGerak ? Icons.sensors_rounded : Icons.shield_rounded,
            iconColor: sensor.tamuGerak ? const Color(0xFFFF4963) : const Color(0xFF00E676),
            valueColor: sensor.tamuGerak ? const Color(0xFFFF4963) : const Color(0xFF00E676),
          ),
          _buildMiniAnalyticCard(
            title: 'DETEKTOR API',
            value: sensor.dapurFlame > 0 ? 'BAHAYA API!' : 'NORMAL',
            subtitle: sensor.dapurFlame > 0 ? 'Deteksi di Dapur' : 'Aman dari Asap/Api',
            icon: sensor.dapurFlame > 0 ? Icons.local_fire_department_rounded : Icons.smoke_free_rounded,
            iconColor: sensor.dapurFlame > 0 ? const Color(0xFFFF4963) : const Color(0xFF00E676),
            valueColor: sensor.dapurFlame > 0 ? const Color(0xFFFF4963) : const Color(0xFF00E676),
            glowColor: sensor.dapurFlame > 0 ? const Color(0xFFFF4963).withValues(alpha: 0.1) : null,
          ),
        ];

        if (isSmall) {
          return SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.gutter),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: width * 0.75,
                  child: items[index],
                );
              },
            ),
          );
        } else {
          return Row(
            children: items.map((widget) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: widget,
              ),
            )).toList()..last = Expanded(child: items.last),
          );
        }
      },
    );
  }

  Widget _buildMiniAnalyticCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Color? valueColor,
    Color? glowColor,
  }) {
    return _MonitorGlassCard(
      glowColor: glowColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.08),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? const Color(AppColors.onSurface),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── F. Helper: Room Status Summary Widget ───
  Widget _buildRoomStatusSummary(SmarthomeSensor sensor, SmarthomePerangkat perangkat) {
    return _MonitorGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                color: Color(AppColors.onSurfaceVariant),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'STATUS PER RUANGAN',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRoomSummaryRow(
            roomName: 'Kamar Tidur',
            icon: Icons.bedroom_parent_rounded,
            devicesText: 'Lampu: ${perangkat.lampuKamar ? 'ON' : 'OFF'}  •  Kipas: ${perangkat.kipasKamar ? 'ON (Spd ${perangkat.kecepatanKipas})' : 'OFF'}',
            sensorsText: '${sensor.kamarSuhu.toStringAsFixed(1)}°C  •  ${sensor.kamarKelembapan.toInt()}% RH',
            isAlert: false,
            customColor: const Color(0xFFB388FF),
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildRoomSummaryRow(
            roomName: 'Dapur',
            icon: Icons.kitchen_rounded,
            devicesText: 'Lampu: ${perangkat.lampuDapur ? 'ON' : 'OFF'}  •  Led Merah: ${perangkat.ledMerahDapur ? 'ON' : 'OFF'}',
            sensorsText: '${sensor.dapurSuhu.toStringAsFixed(1)}°C  •  ${sensor.dapurKelembapan.toInt()}% RH${sensor.dapurFlame > 0 ? '  •  ⚠ API!' : ''}',
            isAlert: sensor.dapurFlame > 0,
            alertText: 'Peringatan Api!',
            customColor: const Color(0xFFFFD54F),
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildRoomSummaryRow(
            roomName: 'Ruang Tamu',
            icon: Icons.weekend_rounded,
            devicesText: 'Lampu: ${perangkat.lampuTamu ? 'ON' : 'OFF'}',
            sensorsText: sensor.tamuGerak ? '⚠ Gerakan Terdeteksi' : 'Gerakan: Aman',
            isAlert: sensor.tamuGerak,
            alertText: 'Gerakan!',
            customColor: const Color(0xFF80FFE8),
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildRoomSummaryRow(
            roomName: 'Kamar Mandi',
            icon: Icons.bathroom_rounded,
            devicesText: 'Lampu: ${perangkat.lampuKamarMandi ? 'ON' : 'OFF'}',
            sensorsText: 'Kondisi Normal',
            isAlert: false,
            customColor: const Color(0xFF80D8FF),
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildRoomSummaryRow(
            roomName: 'Eksterior & Keamanan',
            icon: Icons.home_work_rounded,
            devicesText: 'RFID: ${perangkat.kunciPintuRfid ? 'TERKUNCI' : 'TERBUKA'}  •  Sirine: ${perangkat.buzzerAlrm ? 'AKTIF' : 'MATI'}',
            sensorsText: 'Atap: ${sensor.cahayaAtap}% Cahaya',
            isAlert: perangkat.buzzerAlrm,
            alertText: 'Sirine Aktif!',
            customColor: Color(AppColors.secondaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSummaryRow({
    required String roomName,
    required IconData icon,
    required String devicesText,
    required String sensorsText,
    required bool isAlert,
    String? alertText,
    Color? customColor,
  }) {
    final alertColor = const Color(0xFFFF4963);
    final accentColor = isAlert ? alertColor : (customColor ?? Color(AppColors.secondaryContainer));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: 0.08),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    roomName,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(AppColors.onSurface),
                    ),
                  ),
                  if (isAlert) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: alertColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: alertColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        alertText ?? 'Pemicu Terdeteksi',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: alertColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                devicesText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              sensorsText,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isAlert ? alertColor : const Color(AppColors.onSurface),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAlert ? 'PERHATIAN' : 'SINKRON',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isAlert ? alertColor : const Color(0xFF00E676),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// SHARED MONITOR GLASS CONTAINER
// ─────────────────────────────────────────────────
class _MonitorGlassCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final EdgeInsetsGeometry? padding;

  const _MonitorGlassCard({
    required this.child,
    this.glowColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
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
              blurRadius: 20,
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

// ─────────────────────────────────────────────────
// CUSTOM RADIAL DIAL VECTOR PAINTER
// ─────────────────────────────────────────────────
class _RadialDialPainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;

  _RadialDialPainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final double sweepAngle = 2 * math.pi * (percentage / 100.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    final glowPaint = Paint()
      ..color = progressColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth + 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialDialPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _ChartData {
  final String avgText;
  final String deltaText;
  final bool isDeltaPositive;
  final List<double> values;
  final List<String> labels;

  _ChartData({
    required this.avgText,
    required this.deltaText,
    required this.isDeltaPositive,
    required this.values,
    required this.labels,
  });
}

class _LogItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isVoice;

  _LogItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isVoice,
  });
}
