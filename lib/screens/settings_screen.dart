import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

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
    const Color(0xFF00E676), // Emerald Green
    const Color(0xFFFF007F), // Hot Magenta
    const Color(0xFF2979FF), // Deep Sapphire
  ];
  late Color _activeAccent;

  // ─── Interactive Settings States ───
  double _glassOpacity = 0.05;
  double _autoLockDelay = 3.0; // minutes
  bool _tempScaleCelsius = true; // C or F
  String _defaultBootScreen = 'Home';

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
    _activeAccent = _accentColors[0];
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
                color: _activeAccent.withOpacity(0.04),
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
                color: const Color(0xFFBEC5E5).withOpacity(0.03),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // ─── Main Content ───
          SafeArea(
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

                      // Card 5: Integrations
                      _buildIntegrationsCard(),
                      const SizedBox(height: 16),

                      // Card 6: System actions
                      _buildSystemCard(),
                    ],
                  ),
                ),
              ],
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
              'System Settings',
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
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
                      _activeAccent.withOpacity(0.2),
                      const Color(0xFFBEC5E5).withOpacity(0.4),
                      _activeAccent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _activeAccent.withOpacity(0.25),
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
                child: Center(
                  child: Text(
                    'AR',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _activeAccent,
                      fontFamily: 'Sora',
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
                const Text(
                  'Alex Rivers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Smart Home Administrator',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),

          // Profile edit button
          ClipOval(
            child: Container(
              color: Colors.white.withOpacity(0.04),
              child: IconButton(
                icon: Icon(Icons.edit_rounded, color: _activeAccent, size: 18),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account edit profile panel is disabled in mock demonstration.')),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bento Card: UI Customizer (Accent Color & Blur Slider)
  Widget _buildAppearanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appearance & Customization',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 16),

          // Color selector label
          Text(
            'SYSTEM ACCENT PALETTE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4), letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // Horizontal Color Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _accentColors.map((color) {
              final isSelected = _activeAccent == color;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  setState(() {
                    _activeAccent = color;
                  });
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
                          color: color.withOpacity(0.6),
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

          const SizedBox(height: 20),

          // Slider label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GLASS CONTEXT OPACITY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4), letterSpacing: 0.8),
              ),
              Text(
                '${(_glassOpacity * 100).toInt()}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _activeAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Custom horizontal slider with live visual change on this screen
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _activeAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: Colors.white,
              overlayColor: _activeAccent.withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: _glassOpacity,
              min: 0.02,
              max: 0.25,
              onChanged: (val) {
                // Occasional light haptic click based on step increments
                if ((val * 100).toInt() % 3 == 0) {
                  HapticFeedback.lightImpact();
                }
                setState(() {
                  _glassOpacity = val;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // Bento Card: Smart Preferences
  Widget _buildAutomationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Home Automation',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 16),

          // Auto Lock Delay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AUTO-LOCK IDLE DELAY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4), letterSpacing: 0.8),
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
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: Colors.white,
              overlayColor: _activeAccent.withOpacity(0.2),
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
                  const Text('Temperature scale', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Sensor reading display unit', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45))),
                ],
              ),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    _buildToggleButton('°C', _tempScaleCelsius, () {
                      HapticFeedback.lightImpact();
                      setState(() => _tempScaleCelsius = true);
                    }),
                    _buildToggleButton('°F', !_tempScaleCelsius, () {
                      HapticFeedback.lightImpact();
                      setState(() => _tempScaleCelsius = false);
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
                  const Text('Startup Screen', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Default view upon opening app', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45))),
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
                  items: <String>['Home', 'Devices', 'Monitor', 'Security']
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
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  // Bento Card: Notification Rules
  Widget _buildNotificationsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Notification Rules',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 16),

          _buildSwitchRow('Critical Security Alerts', 'Instant push notifications for alarms', _criticalAlerts, (val) {
            setState(() => _criticalAlerts = val);
          }),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow('Climate Adjustments', 'Report sensor offline states and updates', _climateReports, (val) {
            setState(() => _climateReports = val);
          }),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow('Weekly Energy Budgets', 'Receive solar logs and goals summaries', _energyLogs, (val) {
            setState(() => _energyLogs = val);
          }),
          const Divider(color: Colors.white10, height: 16),
          _buildSwitchRow('Voice assistant recording', 'Allow speech log storage in firestore', _voiceAssistantRecordings, (val) {
            setState(() => _voiceAssistantRecordings = val);
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
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45))),
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
              color: value ? _activeAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: value ? _activeAccent.withOpacity(0.6) : Colors.white.withOpacity(0.12),
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
                  color: value ? _activeAccent : Colors.white.withOpacity(0.6),
                  boxShadow: [
                    if (value)
                      BoxShadow(
                        color: _activeAccent.withOpacity(0.6),
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

  // Bento Card: Integrations
  Widget _buildIntegrationsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connected Integrations',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 16),

          _buildIntegrationTile('Google Home', Icons.home_rounded),
          const SizedBox(height: 12),
          _buildIntegrationTile('Apple HomeKit', Icons.apple_rounded),
          const SizedBox(height: 12),
          _buildIntegrationTile('Amazon Alexa', Icons.bluetooth_audio_rounded),
          const SizedBox(height: 12),
          _buildIntegrationTile('Firebase Sync', Icons.cloud_sync_rounded),
        ],
      ),
    );
  }

  // Integration Row Tile
  Widget _buildIntegrationTile(String name, IconData icon) {
    final status = _integrationStatus[name] ?? 'DISCONNECTED';
    final isSyncing = _integrationSyncing[name] ?? false;
    final isConnected = status == 'CONNECTED';

    return GestureDetector(
      onTap: () => _syncIntegration(name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.75), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            
            // Sync status badge
            if (isSyncing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_activeAccent),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFF00E676).withOpacity(0.08) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isConnected ? const Color(0xFF00E676).withOpacity(0.2) : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: isConnected ? const Color(0xFF00E676) : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Bento Card: System details & Factory reset
  Widget _buildSystemCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Core Information',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Sora'),
          ),
          const SizedBox(height: 14),

          // Technical micro details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Firmware Version', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
              const Text('v4.12.0-stable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gateway IP Address', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
              const Text('192.168.1.104', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gateway Server Ping', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
              Text('12 ms', style: TextStyle(color: _activeAccent, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),

          const SizedBox(height: 20),

          // Reset system button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF93000A).withOpacity(0.12),
              foregroundColor: const Color(0xFFFFB4AB),
              elevation: 0,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: const Color(0xFFFF4963).withOpacity(0.2)),
              ),
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showResetDialog();
            },
            child: const Text('Reset Gateway Core', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // Confirmation warning dialog for factory reset
  void _showResetDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E2020),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: Row(
              children: const [
                Icon(Icons.report_gmailerrorred_rounded, color: Color(0xFFFF4963), size: 24),
                SizedBox(width: 8),
                Text('Reset Smart Gateway?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
            content: const Text(
              'Warning: This action will restore the Otter Smart Gateway to factory defaults. All connected node configurations and rules will be wiped out.',
              style: TextStyle(color: Color(0xFFC6C6CE), height: 1.3),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB4AB),
                  backgroundColor: const Color(0xFF93000A).withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Factory Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Simulating Gateway core wipe out...')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
