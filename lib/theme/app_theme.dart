import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';
import 'typography.dart'; // your AppTypography

class AppTheme {
  AppTheme._();

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF9C86), // your peach
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFFFF9C86),
        onPrimary: Colors.white,
        surface: const Color(0xFFF8F4F1),
        onSurface: const Color(0xFF1E1E1E),
        secondary: const Color(0xFF6E6E6E),
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
        onPrimary: Colors.black, // often better in dark for contrast
        surface: const Color(0xFF131313),
        onSurface: const Color(0xFFEDEDED),
        secondary: const Color(0xFFB8B8B8),
        onSecondary: Colors.black,
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
      );
  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: AppColors.backgroundLight,
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
