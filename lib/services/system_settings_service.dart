import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemSettingsService {
  static final SystemSettingsService _instance = SystemSettingsService._internal();
  factory SystemSettingsService() => _instance;
  SystemSettingsService._internal();

  late SharedPreferences _prefs;

  final ValueNotifier<double> glassOpacity = ValueNotifier<double>(0.05);
  final ValueNotifier<bool> enableVibration = ValueNotifier<bool>(true);
  final ValueNotifier<bool> enableSound = ValueNotifier<bool>(true);
  final ValueNotifier<Color> activeAccent = ValueNotifier<Color>(const Color(0xFF00F4FE)); // Neon Cyan
  final ValueNotifier<bool> tempScaleCelsius = ValueNotifier<bool>(true);
  final ValueNotifier<String> defaultBootScreen = ValueNotifier<String>('Beranda');
  final ValueNotifier<double> autoLockDelay = ValueNotifier<double>(3.0); // minutes
  final ValueNotifier<bool> lockScreenTrigger = ValueNotifier<bool>(false);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load saved settings
    glassOpacity.value = _prefs.getDouble('glassOpacity') ?? 0.05;
    enableVibration.value = _prefs.getBool('enableVibration') ?? true;
    enableSound.value = _prefs.getBool('enableSound') ?? true;
    final accentValue = _prefs.getInt('activeAccent');
    if (accentValue != null) {
      activeAccent.value = Color(accentValue);
    } else {
      activeAccent.value = const Color(0xFF00F4FE);
    }
    tempScaleCelsius.value = _prefs.getBool('tempScaleCelsius') ?? true;
    defaultBootScreen.value = _prefs.getString('defaultBootScreen') ?? 'Beranda';
    autoLockDelay.value = _prefs.getDouble('autoLockDelay') ?? 3.0;

    // Attach auto-save listeners
    glassOpacity.addListener(() => _prefs.setDouble('glassOpacity', glassOpacity.value));
    enableVibration.addListener(() => _prefs.setBool('enableVibration', enableVibration.value));
    enableSound.addListener(() => _prefs.setBool('enableSound', enableSound.value));
    activeAccent.addListener(() => _prefs.setInt('activeAccent', activeAccent.value.value));
    tempScaleCelsius.addListener(() => _prefs.setBool('tempScaleCelsius', tempScaleCelsius.value));
    defaultBootScreen.addListener(() => _prefs.setString('defaultBootScreen', defaultBootScreen.value));
    autoLockDelay.addListener(() => _prefs.setDouble('autoLockDelay', autoLockDelay.value));
  }

  void resetToDefaults() {
    glassOpacity.value = 0.05;
    enableVibration.value = true;
    enableSound.value = true;
    activeAccent.value = const Color(0xFF00F4FE);
    tempScaleCelsius.value = true;
    defaultBootScreen.value = 'Beranda';
    autoLockDelay.value = 3.0;
  }
}
