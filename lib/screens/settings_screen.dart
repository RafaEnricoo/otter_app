import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../services/system_settings_service.dart';
import '../services/firebase_service.dart';
import '../services/profile_service.dart';
import 'edit_profile_screen.dart';
import 'rfid_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  // ─── Accent Colors Palette ───
  final List<Color> _accentColors = [
    const Color(0xFF00F4FE), // Neon Cyan
    const Color(0xFFFFB300), // Vibrant Amber
    const Color(0xFF39FF14), // Neon Lime Green
    const Color(0xFFFF007F), // Hot Magenta
    const Color(0xFF2979FF), // Neon Blue
    const Color(0xFFFF5722), // Sunset Orange
    const Color(0xFFD500F9), // Electric Purple
    const Color(0xFF00FFCC), // Neon Mint
    const Color(0xFFFF4081), // Radiant Pink
    const Color(0xFFCCFF00), // Neon Yellow/Lime
    const Color(0xFFFF6B6B), // Rose Pink
    const Color(0xFFFFFFFF), // Pure White
  ];
  late Color _activeAccent;

  // ─── Interactive Settings States ───
  double _glassOpacity = 0.05;
  double _autoLockDelay = 3.0; // minutes
  bool _tempScaleCelsius = true; // C or F
  String _defaultBootScreen = 'Beranda';

  // Toggle switch states
  bool _criticalAlerts = true;
  bool _climateReports = true;
  bool _energyLogs = false;
  bool _voiceAssistantRecordings = true;

  // Integrations states
  final Map<String, String> _integrationStatus = {
    'Google Home': 'CONNECTED',
    'Apple HomeKit': 'CONNECTED',
    'Amazon Alexa': 'DISCONNECTED',
    'Firebase Sync': 'CONNECTED',
  };
  final Map<String, bool> _integrationSyncing = {
    'Google Home': false,
    'Apple HomeKit': false,
    'Amazon Alexa': false,
    'Firebase Sync': false,
  };

  @override
  void initState() {
    super.initState();
    final settings = SystemSettingsService();
    _glassOpacity = settings.glassOpacity.value;
    _activeAccent = settings.activeAccent.value;
    _tempScaleCelsius = settings.tempScaleCelsius.value;
    _autoLockDelay = settings.autoLockDelay.value;
    _defaultBootScreen = settings.defaultBootScreen.value;
  }

  // Handle integration tap & mock sync animation
  void _syncIntegration(String platform) {
    if (_integrationSyncing[platform] == true) return;
    
    HapticFeedback.mediumImpact();
    setState(() {
      _integrationSyncing[platform] = true;
    });

    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _integrationSyncing[platform] = false;
        // Toggle state
        if (_integrationStatus[platform] == 'CONNECTED') {
          _integrationStatus[platform] = 'DISCONNECTED';
        } else {
          _integrationStatus[platform] = 'CONNECTED';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$platform is now ${_integrationStatus[platform]}'),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      body: Stack(
        children: [
          // ─── Ambient Glow Gradients ───
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _activeAccent.withValues(alpha: 0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBEC5E5).withValues(alpha: 0.03),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // ─── Main Content ───
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Header
                    _buildHeader(context),

                    // Bento list
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          // Card 1: User Profile Glass Card
                          _buildProfileCard(),
                          const SizedBox(height: 16),

                          // Card 2: Customization Bento Grid Row
                          _buildAppearanceCard(),
                          const SizedBox(height: 16),

                          // Card 3: Smart automation
                          _buildAutomationCard(),
                          const SizedBox(height: 16),

                          // Card 4: Notification Toggles
                          _buildNotificationsCard(),
                          const SizedBox(height: 16),

                          // Card 5: RFID Management
                          _buildRfidManagementCard(),
                          const SizedBox(height: 16),

                          // Card 6: System actions
                          _buildSystemCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header UI
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
      child: Row(
        children: [
          ClipOval(
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                tooltip: 'Back',
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Pengaturan Sistem',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFamily: 'Sora',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bento Card: User Profile
  Widget _buildProfileCard() {
    final profile = ProfileService();

    return ValueListenableBuilder<String>(
      valueListenable: profile.displayName,
      builder: (context, name, _) {
        return ValueListenableBuilder<String>(
          valueListenable: profile.role,
          builder: (context, role, _) {
            return ValueListenableBuilder<String>(
              valueListenable: profile.avatarUrl,
              builder: (context, avatar, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _glassOpacity),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Animated Avatar with Aura Glow
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  _activeAccent,
                                  _activeAccent.withValues(alpha: 0.2),
                                  const Color(0xFFBEC5E5).withValues(alpha: 0.4),
                                  _activeAccent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _activeAccent.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1E2020),
                            ),
                            child: avatar.isEmpty
                                ? Center(
                                    child: Text(
                                      profile.initials,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _activeAccent,
                                        fontFamily: 'Sora',
                                      ),
                                    ),
                                  )
                                : ClipOval(
                                    child: avatar.startsWith('data:image') && avatar.contains('base64,')
                                        ? Image.memory(
                                            base64Decode(avatar.split('base64,')[1]),
                                            width: 54,
                                            height: 54,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            avatar,
                                            width: 54,
                                            height: 54,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) => Center(
                                              child: Icon(Icons.person_rounded, color: _activeAccent, size: 24),
                                            ),
                                          ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // User info details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Profile edit button
                      ClipOval(
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.04),
                          child: IconButton(
                            icon: Icon(Icons.edit_rounded, color: _activeAccent, size: 18),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            );
          },
        );
      },
    );
  }

  // Bento Card: UI Customizer (Accent Color & Blur Slider)
  Widget _buildAppearanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tampilan & Kustomisasi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 16),

          // Color selector label
          Text(
            'PALET WARNA AKSEN',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: _accentColors.map((color) {
              final isSelected = _activeAccent == color;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  setState(() {
                    _activeAccent = color;
                  });
                  SystemSettingsService().activeAccent.value = color;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.black, size: 20)
                      : const SizedBox.shrink(),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Bento Card: Smart Preferences
  Widget _buildAutomationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Otomasi Rumah Pintar',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 16),

          // Auto Lock Delay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'JEDA AUTO-KUNCI',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.8),
              ),
              Text(
                '${_autoLockDelay.toInt()} mins',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _activeAccent),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _activeAccent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white,
              overlayColor: _activeAccent.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: _autoLockDelay,
              min: 1.0,
              max: 10.0,
              divisions: 9,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() {
                  _autoLockDelay = val;
                });
                SystemSettingsService().autoLockDelay.value = val;
              },
            ),
          ),

          const SizedBox(height: 12),

          // Temp scale selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Skala Suhu', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Satuan tampilan sensor', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
                ],
              ),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    _buildToggleButton('°C', _tempScaleCelsius, () {
                      HapticFeedback.lightImpact();
                      setState(() => _tempScaleCelsius = true);
                      SystemSettingsService().tempScaleCelsius.value = true;
                    }),
                    _buildToggleButton('°F', !_tempScaleCelsius, () {
                      HapticFeedback.lightImpact();
                      setState(() => _tempScaleCelsius = false);
                      SystemSettingsService().tempScaleCelsius.value = false;
                    }),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Default boot screen dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Layar Awal', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Tampilan default saat membuka aplikasi', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
                ],
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF1E2020),
                ),
                child: DropdownButton<String>(
                  value: _defaultBootScreen,
                  dropdownColor: const Color(0xFF1E2020),
                  borderRadius: BorderRadius.circular(12),
                  underline: const SizedBox.shrink(),
                  icon: Icon(Icons.arrow_drop_down_rounded, color: _activeAccent),
                  style: TextStyle(color: _activeAccent, fontSize: 13, fontWeight: FontWeight.w700),
                  items: <String>['Beranda', 'Perangkat', 'Monitor', 'Keamanan']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(value),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _defaultBootScreen = newValue;
                      });
                      SystemSettingsService().defaultBootScreen.value = newValue;
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Toggle button helper
  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? _activeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  // Bento Card: Notification Rules
  Widget _buildNotificationsCard() {
    final settings = SystemSettingsService();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aturan Notifikasi & Fitur Sistem',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 16),

          _buildSwitchRow('Suara Alarm Kritis', 'Aktifkan suara sirine darurat ketika alarm aktif', settings.enableAlarmSound.value, (val) {
            setState(() {
              settings.enableAlarmSound.value = val;
            });
          }),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow('Suara Notifikasi', 'Aktifkan pemberitahuan audio untuk notifikasi baru', settings.enableNotificationSound.value, (val) {
            setState(() {
              settings.enableNotificationSound.value = val;
            });
          }),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow('Getaran Sistem', 'Aktifkan respon getar / haptic feedback', settings.enableVibration.value, (val) {
            setState(() {
              settings.enableVibration.value = val;
            });
          }),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow('Peringatan Keamanan Kritis', 'Notifikasi push instan untuk alarm', _criticalAlerts, (val) {
            setState(() => _criticalAlerts = val);
          }),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow('Penyesuaian Iklim', 'Laporkan status sensor offline dan pembaruan', _climateReports, (val) {
            setState(() => _climateReports = val);
          }),
        ],
      ),
    );
  }

  // Custom switch toggle row
  Widget _buildSwitchRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
            ],
          ),
        ),
        // Beautiful Premium Toggle
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(!value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 48,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: value ? _activeAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: value ? _activeAccent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? _activeAccent : Colors.white.withValues(alpha: 0.6),
                  boxShadow: [
                    if (value)
                      BoxShadow(
                        color: _activeAccent.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  // Bento Card: System details & Factory reset
  Widget _buildSystemCard() {
    final fb = FirebaseService();
    final isOffline = fb.isUsingFallback;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Sistem',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 14),

          // Technical micro details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Versi Firmware', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
              const Text('v4.12.0-stable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status Database', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
              Text(
                isOffline ? 'Offline (Simulasi Lokal)' : 'Online (Firebase Realtime)',
                style: TextStyle(
                  color: isOffline ? const Color(0xFFFF4963) : const Color(0xFF00E676),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Alamat IP Gateway', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
              const Text('192.168.1.104', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ping Realtime Database', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
              Text(
                isOffline ? 'N/A (Terputus)' : '12 ms',
                style: TextStyle(
                  color: isOffline ? Colors.white.withValues(alpha: 0.3) : _activeAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Lock Device Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _activeAccent.withValues(alpha: 0.12),
              foregroundColor: _activeAccent,
              elevation: 0,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _activeAccent.withValues(alpha: 0.2)),
              ),
            ),
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('Kunci Layar Sekarang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context); // Close Settings screen
              SystemSettingsService().lockScreenTrigger.value = true; // Trigger lock screen
            },
          ),

          const SizedBox(height: 12),

          // Reset system button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF93000A).withValues(alpha: 0.12),
              foregroundColor: const Color(0xFFFFB4AB),
              elevation: 0,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: const Color(0xFFFF4963).withValues(alpha: 0.2)),
              ),
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showResetDialog();
            },
            child: const Text('Reset Gateway', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // Bento Card: RFID Access Management
  Widget _buildRfidManagementCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manajemen Akses RFID',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola daftar kartu RFID terdaftar untuk akses masuk rumah.',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _activeAccent.withValues(alpha: 0.1),
                  foregroundColor: _activeAccent,
                ),
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RfidManagementScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Confirmation warning dialog for factory reset
  void _showResetDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E2020),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            title: Row(
              children: const [
                Icon(Icons.report_gmailerrorred_rounded, color: Color(0xFFFF4963), size: 24),
                SizedBox(width: 8),
                Text('Reset Smart Gateway?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
            content: const Text(
              'Peringatan: Tindakan ini akan mengembalikan Otter Smart Gateway ke pengaturan pabrik. Semua konfigurasi dan aturan node yang terhubung akan dihapus.',
              style: TextStyle(color: Color(0xFFC6C6CE), height: 1.3),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Batal', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB4AB),
                  backgroundColor: const Color(0xFF93000A).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Reset Pabrik', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  SystemSettingsService().resetToDefaults();
                  await FirebaseService().resetDatabase();
                  setState(() {
                    _glassOpacity = SystemSettingsService().glassOpacity.value;
                    _activeAccent = SystemSettingsService().activeAccent.value;
                    _tempScaleCelsius = SystemSettingsService().tempScaleCelsius.value;
                    _autoLockDelay = SystemSettingsService().autoLockDelay.value;
                    _defaultBootScreen = SystemSettingsService().defaultBootScreen.value;
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mengembalikan pengaturan sistem & database ke pabrik...')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
