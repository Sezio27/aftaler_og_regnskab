import 'package:flutter/material.dart';
import 'typography.dart'; // your AppTypography

class AppTheme {
  AppTheme._();

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ).copyWith(
        onPrimary: Colors.white, // ensure white text on FilledButton, etc.
      );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.dark,
  ).copyWith(onPrimary: Colors.white);

  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: Colors.white,
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
