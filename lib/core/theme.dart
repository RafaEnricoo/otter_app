import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Color(AppColors.surface),
    colorScheme: ColorScheme.dark(
      primary: Color(AppColors.primary),
      secondary: Color(AppColors.secondary),
      tertiary: Color(AppColors.tertiary),
      error: Color(AppColors.error),
      surface: Color(AppColors.surface),
      surfaceVariant: Color(AppColors.surfaceVariant),
      onSurface: Color(AppColors.onSurface),
      onSurfaceVariant: Color(AppColors.onSurfaceVariant),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(AppColors.surface),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(AppColors.onSurface),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02,
        color: Color(AppColors.onSurface),
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: Color(AppColors.onSurface),
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.33,
        color: Color(AppColors.onSurface),
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.56,
        color: Color(AppColors.onSurface),
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: Color(AppColors.onSurface),
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.01,
        height: 1.43,
        color: Color(AppColors.onSurface),
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
        height: 1.33,
        color: Color(AppColors.onSurface),
      ),
    ),
    iconTheme: const IconThemeData(color: Color(AppColors.onSurface)),
  );
}
