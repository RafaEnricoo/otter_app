import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  // ─── Timeline State ───
  String _selectedTimeline = '7D'; // '24H', '7D', '30D'

  // ─── Chart Tooltip Hover State ───
  int _hoveredBarIndex = -1;

  // ─── Interactive Luminance State ───
  double _luminancePercent = 75.0;
  double _lastHapticPercent = 75.0;

  // ─── Activity Log Expansion State ───
  bool _isLogExpanded = false;

  // ─── Static / Simulated Chart Data Sets ───
  final Map<String, _ChartData> _datasets = {
    '24H': _ChartData(
      avgText: '71.2°',
      deltaText: '+0.4°',
      isDeltaPositive: true,
      values: [65.0, 68.0, 74.0, 76.0, 72.0, 66.0],
      labels: ['04:00', '08:00', '12:00', '16:00', '20:00', '24:00'],
    ),
    '7D': _ChartData(
      avgText: '72.0°',
      deltaText: '+1.2°',
      isDeltaPositive: true,
      values: [68.0, 70.0, 73.0, 71.0, 75.0, 77.0, 74.0],
      labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    ),
    '30D': _ChartData(
      avgText: '70.8°',
      deltaText: '-0.6°',
      isDeltaPositive: false,
      values: [69.0, 71.0, 73.0, 72.0, 70.0, 68.0],
      labels: ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4', 'Wk 5', 'Wk 6'],
    ),
  };

  // ─── Activity Log Mock Data ───
  final List<_LogItem> _logItems = [
    _LogItem(
      icon: Icons.mic_rounded,
      title: 'Voice command: "Open Gate"',
      subtitle: 'Just now • Perimeter Security',
      accentColor: const Color(0xFF00F4FE),
      isVoice: true,
    ),
    _LogItem(
      icon: Icons.lightbulb_rounded,
      title: 'Lights dimmed to 20%',
      subtitle: '10:00 PM • Living Room',
      accentColor: const Color(AppColors.tertiary),
      isVoice: false,
    ),
    _LogItem(
      icon: Icons.thermostat_auto_rounded,
      title: 'Climate schedule activated (Night)',
      subtitle: '09:30 PM • HVAC System',
      accentColor: const Color(AppColors.tertiary),
      isVoice: false,
    ),
    _LogItem(
      icon: Icons.lock_rounded,
      title: 'Main Garage Door locked',
      subtitle: '08:15 PM • Garage & Security',
      accentColor: const Color(0xFF00F4FE),
      isVoice: false,
    ),
    _LogItem(
      icon: Icons.umbrella_rounded,
      title: 'Clothesline closed automatically',
      subtitle: '07:45 PM • Rain Sensor Sync',
      accentColor: const Color(0xFF00F4FE),
      isVoice: false,
    ),
    _LogItem(
      icon: Icons.sensors_rounded,
      title: 'Light sensor (LDR) calibrated',
      subtitle: '06:00 PM • Home Automation',
      accentColor: const Color(AppColors.tertiary),
      isVoice: false,
    ),
  ];

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
      _luminancePercent = percentage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final _ChartData activeData = _datasets[_selectedTimeline]!;

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
            
            SizedBox(height: isMobile ? 24.0 : AppSpacing.stackLg),

            // ─── Responsive Bento Grid ───
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;

                if (width > 900) {
                  // Desktop 2-Row Bento Grid
                  return Column(
                    children: [
                      // Row 1: Chart Card (8 cols) & Circular Dial Card (4 cols)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTempChartCard(activeData),
                          ),
                          const SizedBox(width: AppSpacing.gutter),
                          Expanded(
                            flex: 1,
                            child: _buildLuminanceCard(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      // Row 2: Humidity Progress (4 cols) & Logs Card (8 cols)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildHumidityCard(),
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
                  // Tablet Balanced 2-Column Layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column
                      Expanded(
                        child: Column(
                          children: [
                            _buildTempChartCard(activeData),
                            const SizedBox(height: AppSpacing.gutter),
                            _buildHumidityCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.gutter),
                      // Right Column
                      Expanded(
                        child: Column(
                          children: [
                            _buildLuminanceCard(),
                            const SizedBox(height: AppSpacing.gutter),
                            _buildActivityCard(),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile Single-Column Vertical Stack Layout
                  return Column(
                    children: [
                      _buildTempChartCard(activeData),
                      const SizedBox(height: AppSpacing.gutter),
                      _buildLuminanceCard(),
                      const SizedBox(height: AppSpacing.gutter),
                      _buildHumidityCard(),
                      const SizedBox(height: AppSpacing.gutter),
                      _buildActivityCard(),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // A. Header Widget (Title & Premium Timeline Selectors)
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
                'Environment',
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
                'Real-time telemetry and historical analysis.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: const Color(AppColors.onSurfaceVariant).withOpacity(0.7),
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
              color: Colors.white.withOpacity(0.06),
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
                        ? const Color(0xFF00F4FE).withOpacity(0.12)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00F4FE).withOpacity(0.35)
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
                          ? const Color(0xFF00F4FE)
                          : const Color(AppColors.onSurfaceVariant).withOpacity(0.6),
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
  // B. Card 1: Temperature Custom Animated Bar Chart
  // ─────────────────────────────────────────────────
  Widget _buildTempChartCard(_ChartData activeData) {
    return _MonitorGlassCard(
      child: Stack(
        children: [
          // Ambient Radial backglow
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
                    const Color(0xFF00F4FE).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description row
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
                          color: const Color(0xFF00F4FE).withOpacity(0.08),
                          border: Border.all(
                            color: const Color(0xFF00F4FE).withOpacity(0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.device_thermostat_rounded,
                          color: Color(0xFF00F4FE),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AVG TEMP',
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
                                activeData.avgText,
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
                                      ? const Color(0xFF00F4FE)
                                      : const Color(AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    color: const Color(AppColors.onSurfaceVariant).withOpacity(0.6),
                    onPressed: () {},
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bar Chart Layout with dynamic hover tooltips!
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(activeData.values.length, (index) {
                    final double originalVal = activeData.values[index];
                    // Normalize bar height inside our 100px range
                    final double normalizedHeight = ((originalVal - 60.0) / 25.0).clamp(0.15, 1.0) * 96;
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
                          color: Colors.transparent, // expand gesture detector area
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Floating numeric popup tooltip
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: isHovered ? 1.0 : 0.0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00F4FE),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00F4FE).withOpacity(0.3),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    '${originalVal.toInt()}°',
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
                              // Rounded Bar Container
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
                                            ? const Color(0xFF00F4FE) 
                                            : const Color(0xFF00F4FE).withOpacity(0.85),
                                        const Color(0xFF00F4FE).withOpacity(0.02),
                                      ],
                                    ),
                                    boxShadow: isHovered 
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF00F4FE).withOpacity(0.25),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            )
                                          ] 
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // X-Axis labels
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isHovered 
                                      ? const Color(0xFF00F4FE) 
                                      : const Color(AppColors.onSurfaceVariant).withOpacity(0.6),
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
  // C. Card 2: Interactive Luminance Circular Dial
  // ─────────────────────────────────────────────────
  Widget _buildLuminanceCard() {
    // Generate description based on active percentage value
    final String statusText = _luminancePercent < 30.0 
        ? 'Low Ambient' 
        : _luminancePercent < 70.0 
            ? 'Optimal' 
            : 'Overexposed';

    final Color statusColor = _luminancePercent < 30.0
        ? const Color(AppColors.tertiary)
        : _luminancePercent < 70.0
            ? const Color(0xFF00F4FE)
            : const Color(AppColors.error);

    return _MonitorGlassCard(
      glowColor: const Color(0xFF00F4FE).withOpacity(0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            children: [
              const Icon(
                Icons.lightbulb_rounded,
                color: Color(0xFF00F4FE),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'LUMINANCE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppColors.onSurfaceVariant).withOpacity(0.7),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Central circular canvas Dial
          Center(
            child: GestureDetector(
              onPanUpdate: (details) {
                // Dial container is 140x140
                _updateDialGesture(details.localPosition, const Size(140, 140));
              },
              onTapDown: (details) {
                _updateDialGesture(details.localPosition, const Size(140, 140));
              },
              child: Container(
                width: 140,
                height: 140,
                color: Colors.transparent, // gesture hit-testing
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Canvas paint stroke arc
                    SizedBox(
                      width: 124,
                      height: 124,
                      child: CustomPaint(
                        painter: _RadialDialPainter(
                          percentage: _luminancePercent,
                          trackColor: Colors.white.withOpacity(0.04),
                          progressColor: const Color(0xFF00F4FE),
                        ),
                      ),
                    ),

                    // Central values text
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${_luminancePercent.toInt()}',
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(AppColors.onSurface),
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF00F4FE),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                            ),
                            const Text(
                              '%',
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00F4FE),
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
          
          // Instruction tip
          Center(
            child: Text(
              'Drag along the dial to adjust',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                color: const Color(AppColors.onSurfaceVariant).withOpacity(0.4),
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
  Widget _buildHumidityCard() {
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
                    'HUMIDITY',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppColors.onSurfaceVariant).withOpacity(0.7),
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
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
                child: const Text(
                  'Indoor',
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

          const SizedBox(height: 20),

          const Text(
            '45%',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(AppColors.onSurface),
            ),
          ),

          const SizedBox(height: 12),

          // Horizontal Progress Bar with gradient
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 0.45),
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(AppColors.surfaceContainer),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
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
  // E. Card 4: Recent Activity Action Logs list
  // ─────────────────────────────────────────────────
  Widget _buildActivityCard() {
    // Determine how many items to display
    final int displayCount = _isLogExpanded ? _logItems.length : 3;

    return _MonitorGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                    'RECENT ACTIONS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppColors.onSurfaceVariant).withOpacity(0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _isLogExpanded = !_isLogExpanded;
                  });
                },
                child: Text(
                  _isLogExpanded ? 'Show Less' : 'View All',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00F4FE),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Lists Items with smooth heights transition
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayCount,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final _LogItem item = _logItems[index];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.transparent,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Log Icon with neon glow on voice actions
                      Icon(
                        item.icon,
                        size: 20,
                        color: item.accentColor,
                        shadows: item.isVoice 
                            ? [
                                Shadow(
                                  color: item.accentColor.withOpacity(0.6),
                                  blurRadius: 8,
                                )
                              ] 
                            : null,
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
                                color: const Color(AppColors.onSurfaceVariant).withOpacity(0.5),
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
  }
}

// ─────────────────────────────────────────────────
// SHARED MONITOR GLASS CONTAINER (Uniform Border)
// ─────────────────────────────────────────────────
class _MonitorGlassCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;

  const _MonitorGlassCard({
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
              blurRadius: 20,
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

    // Track Circle Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc Paint
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final double sweepAngle = 2 * math.pi * (percentage / 100.0);

    // Draw active neon progress arc from top 12 o'clock (-pi/2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Dynamic blur/glow filter arc
    final glowPaint = Paint()
      ..color = progressColor.withOpacity(0.3)
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

// ─── Chart Data Helper Struct ───
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

// ─── Log Item Helper Struct ───
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
