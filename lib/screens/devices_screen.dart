import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import '../services/firebase_service.dart';
import '../services/system_settings_service.dart';
import '../widgets/quick_status_banner.dart';
import '../widgets/animated_temp_text.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  int? _draggedBatasGelapLampu;
  double? _draggedBatasPanasKamar;

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
        final otomatisasi = state.otomatisasi;

        // Map speeds to levels 0-3
        double fanSpeedLevel = 0;
        if (perangkat.kecepatanKipas >= 200) {
          fanSpeedLevel = 3.0;
        } else if (perangkat.kecepatanKipas >= 120) {
          fanSpeedLevel = 2.0;
        } else if (perangkat.kecepatanKipas >= 50) {
          fanSpeedLevel = 1.0;
        }


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
                    'Perangkat Pintar',
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
                    'Panel kontrol interaktif yang disinkronkan dengan sensor cahaya (LDR), suhu, dan kelembapan.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // ─── Emergency Status/Warning Banner ───
                if (sensor.dapurFlame > 0 || sensor.tamuGerak || perangkat.buzzerAlrm) ...[
                  const QuickStatusBanner(alwaysShow: false),
                  const SizedBox(height: 16),
                ],

                // ─── Room: Living Room ───
                _buildRoomSection(
                  roomTitle: 'Ruang Tamu',
                  children: [
                    // 1. Lampu Ruang Tamu LED Card
                    _buildLEDCard(
                      title: 'Lampu Ruang Tamu',
                      isOn: perangkat.lampuTamu,
                      brightness: 100.0,
                      isAuto: otomatisasi.modeAutoLampuTamu,
                      icon: Icons.lightbulb_rounded,
                      onModeChanged: (val) {
                        FirebaseService().updateOtomatisasi('mode_auto_lampu_tamu', val);
                      },
                      onToggle: (val) {
                        FirebaseService().updatePerangkat('lampu_tamu', val);
                      },
                      onSliderChanged: (val) {},
                      hasSlider: false,
                      isFullWidth: true,
                      activeColor: const Color(0xFFFFD54F),
                    ),

                    // 2. Sensor Gerak Tamu Card
                    _buildSensorCard(
                      title: 'Gerak Ruang Tamu',
                      value: sensor.tamuGerak ? 'AKTIF' : 'AMAN',
                      unit: '',
                      badgeText: 'Sensor PIR',
                      icon: sensor.tamuGerak ? Icons.run_circle_rounded : Icons.motion_photos_off_rounded,
                      onTap: () => _showMotionSimulationSheet(sensor.tamuGerak),
                      infoText: sensor.tamuGerak ? '🚨 Terdeteksi Gerakan' : 'Tidak Ada Gerakan',
                      isActive: sensor.tamuGerak,
                      activeColor: Colors.orangeAccent,
                    ),

                    // 3. Siren Tamu System Card
                    _buildToggleCard(
                      title: 'Sirine Rumah',
                      statusText: perangkat.buzzerAlrm ? 'BERBUNYI (Alarm)' : 'Siaga',
                      isOn: perangkat.buzzerAlrm,
                      icon: Icons.campaign_rounded,
                      onToggle: (val) {
                        FirebaseService().updatePerangkat('buzzer_alrm', val);
                      },
                      activeColor: const Color(0xFFFF4963),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.stackLg),

                // ─── Room: Bedroom ───
                _buildRoomSection(
                  roomTitle: 'Kamar Tidur',
                  children: [
                    // 1. Lampu Kamar LED Card
                    _buildLEDCard(
                      title: 'Lampu Kamar',
                      isOn: perangkat.lampuKamar,
                      brightness: 100.0,
                      isAuto: otomatisasi.modeAutoLampuKamar,
                      icon: Icons.lightbulb_rounded,
                      onModeChanged: (val) {
                        FirebaseService().updateOtomatisasi('mode_auto_lampu_kamar', val);
                      },
                      onToggle: (val) {
                        FirebaseService().updatePerangkat('lampu_kamar', val);
                      },
                      onSliderChanged: (val) {},
                      hasSlider: false,
                      isFullWidth: true,
                      activeColor: const Color(0xFFFFD54F),
                    ),

                    // 2. Kipas Kamar Card with Spinning Blades
                    _buildFanCard(
                      title: 'Kipas Kamar',
                      isOn: perangkat.kipasKamar,
                      speed: fanSpeedLevel,
                      isAuto: otomatisasi.modeAutoKipas,
                      onModeChanged: (val) {
                        FirebaseService().updateOtomatisasi('mode_auto_kipas', val);
                      },
                      onToggle: (val) {
                        FirebaseService().updatePerangkat('kipas_kamar', val);
                        if (val && fanSpeedLevel == 0) {
                          FirebaseService().updatePerangkat('kecepatan_kipas', 255);
                        }
                      },
                      onSpeedChanged: (val) {
                        int mappedSpeed = 0;
                        if (val == 1.0) mappedSpeed = 85;
                        if (val == 2.0) mappedSpeed = 170;
                        if (val == 3.0) mappedSpeed = 255;
                        FirebaseService().updatePerangkat('kecepatan_kipas', mappedSpeed);
                        FirebaseService().updatePerangkat('kipas_kamar', val > 0);
                      },
                      isFullWidth: true,
                      activeColor: const Color(0xFF81C784),
                    ),

                    // 3. Suhu Kamar Tidur Card
                    ValueListenableBuilder<bool>(
                      valueListenable: SystemSettingsService().tempScaleCelsius,
                      builder: (context, isCelsius, _) {
                        return _buildSensorCard(
                          title: 'Suhu Kamar Tidur',
                          value: '',
                          valueWidget: AnimatedTempText(
                            celsiusValue: sensor.kamarSuhu,
                            isCelsius: isCelsius,
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(AppColors.onSurface),
                              height: 1.0,
                            ),
                          ),
                          unit: '',
                          badgeText: 'DHT11 Temp',
                          icon: Icons.thermostat_rounded,
                          onTap: () => _showClimateSimulationSheet(
                            title: 'Kamar Tidur',
                            isBedroom: true,
                            currentTemp: sensor.kamarSuhu,
                            currentHumid: sensor.kamarKelembapan,
                          ),
                          infoText: otomatisasi.modeAutoKipas ? 'Otomatisasi Kipas Aktif' : 'Kontrol iklim manual',
                          isActive: true,
                          activeColor: getTempColor(sensor.kamarSuhu),
                        );
                      },
                    ),

                    // 4. Kelembapan Kamar Tidur Card
                    _buildSensorCard(
                      title: 'Kelembapan Kamar',
                      value: '${sensor.kamarKelembapan.toInt()}%',
                      unit: '',
                      badgeText: 'DHT11 Humid',
                      icon: Icons.water_drop_rounded,
                      onTap: () => _showClimateSimulationSheet(
                        title: 'Kamar Tidur',
                        isBedroom: true,
                        currentTemp: sensor.kamarSuhu,
                        currentHumid: sensor.kamarKelembapan,
                      ),
                      infoText: 'Kelembapan optimal 40-60%',
                      isActive: true,
                      activeColor: const Color(0xFF4FC3F7),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.stackLg),

                // ─── Room: Kitchen ───
                _buildRoomSection(
                  roomTitle: 'Dapur',
                  children: [
                    // 1. Lampu Dapur LED Card
                    _buildLEDCard(
                      title: 'Lampu Dapur',
                      isOn: perangkat.lampuDapur,
                      brightness: 100.0,
                      isAuto: otomatisasi.modeAutoLampuDapur,
                      icon: Icons.lightbulb_rounded,
                      onModeChanged: (val) {
                        FirebaseService().updateOtomatisasi('mode_auto_lampu_dapur', val);
                      },
                      onToggle: (val) {
                        FirebaseService().updatePerangkat('lampu_dapur', val);
                      },
                      onSliderChanged: (val) {},
                      hasSlider: false,
                      hasAutoMode: true,
                      isFullWidth: true,
                      activeColor: const Color(0xFFFFD54F),
                    ),

                    // 2. Flame Sensor Card (Simulation trigger)
                    _buildSensorCard(
                      title: 'Detektor Api Dapur',
                      value: sensor.dapurFlame > 0 ? 'API AKTIF' : 'AMAN',
                      unit: '',
                      badgeText: 'Flame Sensor IR',
                      icon: Icons.local_fire_department_rounded,
                      onTap: () => _showSmokeSimulationSheet(sensor.dapurFlame > 0),
                      infoText: sensor.dapurFlame > 0 ? '🔥 Terdeteksi Nyala Api / Kebakaran!' : 'Area dapur aman',
                      isActive: sensor.dapurFlame > 0,
                      activeColor: const Color(0xFFFF4963),
                    ),

                    // 3. Kitchen warning LED
                    _buildToggleCard(
                      title: 'LED Merah Peringatan',
                      statusText: perangkat.ledMerahDapur ? 'PERINGATAN AKTIF' : 'Siaga',
                      isOn: perangkat.ledMerahDapur,
                      icon: Icons.circle_notifications_rounded,
                      onToggle: (val) {
                        FirebaseService().updatePerangkat('led_merah_dapur', val);
                      },
                      activeColor: Colors.redAccent,
                    ),

                    // 5. Suhu Dapur Card
                    ValueListenableBuilder<bool>(
                      valueListenable: SystemSettingsService().tempScaleCelsius,
                      builder: (context, isCelsius, _) {
                        return _buildSensorCard(
                          title: 'Suhu Dapur',
                          value: '',
                          valueWidget: AnimatedTempText(
                            celsiusValue: sensor.dapurSuhu,
                            isCelsius: isCelsius,
                            style: const TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(AppColors.onSurface),
                              height: 1.0,
                            ),
                          ),
                          unit: '',
                          badgeText: 'DHT11 Temp',
                          icon: Icons.thermostat_rounded,
                          onTap: () => _showClimateSimulationSheet(
                            title: 'Dapur',
                            isBedroom: false,
                            currentTemp: sensor.dapurSuhu,
                            currentHumid: sensor.dapurKelembapan,
                          ),
                          infoText: 'Sensor dalam ruangan dapur',
                          isActive: true,
                          activeColor: getTempColor(sensor.dapurSuhu),
                        );
                      },
                    ),

                    // 6. Kelembapan Dapur Card
                    _buildSensorCard(
                      title: 'Kelembapan Dapur',
                      value: '${sensor.dapurKelembapan.toInt()}%',
                      unit: '',
                      badgeText: 'DHT11 Humid',
                      icon: Icons.water_drop_rounded,
                      onTap: () => _showClimateSimulationSheet(
                        title: 'Dapur',
                        isBedroom: false,
                        currentTemp: sensor.dapurSuhu,
                        currentHumid: sensor.dapurKelembapan,
                      ),
                      infoText: 'Kelembapan optimal 40-60%',
                      isActive: true,
                      activeColor: const Color(0xFF4FC3F7),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.stackLg),

                // ─── Room: Bathroom ───
                _buildRoomSection(
                  roomTitle: 'Kamar Mandi',
                  children: [
                    // 1. Lampu Kamar Mandi LED Card
                    _buildLEDCard(
                      title: 'Lampu Kamar Mandi',
                      isOn: perangkat.lampuKamarMandi,
                      brightness: 100.0,
                      isAuto: otomatisasi.modeAutoLampuKamarMandi,
                      icon: Icons.lightbulb_rounded,
                      onModeChanged: (val) {
                        FirebaseService().updateOtomatisasi('mode_auto_lampu_kamar_mandi', val);
                      },
                      onToggle: (val) {
                        FirebaseService().updatePerangkat('lampu_kamar_mandi', val);
                      },
                      onSliderChanged: (val) {},
                      hasSlider: false,
                      hasAutoMode: true,
                      isFullWidth: true,
                      activeColor: const Color(0xFFFFD54F),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.stackLg),

                // ─── Room: Exterior & Security ───
                _buildRoomSection(
                  roomTitle: 'Eksterior & Gerbang Keamanan',
                  children: [
                    // 1. RFID Door Lock
                    _buildActionCard(
                      title: 'Kunci Pintu RFID',
                      statusText: perangkat.kunciPintuRfid ? 'Terkunci (Aman)' : 'Terbuka',
                      badgeText: perangkat.kunciPintuRfid ? 'Aman' : 'Akses Terbuka',
                      icon: Icons.meeting_room_rounded,
                      footerIcon: perangkat.kunciPintuRfid ? Icons.lock_rounded : Icons.lock_open_rounded,
                      footerText: perangkat.kunciPintuRfid ? 'RFID Mengunci' : 'RFID Terbuka',
                      isActive: perangkat.kunciPintuRfid,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        FirebaseService().updatePerangkat('kunci_pintu_rfid', !perangkat.kunciPintuRfid);
                      },
                    ),

                    // 2. Roof Light Sensor Card
                    _buildSensorCard(
                      title: 'Sensor Cahaya Atap',
                      value: '${sensor.cahayaAtap}',
                      unit: '%',
                      badgeText: 'LDR Photoresistor',
                      icon: Icons.wb_sunny_rounded,
                      onTap: () => _showLdrSimulationSheet(sensor.cahayaAtap),
                      infoText: (otomatisasi.modeAutoLampuTamu || otomatisasi.modeAutoLampuKamar || otomatisasi.modeAutoLampuDapur || otomatisasi.modeAutoLampuKamarMandi) ? 'Menyelaraskan lampu...' : 'Mode manual',
                      activeColor: const Color(0xFFFFB300),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.stackLg),

                // ─── Section: Automation Rules Panel ───
                _buildAutomationPanel(otomatisasi),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // Room Section Grid Layout
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
              final double colWidth = (width - (spacing * 3)) / 4;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: children.map((widget) {
                  return SizedBox(width: colWidth, child: widget);
                }).toList(),
              );
            } else if (width > 600) {
              final double colWidth = (width - (spacing * 2)) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: children.map((widget) {
                  return SizedBox(width: colWidth, child: widget);
                }).toList(),
              );
            } else {
              final double halfWidth = (width - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: children.map((widget) {
                  double cardWidth = halfWidth;
                  if (widget is _CardWidthWrapper && widget.isFullWidth) {
                    cardWidth = width;
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
  // Automation Panel Configurations
  // ─────────────────────────────────────────────────
  Widget _buildAutomationPanel(SmarthomeOtomatisasi otomatisasi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.stackSm),
          child: Text(
            'Konfigurasi Otomatisasi',
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(AppColors.onSurface),
              letterSpacing: -0.5,
            ),
          ),
        ),
        Container(
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
            children: [
              // Rule 1: Auto Light
              // Rule 1: Auto Light Kamar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Otomatisasi Lampu Kamar',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(AppColors.onSurface),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aktifkan lampu kamar otomatis saat di luar gelap',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomToggleSwitch(
                    value: otomatisasi.modeAutoLampuKamar,
                    onChanged: (val) {
                      FirebaseService().updateOtomatisasi('mode_auto_lampu_kamar', val);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 16),
              // Rule 2: Auto Light Tamu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Otomatisasi Lampu Ruang Tamu',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(AppColors.onSurface),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aktifkan lampu tamu otomatis saat di luar gelap',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomToggleSwitch(
                    value: otomatisasi.modeAutoLampuTamu,
                    onChanged: (val) {
                      FirebaseService().updateOtomatisasi('mode_auto_lampu_tamu', val);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 16),
              // Rule 3: Auto Light Kamar Mandi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Otomatisasi Lampu Kamar Mandi',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(AppColors.onSurface),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aktifkan lampu mandi otomatis saat di luar gelap',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomToggleSwitch(
                    value: otomatisasi.modeAutoLampuKamarMandi,
                    onChanged: (val) {
                      FirebaseService().updateOtomatisasi('mode_auto_lampu_kamar_mandi', val);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 16),
              // Rule 4: Auto Light Dapur
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Otomatisasi Lampu Dapur',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(AppColors.onSurface),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aktifkan lampu dapur otomatis saat di luar gelap',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomToggleSwitch(
                    value: otomatisasi.modeAutoLampuDapur,
                    onChanged: (val) {
                      FirebaseService().updateOtomatisasi('mode_auto_lampu_dapur', val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Ambang Batas Gelap (LDR):', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const Spacer(),
                  Text('${_draggedBatasGelapLampu ?? otomatisasi.batasGelapLampu}%', style: TextStyle(fontWeight: FontWeight.bold, color: Color(AppColors.secondaryContainer))),
                ],
              ),
              Slider(
                value: (_draggedBatasGelapLampu ?? otomatisasi.batasGelapLampu).toDouble(),
                min: 0,
                max: 100,
                activeColor: Color(AppColors.secondaryContainer),
                inactiveColor: const Color(0xFF1E2020),
                onChanged: (val) {
                  setState(() {
                    _draggedBatasGelapLampu = val.toInt();
                  });
                },
                onChangeEnd: (val) {
                  FirebaseService().updateOtomatisasi('batas_gelap_lampu', val.toInt());
                  setState(() {
                    _draggedBatasGelapLampu = null;
                  });
                },
              ),

              const Divider(color: Colors.white10, height: 32),

              // Rule 2: Auto Fan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mode Otomatis Kipas',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(AppColors.onSurface),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nyalakan kipas kamar dan atur kecepatan saat suhu kamar panas',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(AppColors.onSurfaceVariant).withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomToggleSwitch(
                    value: otomatisasi.modeAutoKipas,
                    onChanged: (val) {
                      FirebaseService().updateOtomatisasi('mode_auto_kipas', val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Ambang Batas Panas Kamar:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const Spacer(),
                  Text('${(_draggedBatasPanasKamar ?? otomatisasi.batasPanasKamar).toStringAsFixed(1)}°C', style: TextStyle(fontWeight: FontWeight.bold, color: Color(AppColors.secondaryContainer))),
                ],
              ),
              Slider(
                value: _draggedBatasPanasKamar ?? otomatisasi.batasPanasKamar,
                min: 15.0,
                max: 35.0,
                activeColor: Color(AppColors.secondaryContainer),
                inactiveColor: const Color(0xFF1E2020),
                onChanged: (val) {
                  setState(() {
                    _draggedBatasPanasKamar = val;
                  });
                },
                onChangeEnd: (val) {
                  FirebaseService().updateOtomatisasi('batas_panas_kamar', val);
                  setState(() {
                    _draggedBatasPanasKamar = null;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // Simulation Bottom Sheets Triggers
  // ─────────────────────────────────────────────────
  
  // A. LDR Light Sensor Simulation
  void _showLdrSimulationSheet(int currentVal) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SimulationModalWrapper(
              title: 'Sensor Cahaya Atap (LDR)',
              description: 'Seret slider untuk mensimulasikan intensitas cahaya luar ruangan. Pada mode Otomatis, Lampu Kamar & Lampu Ruang Tamu akan merespon jika intensitas di bawah ambang batas.',
              icon: Icons.wb_sunny_rounded,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentVal < 30 
                            ? '🌑 Suhu/Kondisi Gelap Gulita' 
                            : currentVal < 70 
                                ? '⛅ Kondisi Redup / Berawan' 
                                : '☀️ Kondisi Terang Benderang',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.onSurface),
                        ),
                      ),
                      Text(
                        '$currentVal%',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(AppColors.secondaryContainer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: currentVal.toDouble(),
                    min: 0.0,
                    max: 100.0,
                    activeColor: Color(AppColors.secondaryContainer),
                    inactiveColor: const Color(0xFF1E2020),
                    onChanged: (val) {
                      setSheetState(() => currentVal = val.toInt());
                    },
                    onChangeEnd: (val) {
                      FirebaseService().updateSensor('cahaya_atap', val.toInt());
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // B. Climate Simulation Sheet
  void _showClimateSimulationSheet({
    required String title,
    required bool isBedroom,
    required double currentTemp,
    required double currentHumid,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SimulationModalWrapper(
              title: 'Simulasi $title',
              description: 'Atur parameter suhu dan kelembapan untuk mensimulasikan perubahan iklim ruangan.',
              icon: Icons.thermostat_rounded,
              iconColor: getTempColor(currentTemp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Suhu Udara', style: TextStyle(color: Colors.white70)),
                      ValueListenableBuilder<bool>(
                        valueListenable: SystemSettingsService().tempScaleCelsius,
                        builder: (context, isCelsius, _) {
                          return AnimatedTempText(
                            celsiusValue: currentTemp,
                            isCelsius: isCelsius,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(AppColors.secondaryContainer),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Slider(
                    value: currentTemp,
                    min: 15.0,
                    max: 35.0,
                    activeColor: Color(AppColors.secondaryContainer),
                    inactiveColor: const Color(0xFF1E2020),
                    onChanged: (val) {
                      setSheetState(() => currentTemp = val);
                    },
                    onChangeEnd: (val) {
                      FirebaseService().updateSensor(isBedroom ? 'kamar_suhu' : 'dapur_suhu', val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kelembapan Udara', style: TextStyle(color: Colors.white70)),
                      Text('${currentHumid.toInt()}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(AppColors.secondaryContainer))),
                    ],
                  ),
                  Slider(
                    value: currentHumid,
                    min: 0.0,
                    max: 100.0,
                    activeColor: Color(AppColors.secondaryContainer),
                    inactiveColor: const Color(0xFF1E2020),
                    onChanged: (val) {
                      setSheetState(() => currentHumid = val);
                    },
                    onChangeEnd: (val) {
                      FirebaseService().updateSensor(isBedroom ? 'kamar_kelembapan' : 'dapur_kelembapan', val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // C. Flame Warning Simulation Trigger
  void _showSmokeSimulationSheet(bool hasFlame) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SimulationModalWrapper(
              title: 'Flame Sensor (Sensor Api)',
              description: 'Mensimulasikan deteksi nyala api atau kebakaran di dapur. Jika diaktifkan, Sirine & LED Peringatan Merah akan langsung menyala otomatis!',
              icon: Icons.local_fire_department_rounded,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasFlame
                            ? Icons.local_fire_department_rounded
                            : Icons.check_circle_rounded,
                        color: hasFlame
                            ? const Color(AppColors.error)
                            : Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasFlame ? 'NYALA API TERDETEKSI' : 'KONDISI DAPUR AMAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: hasFlame
                              ? const Color(AppColors.error)
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  CustomToggleSwitch(
                    value: hasFlame,
                    onChanged: (val) {
                      setSheetState(() => hasFlame = val);
                      FirebaseService().updateSensor('dapur_flame', val ? 1 : 0);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // D. Living Room Motion Simulation Trigger
  void _showMotionSimulationSheet(bool hasMotion) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SimulationModalWrapper(
              title: 'Sensor Gerak Tamu (PIR)',
              description: 'Simulasikan pergerakan di ruang tamu. Berguna untuk mendeteksi keamanan rumah.',
              icon: Icons.run_circle_rounded,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasMotion
                            ? Icons.directions_run_rounded
                            : Icons.check_circle_rounded,
                        color: hasMotion ? Colors.orange : Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasMotion ? 'ADA PERGERAKAN' : 'KONDISI SUNYI / AMAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: hasMotion ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  CustomToggleSwitch(
                    value: hasMotion,
                    onChanged: (val) {
                      setSheetState(() => hasMotion = val);
                      FirebaseService().updateSensor('tamu_gerak', val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  // Helper Widget: Custom Glass Card Builders for LED Card
  Widget _buildLEDCard({
    required String title,
    required bool isOn,
    required double brightness,
    required bool isAuto,
    required IconData icon,
    required ValueChanged<bool> onModeChanged,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onSliderChanged,
    bool hasSlider = true,
    bool hasAutoMode = true,
    bool isFullWidth = false,
    Color? activeColor,
  }) {
    final bool canControlManually = !isAuto;
    final Color actualActiveColor = activeColor ?? Color(AppColors.secondaryContainer);

    return _CardWidthWrapper(
      isFullWidth: isFullWidth,
      child: _DeviceGlassCard(
        isActive: isOn,
        activeColor: actualActiveColor,
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
                  glowColor: actualActiveColor,
                ),
                if (hasAutoMode)
                  ModeSelector(
                    isAuto: isAuto,
                    onChanged: onModeChanged,
                    activeColor: actualActiveColor,
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
                        activeColor: actualActiveColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAuto
                      ? 'Otomatis (Sinkron Sensor)'
                      : isOn ? 'Aktif' : 'Mati',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOn
                        ? actualActiveColor
                        : Color(AppColors.tertiary).withValues(alpha: 0.7),
                  ),
                ),
                if (hasSlider) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 20,
                    child: Slider(
                      value: isOn ? brightness : 0.0,
                      min: 0.0,
                      max: 100.0,
                      activeColor: actualActiveColor,
                      inactiveColor: const Color(0xFF1E2020),
                      onChanged: canControlManually && isOn ? onSliderChanged : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Sensor Card displaying values
  Widget _buildSensorCard({
    required String title,
    required String value,
    Widget? valueWidget,
    required String unit,
    required String badgeText,
    required IconData icon,
    required VoidCallback onTap,
    required String infoText,
    bool isActive = false,
    Color? activeColor,
  }) {
    final Color actualActiveColor = activeColor ?? Color(AppColors.secondaryContainer);

    return _DeviceGlassCard(
      isActive: isActive,
      activeColor: actualActiveColor,
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
                color: isActive ? actualActiveColor : Color(AppColors.secondaryContainer),
                size: 32,
                shadows: [
                  Shadow(
                    color: (isActive ? actualActiveColor : Color(AppColors.secondaryContainer)).withValues(alpha: 0.4),
                    blurRadius: 10,
                  )
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  color: (isActive ? actualActiveColor : Color(AppColors.secondaryContainer)).withValues(alpha: 0.08),
                  border: Border.all(
                    color: (isActive ? actualActiveColor : Color(AppColors.secondaryContainer)).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? actualActiveColor : Color(AppColors.secondaryContainer),
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
                  valueWidget ?? Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isActive ? actualActiveColor : const Color(AppColors.onSurface),
                      height: 1.0,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 2),
                      child: Text(
                        unit,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.tertiary).withValues(alpha: 0.7),
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
                  color: isActive ? actualActiveColor.withValues(alpha: 0.8) : Color(AppColors.tertiary).withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Fan Card with spinning blade animation
  Widget _buildFanCard({
    required String title,
    required bool isOn,
    required double speed,
    required bool isAuto,
    required ValueChanged<bool> onModeChanged,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onSpeedChanged,
    bool isFullWidth = false,
    Color? activeColor,
  }) {
    final bool canControlManually = !isAuto;
    final Color actualActiveColor = activeColor ?? Color(AppColors.secondaryContainer);

    return _CardWidthWrapper(
      isFullWidth: isFullWidth,
      child: _DeviceGlassCard(
        isActive: isOn,
        activeColor: actualActiveColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SpinningFanBlade(
                  isSpinning: isOn,
                  speed: speed,
                  activeColor: actualActiveColor,
                ),
                ModeSelector(
                  isAuto: isAuto,
                  onChanged: onModeChanged,
                  activeColor: actualActiveColor,
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
                        activeColor: actualActiveColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAuto
                      ? 'Otomatis (Sinkron Suhu)'
                      : isOn ? 'Kecepatan ${speed.toInt()}' : 'Mati',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOn
                        ? actualActiveColor
                        : Color(AppColors.tertiary).withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 20,
                  child: Slider(
                    value: isOn ? speed : 0.0,
                    min: 0.0,
                    max: 3.0,
                    divisions: 3,
                    activeColor: actualActiveColor,
                    inactiveColor: const Color(0xFF1E2020),
                    onChanged: canControlManually && isOn ? onSpeedChanged : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Biometric door card
  Widget _buildActionCard({
    required String title,
    required String statusText,
    required String badgeText,
    required IconData icon,
    required IconData footerIcon,
    required String footerText,
    required bool isActive,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final Color actualActiveColor = activeColor ?? Color(AppColors.secondaryContainer);

    return _DeviceGlassCard(
      isActive: isActive,
      activeColor: actualActiveColor,
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
                glowColor: actualActiveColor,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  color: isActive
                      ? actualActiveColor.withValues(alpha: 0.1)
                      : Color(AppColors.surfaceContainerHigh),
                  border: Border.all(
                    color: isActive
                        ? actualActiveColor.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? actualActiveColor : Color(AppColors.tertiary),
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
                        ? actualActiveColor
                        : Color(AppColors.tertiary).withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    footerText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? actualActiveColor
                          : Color(AppColors.tertiary).withValues(alpha: 0.6),
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

  // Toggle switch card
  Widget _buildToggleCard({
    required String title,
    required String statusText,
    required bool isOn,
    required IconData icon,
    required ValueChanged<bool> onToggle,
    Color? activeColor,
  }) {
    final Color actualActiveColor = activeColor ?? Color(AppColors.secondaryContainer);

    return _DeviceGlassCard(
      isActive: isOn,
      activeColor: actualActiveColor,
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
                glowColor: actualActiveColor,
              ),
              CustomToggleSwitch(
                value: isOn,
                onChanged: onToggle,
                activeColor: actualActiveColor,
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
                      ? actualActiveColor
                      : Color(AppColors.tertiary).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                color: glowColor.withValues(alpha: 0.8),
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
  final Color? activeColor;

  const _SpinningFanBlade({
    required this.isSpinning,
    required this.speed,
    this.activeColor,
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
    double speedDuration = widget.speed == 3
        ? 0.6
        : widget.speed == 2
            ? 1.3
            : 2.8;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (speedDuration * 1000).toInt()),
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
    final glowColor = widget.activeColor ?? Color(AppColors.secondaryContainer);
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
                    color: glowColor.withValues(alpha: 0.15),
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

    canvas.drawCircle(center, radius * 0.24, paint);
    
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.24, borderPaint);

    final double bladeWidth = radius * 0.26;
    for (int i = 0; i < 4; i++) {
      final double angle = i * math.pi / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final path = Path();
      path.moveTo(0, 0);
      
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
      
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(0, -radius * 0.6), radius * 0.08, linePaint);
      
      canvas.restore();
    }
    
    final centerDotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.08, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant FanBladePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DeviceGlassCard extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final VoidCallback? onTap;
  final Color? activeColor;

  const _DeviceGlassCard({
    required this.child,
    this.isActive = false,
    this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = activeColor ?? Color(AppColors.secondaryContainer);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isActive
                ? glowColor.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: glowColor.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
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

class ModeSelector extends StatelessWidget {
  final bool isAuto;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const ModeSelector({
    super.key,
    required this.isAuto,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final actColor = activeColor ?? Color(AppColors.secondaryContainer);

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
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
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
                      ? actColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isAuto
                        ? actColor.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
            ),
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
                      color: isAuto ? actColor : Color(AppColors.tertiary).withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
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
                      color: !isAuto ? Colors.white : Color(AppColors.tertiary).withValues(alpha: 0.4),
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

class CustomToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const CustomToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final actColor = activeColor ?? Color(AppColors.secondaryContainer);
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
          color: value ? actColor.withValues(alpha: 0.2) : const Color(0xFF1E2020),
          border: Border.all(
            color: value ? actColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
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
                  color: value ? actColor : Color(AppColors.tertiary),
                  boxShadow: value
                      ? [
                          BoxShadow(
                            color: actColor.withValues(alpha: 0.8),
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

class _SimulationModalWrapper extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget child;
  final Color? iconColor;

  const _SimulationModalWrapper({
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(AppColors.surfaceContainer).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
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
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? Color(AppColors.secondaryContainer),
                size: 28,
                shadows: [
                  Shadow(
                    color: (iconColor ?? Color(AppColors.secondaryContainer)).withValues(alpha: 0.4),
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
              color: const Color(AppColors.onSurfaceVariant).withValues(alpha: 0.7),
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
