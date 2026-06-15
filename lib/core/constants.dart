import 'package:flutter/material.dart';
import '../services/system_settings_service.dart';

class AppColors {
  // Main Colors
  static const primary = 0xFFBEC5E5;
  static const secondary = 0xFFE6FEFF;
  static int get secondaryContainer => SystemSettingsService().activeAccent.value.value;
  static const tertiary = 0xFFC6C7C3;
  static const error = 0xFFFFB4AB;

  // Surface Colors
  static const surface = 0xFF121414;
  static const surfaceVariant = 0xFF333535;
  static const surfaceContainer = 0xFF1E2020;
  static const surfaceContainerLow = 0xFF1A1C1C;
  static const surfaceContainerHigh = 0xFF282A2B;
  static const surfaceContainerHighest = 0xFF333535;
  static const surfaceBright = 0xFF37393A;
  static const surfaceDim = 0xFF121414;

  // Text Colors
  static const onSurface = 0xFFE2E2E2;
  static const onSurfaceVariant = 0xFFC6C6CE;
  static const onBackground = 0xFFE2E2E2;

  // Container Colors
  static const primaryContainer = 0xFF0B132B;
  static const primaryFixed = 0xFFDBE1FF;
  static const errorContainer = 0xFF93000A;
}

class AppSpacing {
  static const containerPadding = 24.0;
  static const stackLg = 40.0;
  static const stackMd = 24.0;
  static const stackSm = 12.0;
  static const gutter = 16.0;
  static const base = 8.0;
}

class AppRadius {
  static const sm = 2.0;
  static const md = 4.0;
  static const lg = 8.0;
  static const xl = 12.0;
  static const full = 9999.0;
}

Color getTempColor(double celsius) {
  if (celsius <= 20.0) {
    return const Color(0xFF4FC3F7); // Cold - Light Blue
  } else if (celsius <= 26.0) {
    return const Color(0xFF81C784); // Optimal - Green
  } else if (celsius <= 30.0) {
    return const Color(0xFFFFB74D); // Warm - Orange
  } else {
    return const Color(0xFFFF4963); // Hot - Red
  }
}

