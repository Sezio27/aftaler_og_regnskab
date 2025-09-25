import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';

/// Central place for building the Material [ThemeData] used in the app.
///
/// The idea is to keep visual configuration in one spot so the rest of the
/// widgets can focus on layout. Colors come from [AppColors] and the widget
/// typography helpers live in `typography.dart`.
class AppTheme {
  AppTheme._();

  /// Light color palette used by default.
  static final ThemeData light = _buildTheme(Brightness.light);

  /// Dark color palette for users who prefer it via system setting.
  static final ThemeData dark = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    final ColorScheme baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.greenMain,
      brightness: brightness,
    );

    final ColorScheme colorScheme = baseScheme.copyWith(
      primary: AppColors.greenMain,
      onPrimary: Colors.white,
      secondary: AppColors.orangeMain,
      onSecondary: Colors.white,
      tertiary: AppColors.peach,
      onTertiary: Colors.white,
      error: AppColors.redMain,
      onError: Colors.white,
      background: isLight ? Colors.white : const Color(0xFF121212),
      surface: isLight ? Colors.white : const Color(0xFF1F1F1F),
      surfaceVariant: isLight
          ? AppColors.greyBackground
          : const Color(0xFF2A2A2A),
      outline: AppColors.greyMain,
      surfaceTint: AppColors.peach,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: isLight ? Colors.white : const Color(0xFF0D0D0D),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: isLight ? 1 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
        filled: true,
        fillColor: isLight ? Colors.white : colorScheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.greyBackground),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.greyBackground),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.surfaceVariant;
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onPrimary),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.onPrimary.withOpacity(0.12);
            }
            return null;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withOpacity(0.3),
        thickness: 1,
      ),
    );
  }
}
