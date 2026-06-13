import 'package:flutter/material.dart';

class SystemSettingsService {
  static final SystemSettingsService _instance = SystemSettingsService._internal();
  factory SystemSettingsService() => _instance;
  SystemSettingsService._internal();

  final ValueNotifier<double> glassOpacity = ValueNotifier<double>(0.05);
  final ValueNotifier<bool> enableVibration = ValueNotifier<bool>(true);
  final ValueNotifier<bool> enableSound = ValueNotifier<bool>(true);
  final ValueNotifier<Color> activeAccent = ValueNotifier<Color>(const Color(0xFF00F4FE)); // Neon Cyan
  final ValueNotifier<bool> tempScaleCelsius = ValueNotifier<bool>(true);
  final ValueNotifier<String> defaultBootScreen = ValueNotifier<String>('Beranda');
  final ValueNotifier<double> autoLockDelay = ValueNotifier<double>(3.0); // minutes

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
