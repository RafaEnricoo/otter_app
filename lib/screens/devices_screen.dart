import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  // ─── Environment / Sensors Simulated State ───
  double _ambientLightLdr = 42.0; // 0% (Dark) to 100% (Bright)
  double _temperatureCelsius = 26.5; // 15°C to 35°C
  double _humidityPercentage = 60.0; // 0% to 100%
  bool _isRaining = true;

  // ─── Devices Interactive State ───
  // 1. Living Room: Main Lights
  bool _mainLightsAuto = true;
  bool _mainLightsOn = true;
  double _mainLightsBrightness = 58.0; // 100 - LDR in Auto

  // 2. Living Room: Ceiling Fan
  bool _ceilingFanAuto = true;
  bool _ceilingFanOn = true;
  double _ceilingFanSpeed = 2.0; // Controlled by temp in Auto

  // 3. Bedroom: Bedside Lamp
  bool _bedsideLampAuto = false;
  bool _bedsideLampOn = false;
  double _bedsideLampBrightness = 0.0;

  // 4. Garage: Main Garage Door
  bool _garageLocked = true;

  // 5. Garage: Siren System
  bool _sirenArmed = false;

  // 6. Garage: Smart Clothesline
  bool _clotheslineAuto = true;
  bool _clotheslineClosed = true; // Closed (Raining) in Auto

  @override
  void initState() {
    super.initState();
    _updateAutoDevices();
  }

  // ─── Automatic Logic Rules ───
  void _updateAutoDevices() {
    setState(() {
      // 1. Main Lights Auto Logic (Based on LDR)
      if (_mainLightsAuto) {
        double calcBrightness = 100 - _ambientLightLdr;
        if (_ambientLightLdr > 85) {
          // Very bright outside, turn lights completely off
          _mainLightsOn = false;
          _mainLightsBrightness = 0.0;
        } else {
          _mainLightsOn = true;
          _mainLightsBrightness = calcBrightness.clamp(10.0, 100.0);
        }
      }

      // 2. Bedroom Bedside Lamp Auto Logic (Same LDR but dimmed)
      if (_bedsideLampAuto) {
        double calcBrightness = (100 - _ambientLightLdr) * 0.7; // dim bedtime lamp
        if (_ambientLightLdr > 70) {
          _bedsideLampOn = false;
          _bedsideLampBrightness = 0.0;
        } else {
          _bedsideLampOn = true;
          _bedsideLampBrightness = calcBrightness.clamp(5.0, 80.0);
        }
      }

      // 3. Ceiling Fan Auto Logic (Based on Temperature)
      if (_ceilingFanAuto) {
        if (_temperatureCelsius < 22.0) {
          _ceilingFanOn = false;
          _ceilingFanSpeed = 0.0;
        } else {
          _ceilingFanOn = true;
          if (_temperatureCelsius >= 22.0 && _temperatureCelsius < 25.0) {
            _ceilingFanSpeed = 1.0;
          } else if (_temperatureCelsius >= 25.0 && _temperatureCelsius < 28.0) {
            _ceilingFanSpeed = 2.0;
          } else {
            _ceilingFanSpeed = 3.0;
          }
        }
      }

      // 4. Smart Clothesline Auto Logic (Based on Rain/Humidity)
      if (_clotheslineAuto) {
        // If it is raining or humidity is high (> 75%), close clothesline
        if (_isRaining || _humidityPercentage > 75.0) {
          _clotheslineClosed = true;
        } else {
          _clotheslineClosed = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

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
            // ─── Page Intro header (Desktop only) ───
            if (!isMobile) ...[
              const Text(
                'Smart Devices',
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.onSurface),
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Interactive control panel synced with ambient light (LDR), temperature, and humidity sensors.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Color(AppColors.onSurfaceVariant).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ─── Room: Living Room ───
            _buildRoomSection(
              roomTitle: 'Living Room',
              children: [
                // 1. Main Lights LED Card
                _buildLEDCard(
                  title: 'Main Lights',
                  isOn: _mainLightsOn,
                  brightness: _mainLightsBrightness,
                  isAuto: _mainLightsAuto,
                  icon: Icons.lightbulb_rounded,
                  onModeChanged: (val) {
                    setState(() {
                      _mainLightsAuto = val;
                      _updateAutoDevices();
                    });
                  },
                  onToggle: (val) {
                    setState(() {
                      _mainLightsOn = val;
                      if (val && _mainLightsBrightness == 0) _mainLightsBrightness = 75.0;
                    });
                  },
                  onSliderChanged: (val) {
                    setState(() {
                      _mainLightsBrightness = val;
                      _mainLightsOn = val > 0;
                    });
                  },
                  isFullWidth: true,
                ),

                // 2. LDR Light Sensor Card (Simulation trigger)
                _buildSensorCard(
                  title: 'Ambient Light',
                  value: _ambientLightLdr.toInt().toString(),
                  unit: '%',
                  badgeText: 'LDR Sensor',
                  icon: Icons.sensors_rounded,
                  onTap: _showLdrSimulationSheet,
                  infoText: _mainLightsAuto ? 'Auto Dimmed' : 'Manual Mode',
                ),

                // 3. Ceiling Fan Card with Spinning Fan Blades
                _buildFanCard(
                  title: 'Ceiling Fan',
                  isOn: _ceilingFanOn,
                  speed: _ceilingFanSpeed,
                  isAuto: _ceilingFanAuto,
                  onModeChanged: (val) {
                    setState(() {
                      _ceilingFanAuto = val;
                      _updateAutoDevices();
                    });
                  },
                  onToggle: (val) {
                    setState(() {
                      _ceilingFanOn = val;
                    });
                  },
                  onSpeedChanged: (val) {
                    setState(() {
                      _ceilingFanSpeed = val;
                      _ceilingFanOn = val > 0;
                    });
                  },
                  isFullWidth: true,
                ),

                // 4. Temp & Humidity Sensor Card (Simulation trigger)
                _buildSensorCard(
                  title: 'Temp & Humidity',
                  value: '${_temperatureCelsius.toStringAsFixed(1)}°C',
                  unit: ' / ${_humidityPercentage.toInt()}%',
                  badgeText: 'Climate Sensor',
                  icon: Icons.thermostat_rounded,
                  onTap: _showClimateSimulationSheet,
                  infoText: _isRaining ? 'Raining Outside' : 'Dry & Sunny',
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.stackLg),

            // ─── Room: Bedroom ───
            _buildRoomSection(
              roomTitle: 'Bedroom',
              children: [
                // 1. Bedside Lamp LED Card
                _buildLEDCard(
                  title: 'Bedside Lamp',
                  isOn: _bedsideLampOn,
                  brightness: _bedsideLampBrightness,
                  isAuto: _bedsideLampAuto,
                  icon: Icons.lightbulb_outline_rounded,
                  onModeChanged: (val) {
                    setState(() {
                      _bedsideLampAuto = val;
                      _updateAutoDevices();
                    });
                  },
                  onToggle: (val) {
                    setState(() {
                      _bedsideLampOn = val;
                      if (val && _bedsideLampBrightness == 0) _bedsideLampBrightness = 50.0;
                    });
                  },
                  onSliderChanged: (val) {
                    setState(() {
                      _bedsideLampBrightness = val;
                      _bedsideLampOn = val > 0;
                    });
                  },
                  isFullWidth: true,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.stackLg),

            // ─── Room: Garage & Exterior ───
            _buildRoomSection(
              roomTitle: 'Garage & Exterior',
              children: [
                // 1. RFID Garage Door
                _buildActionCard(
                  title: 'Main Garage Door',
                  statusText: _garageLocked ? 'Locked' : 'Unlocked',
                  badgeText: _garageLocked ? 'Locked' : 'Open',
                  icon: Icons.meeting_room_rounded,
                  footerIcon: _garageLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  footerText: _garageLocked ? 'Secured' : 'Access Open',
                  isActive: _garageLocked,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _garageLocked = !_garageLocked;
                    });
                  },
                ),

                // 2. Siren System Card
                _buildToggleCard(
                  title: 'Siren System',
                  statusText: _sirenArmed ? 'Armed' : 'Disarmed',
                  isOn: _sirenArmed,
                  icon: Icons.campaign_rounded,
                  onToggle: (val) {
                    setState(() {
                      _sirenArmed = val;
                    });
                  },
                ),

                // 3. Smart Clothesline Card with Auto (Rain Sensor) Sync
                _buildClotheslineCard(
                  title: 'Smart Clothesline',
                  isClosed: _clotheslineClosed,
                  isAuto: _clotheslineAuto,
                  icon: Icons.umbrella_rounded,
                  onModeChanged: (val) {
                    setState(() {
                      _clotheslineAuto = val;
                      _updateAutoDevices();
                    });
                  },
                  onToggle: (val) {
                    setState(() {
                      _clotheslineClosed = !val; // Open is Active, Closed is Inactive
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Room Section Responsive Grid Layout
  // ─────────────────────────────────────────────────
  Widget _buildRoomSection({
    required String roomTitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
          child: Text(
            roomTitle,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(AppColors.onSurface),
              letterSpacing: -0.5,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            const double spacing = AppSpacing.gutter;

            if (width > 900) {
              // 4 columns Desktop Grid layout
              final double colWidth = (width - (spacing * 3)) / 4;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: children.map((widget) {
                  return SizedBox(width: colWidth, child: widget);
                }).toList(),
              );
            } else if (width > 600) {
              // 3 columns Tablet Grid layout
              final double colWidth = (width - (spacing * 2)) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: children.map((widget) {
                  return SizedBox(width: colWidth, child: widget);
                }).toList(),
              );
            } else {
              // 2 columns Mobile Grid layout (cards wrap or scale down)
              final double halfWidth = (width - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: children.map((widget) {
                  double cardWidth = halfWidth;
                  if (widget is _CardWidthWrapper && widget.isFullWidth) {
                    cardWidth = width; // spans full width on mobile
                  }
                  return SizedBox(width: cardWidth, child: widget);
                }).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // Interactive Simulation Sheet Panels
  // ─────────────────────────────────────────────────
  
  // A. LDR Ambient Light Sensor Simulation
  void _showLdrSimulationSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SimulationModalWrapper(
              title: 'LDR Ambient Light Sensor',
              description: 'Drag the slider to simulate room ambient light. In Auto mode, the Main Lights & Bedside Lamp dim automatically in response.',
              icon: Icons.sensors_rounded,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _ambientLightLdr < 30 
                            ? '🌑 Room is Dark' 
                            : _ambientLightLdr < 75 
                                ? '⛅ Room is Dim' 
                                : '☀️ Room is Bright',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.onSurface),
                        ),
                      ),
                      Text(
                        '${_ambientLightLdr.toInt()}%',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00F4FE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF00F4FE),
                      inactiveTrackColor: const Color(0xFF1E2020),
                      thumbColor: Colors.white,
                      trackHeight: 6,
                      overlayColor: const Color(0xFF00F4FE).withOpacity(0.15),
                    ),
                    child: Slider(
                      value: _ambientLightLdr,
                      min: 0.0,
                      max: 100.0,
                      onChanged: (val) {
                        setSheetState(() => _ambientLightLdr = val);
                        setState(() {
                          _ambientLightLdr = val;
                          _updateAutoDevices();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSyncStatusBox(
                    label: 'Sync Status (Auto Mode):',
                    details: 'Main Lights: ${_mainLightsAuto ? "${_mainLightsBrightness.toInt()}% Brightness" : "Manual override"} \nBedside Lamp: ${_bedsideLampAuto ? "${_bedsideLampBrightness.toInt()}% Brightness" : "Manual override"}',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // B. Temperature, Humidity, and Rain Sensor Simulation
  void _showClimateSimulationSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SimulationModalWrapper(
              title: 'Climate Sensor (Temp & Humidity)',
              description: 'Adjust temperature and humidity parameters to trigger system rules. Fan speed scales with temperature, and clothesline closes when raining.',
              icon: Icons.thermostat_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Temperature Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ambient Temperature',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        '${_temperatureCelsius.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00F4FE),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF00F4FE),
                      inactiveTrackColor: const Color(0xFF1E2020),
                      thumbColor: Colors.white,
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _temperatureCelsius,
                      min: 15.0,
                      max: 35.0,
                      onChanged: (val) {
                        setSheetState(() => _temperatureCelsius = val);
                        setState(() {
                          _temperatureCelsius = val;
                          _updateAutoDevices();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Humidity Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Humidity Level',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        '${_humidityPercentage.toInt()}%',
                        style: const TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00F4FE),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF00F4FE),
                      inactiveTrackColor: const Color(0xFF1E2020),
                      thumbColor: Colors.white,
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _humidityPercentage,
                      min: 0.0,
                      max: 100.0,
                      onChanged: (val) {
                        setSheetState(() => _humidityPercentage = val);
                        setState(() {
                          _humidityPercentage = val;
                          _updateAutoDevices();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Rain Sensor Switch Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rain Sensor Triggered',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.onSurface),
                        ),
                      ),
                      CustomToggleSwitch(
                        value: _isRaining,
                        onChanged: (val) {
                          setSheetState(() => _isRaining = val);
                          setState(() {
                            _isRaining = val;
                            _updateAutoDevices();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSyncStatusBox(
                    label: 'Sync Status (Auto Mode):',
                    details: 'Ceiling Fan: ${_ceilingFanAuto ? "Active (Speed ${_ceilingFanSpeed.toInt()})" : "Manual override"} \nSmart Clothesline: ${_clotheslineAuto ? (_clotheslineClosed ? "Closed (Raining)" : "Open (Dry)") : "Manual override"}',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper Widget: status box
  Widget _buildSyncStatusBox({
    required String label,
    required String details,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00F4FE),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            details,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.4,
              color: const Color(AppColors.onSurfaceVariant).withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Custom High-Fidelity Device Cards Builders
  // ─────────────────────────────────────────────────

  // 1. LED Card with Auto/Manual mode toggle
  Widget _buildLEDCard({
    required String title,
    required bool isOn,
    required double brightness,
    required bool isAuto,
    required IconData icon,
    required ValueChanged<bool> onModeChanged,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onSliderChanged,
    bool isFullWidth = false,
  }) {
    final bool canControlManually = !isAuto;

    return _CardWidthWrapper(
      isFullWidth: isFullWidth,
      child: _DeviceGlassCard(
        isActive: isOn,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Row: Icon (Left), Auto/Manual Switch (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlowingIcon(
                  icon: icon,
                  isActive: isOn,
                  glowColor: const Color(0xFF00F4FE),
                ),
                ModeSelector(
                  isAuto: isAuto,
                  onChanged: onModeChanged,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Manual Switch (Only shown/enabled if Manual, or disabled system state display)
                    Opacity(
                      opacity: canControlManually ? 1.0 : 0.5,
                      child: CustomToggleSwitch(
                        value: isOn,
                        onChanged: canControlManually ? onToggle : (val) {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAuto
                      ? 'Auto: ${isOn ? "${brightness.toInt()}% (LDR Sync)" : "Off (Bright Day)"}'
                      : isOn ? '${brightness.toInt()}% Brightness' : 'Off',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOn
                        ? const Color(0xFF00F4FE)
                        : Color(AppColors.tertiary).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                // Brightness Slider
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF00F4FE),
                      inactiveTrackColor: const Color(0xFF1E2020),
                      trackHeight: 4,
                      thumbColor: Colors.white,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: canControlManually ? 8 : 4,
                        elevation: canControlManually ? 4 : 0,
                      ),
                      overlayColor: const Color(0xFF00F4FE).withOpacity(0.15),
                      trackShape: const RectangularSliderTrackShape(),
                    ),
                    child: Slider(
                      value: isOn ? brightness : 0.0,
                      min: 0.0,
                      max: 100.0,
                      onChanged: canControlManually && isOn ? onSliderChanged : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. Sensor Card (LDR / Climate) - Displays values, clickable triggers simulation
  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required String badgeText,
    required IconData icon,
    required VoidCallback onTap,
    required String infoText,
  }) {
    return _DeviceGlassCard(
      isActive: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: const Color(0xFF00F4FE),
                size: 32,
                shadows: [
                  Shadow(
                    color: const Color(0xFF00F4FE).withOpacity(0.4),
                    blurRadius: 10,
                  )
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  color: const Color(0xFF00F4FE).withOpacity(0.08),
                  border: Border.all(
                    color: const Color(0xFF00F4FE).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Tap Simulate',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00F4FE),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.onSurface),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(AppColors.onSurface),
                      height: 1.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(AppColors.tertiary).withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                infoText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.tertiary).withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Fan Card with custom rotating aerodynamic blades
  Widget _buildFanCard({
    required String title,
    required bool isOn,
    required double speed,
    required bool isAuto,
    required ValueChanged<bool> onModeChanged,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onSpeedChanged,
    bool isFullWidth = false,
  }) {
    final bool canControlManually = !isAuto;

    return _CardWidthWrapper(
      isFullWidth: isFullWidth,
      child: _DeviceGlassCard(
        isActive: isOn,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Custom aerodynamic rotating fan blade widget!
                _SpinningFanBlade(
                  isSpinning: isOn,
                  speed: speed,
                ),
                ModeSelector(
                  isAuto: isAuto,
                  onChanged: onModeChanged,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: canControlManually ? 1.0 : 0.5,
                      child: CustomToggleSwitch(
                        value: isOn,
                        onChanged: canControlManually ? onToggle : (val) {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAuto
                      ? 'Auto: ${isOn ? "Speed ${speed.toInt()} (Temp Sync)" : "Off (< 22°C)"}'
                      : isOn ? 'Speed ${speed.toInt()}' : 'Off',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOn
                        ? const Color(0xFF00F4FE)
                        : Color(AppColors.tertiary).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                // Discrete slider (0 to 3)
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF00F4FE),
                      inactiveTrackColor: const Color(0xFF1E2020),
                      trackHeight: 4,
                      thumbColor: Colors.white,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: canControlManually ? 8 : 4,
                        elevation: canControlManually ? 4 : 0,
                      ),
                      overlayColor: const Color(0xFF00F4FE).withOpacity(0.15),
                      trackShape: const RectangularSliderTrackShape(),
                    ),
                    child: Slider(
                      value: isOn ? speed : 0.0,
                      min: 0.0,
                      max: 3.0,
                      divisions: 3,
                      onChanged: canControlManually && isOn ? onSpeedChanged : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 4. RFID Door Card
  Widget _buildActionCard({
    required String title,
    required String statusText,
    required String badgeText,
    required IconData icon,
    required IconData footerIcon,
    required String footerText,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return _DeviceGlassCard(
      isActive: isActive,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGlowingIcon(
                icon: icon,
                isActive: isActive,
                glowColor: const Color(0xFF00F4FE),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  color: isActive
                      ? const Color(0xFF00F4FE).withOpacity(0.1)
                      : Color(AppColors.surfaceContainerHigh),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF00F4FE).withOpacity(0.3)
                        : Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? const Color(0xFF00F4FE) : Color(AppColors.tertiary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.onSurface),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    footerIcon,
                    size: 14,
                    color: isActive
                        ? const Color(0xFF00F4FE)
                        : Color(AppColors.tertiary).withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    footerText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? const Color(0xFF00F4FE)
                          : Color(AppColors.tertiary).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Toggle Card (Siren Alarm)
  Widget _buildToggleCard({
    required String title,
    required String statusText,
    required bool isOn,
    required IconData icon,
    required ValueChanged<bool> onToggle,
  }) {
    return _DeviceGlassCard(
      isActive: isOn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGlowingIcon(
                icon: icon,
                isActive: isOn,
                glowColor: const Color(0xFF00F4FE),
              ),
              CustomToggleSwitch(
                value: isOn,
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.onSurface),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                statusText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOn
                      ? const Color(0xFF00F4FE)
                      : Color(AppColors.tertiary).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Clothesline Card (Custom Auto/Manual support)
  Widget _buildClotheslineCard({
    required String title,
    required bool isClosed,
    required bool isAuto,
    required IconData icon,
    required ValueChanged<bool> onModeChanged,
    required ValueChanged<bool> onToggle,
  }) {
    final bool isOpen = !isClosed;
    final bool canControlManually = !isAuto;

    return _DeviceGlassCard(
      isActive: isOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGlowingIcon(
                icon: icon,
                isActive: isOpen,
                glowColor: const Color(0xFF00F4FE),
              ),
              ModeSelector(
                isAuto: isAuto,
                onChanged: onModeChanged,
              ),
            ],
          ),
          const SizedBox(height: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(AppColors.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Opacity(
                    opacity: canControlManually ? 1.0 : 0.5,
                    child: CustomToggleSwitch(
                      value: isOpen,
                      onChanged: canControlManually ? onToggle : (val) {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isAuto 
                    ? 'Auto: ${isClosed ? "Closed (Wet/Rain)" : "Open (Dry)"}'
                    : isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOpen
                      ? const Color(0xFF00F4FE)
                      : Color(AppColors.tertiary).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // UI Helpers
  // ─────────────────────────────────────────────────
  Widget _buildGlowingIcon({
    required IconData icon,
    required bool isActive,
    required Color glowColor,
  }) {
    return isActive
        ? Icon(
            icon,
            color: glowColor,
            size: 32,
            shadows: [
              Shadow(
                color: glowColor.withOpacity(0.8),
                blurRadius: 16,
              ),
            ],
          )
        : Icon(
            icon,
            color: Color(AppColors.tertiary),
            size: 32,
          );
  }
}

// ─────────────────────────────────────────────────
// CUSTOM SPINNING FAN BLADES WIDGET (Using CustomPainter)
// ─────────────────────────────────────────────────
class _SpinningFanBlade extends StatefulWidget {
  final bool isSpinning;
  final double speed;

  const _SpinningFanBlade({
    required this.isSpinning,
    required this.speed,
  });

  @override
  State<_SpinningFanBlade> createState() => _SpinningFanBladeState();
}

class _SpinningFanBladeState extends State<_SpinningFanBlade>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isSpinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SpinningFanBlade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning != oldWidget.isSpinning || widget.speed != oldWidget.speed) {
      if (widget.isSpinning) {
        // Dynamic speed controller: speed 3 is fastest, 1 is slowest
        double speedDuration = widget.speed == 3
            ? 0.6
            : widget.speed == 2
                ? 1.3
                : 2.8;
        _controller.duration = Duration(milliseconds: (speedDuration * 1000).toInt());
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = const Color(0xFF00F4FE);
    final themeColor = widget.isSpinning ? glowColor : Color(AppColors.tertiary);

    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          boxShadow: widget.isSpinning
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.15),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: CustomPaint(
          painter: FanBladePainter(color: themeColor),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CUSTOM FAN BLADES VECTOR PAINTER
// ─────────────────────────────────────────────────
class FanBladePainter extends CustomPainter {
  final Color color;

  FanBladePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw central circular spinner cap
    canvas.drawCircle(center, radius * 0.24, paint);
    
    // Draw depth border ring
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.24, borderPaint);

    // Draw 4 aerodynamic curved ceiling fan blades
    final double bladeWidth = radius * 0.26;
    for (int i = 0; i < 4; i++) {
      final double angle = i * math.pi / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final path = Path();
      path.moveTo(0, 0);
      
      // Contoured swept-wing design
      path.cubicTo(
        -bladeWidth * 0.35, -radius * 0.25, 
        -bladeWidth * 1.0, -radius * 0.7, 
        -bladeWidth * 0.55, -radius
      );
      path.cubicTo(
        -bladeWidth * 0.15, -radius * 1.05, 
        bladeWidth * 0.45, -radius * 1.05, 
        bladeWidth * 0.55, -radius
      );
      path.cubicTo(
        bladeWidth * 1.0, -radius * 0.7, 
        bladeWidth * 0.35, -radius * 0.25, 
        0, 0
      );
      path.close();

      canvas.drawPath(path, paint);
      
      // Accent contour line details on blades
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(0, -radius * 0.6), radius * 0.08, linePaint);
      
      canvas.restore();
    }
    
    // Tiny glowing center pin
    final centerDotPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.08, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant FanBladePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────
// CUSTOM GLASS CARD CONTAINER (Uniform Border)
// ─────────────────────────────────────────────────
class _DeviceGlassCard extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final VoidCallback? onTap;

  const _DeviceGlassCard({
    required this.child,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00F4FE).withOpacity(0.35)
                : Colors.white.withOpacity(0.12),
            width: 1.0,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: const Color(0xFF00F4FE).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Grid card layout spacer wrapper
// ─────────────────────────────────────────────────
class _CardWidthWrapper extends StatelessWidget {
  final Widget child;
  final bool isFullWidth;

  const _CardWidthWrapper({
    required this.child,
    required this.isFullWidth,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

// ─────────────────────────────────────────────────
// PREMIUM SLIDING MODE SELECTOR (Auto vs Manual)
// ─────────────────────────────────────────────────
class ModeSelector extends StatelessWidget {
  final bool isAuto;
  final ValueChanged<bool> onChanged;

  const ModeSelector({
    super.key,
    required this.isAuto,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF00F4FE);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!isAuto);
      },
      child: Container(
        width: 76,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: const Color(0xFF1E2020),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Slide background pill
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: isAuto ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 38,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  color: isAuto
                      ? activeColor.withOpacity(0.15)
                      : Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: isAuto
                        ? activeColor.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
            ),
            // "Auto" Text Label
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    'Auto',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isAuto ? activeColor : Color(AppColors.tertiary).withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
            // "Manual" Text Label
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    'Man',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: !isAuto ? Colors.white : Color(AppColors.tertiary).withOpacity(0.4),
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

// ─────────────────────────────────────────────────
// PREMIUM CUSTOM SWITCH (With glow and slide animation)
// ─────────────────────────────────────────────────
class CustomToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF00F4FE);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: value ? activeColor.withOpacity(0.2) : const Color(0xFF1E2020),
          border: Border.all(
            color: value ? activeColor.withOpacity(0.4) : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? activeColor : Color(AppColors.tertiary),
                  boxShadow: value
                      ? [
                          BoxShadow(
                            color: activeColor.withOpacity(0.8),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SIMULATION SHEET CONTAINER WRAPPER (Glow glass design)
// ─────────────────────────────────────────────────
class _SimulationModalWrapper extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  const _SimulationModalWrapper({
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(AppColors.surfaceContainer).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: bottomPadding + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title area with glowing icon
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF00F4FE),
                size: 28,
                shadows: [
                  Shadow(
                    color: const Color(0xFF00F4FE).withOpacity(0.4),
                    blurRadius: 10,
                  )
                ],
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: const Color(AppColors.onSurfaceVariant).withOpacity(0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
