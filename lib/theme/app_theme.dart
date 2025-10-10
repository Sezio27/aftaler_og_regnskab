import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.peach, // your peach
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.peach,
        onPrimary: Colors.white,
        surface: AppColors.backgroundLight,
        onSurface: Colors.black,
        secondary: AppColors.peach2,
        onSecondary: Colors.white,
        error: const Color(0xFFB00020),
        onError: Colors.white,
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF9C86),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFF9C86),
        onPrimary: Colors.black,
        surface: AppColors.backgroundDark,
        onSurface: Colors.white,
        secondary: const Color(0xFFB8B8B8),
        onSecondary: Colors.black,
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
      );
  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    datePickerTheme: DatePickerThemeData(
      dividerColor: _lightScheme.primary,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _lightScheme.primary;

        return Colors.transparent;
      }),
      todayBorder: BorderSide(color: _lightScheme.primary, width: 1),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _lightScheme.onSurface, width: 1.5),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _lightScheme.onSurface, width: 1.5),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _lightScheme.onSurface.withOpacity(.4)),
      ),
      labelStyle: TextStyle(color: _lightScheme.onSurface),
      floatingLabelStyle: TextStyle(color: _lightScheme.onSurface),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? _lightScheme.surfaceContainerHighest
              : _lightScheme.primary,
        ),
        foregroundColor: WidgetStatePropertyAll(_lightScheme.onPrimary),
      ),
    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: _darkScheme,
    scaffoldBackgroundColor: Colors.black,
    inputDecorationTheme: InputDecorationTheme(
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _darkScheme.onSurface, width: 1.5),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _darkScheme.onSurface, width: 1.5),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _darkScheme.onSurface.withOpacity(.4)),
      ),
      labelStyle: TextStyle(color: _darkScheme.onSurface),
      floatingLabelStyle: TextStyle(color: _darkScheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? _darkScheme.surfaceContainerHighest
              : _darkScheme.primary,
        ),
        foregroundColor: WidgetStatePropertyAll(_darkScheme.onPrimary),
      ),
    ),
  );
}
