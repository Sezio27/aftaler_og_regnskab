import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  /// Base helper to set family/spacing consistently
  static TextStyle _raleway(
    double size,
    FontWeight w, {
    double? height,
    double? letter,
  }) => GoogleFonts.raleway(
    fontSize: size,
    fontWeight: w,
    height: height ?? 1.20,
    letterSpacing: letter ?? -0.2, // tighter headings
  );

  static TextStyle _inter(
    double size,
    FontWeight w, {
    double? height,
    double? letter,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: w,
    height: height ?? 1.40,
    letterSpacing: letter ?? 0.0,
  );

  /// Material 3-compatible scale (mobile-first)
  static final TextTheme textTheme = TextTheme(
    // Headings (Raleway)
    displayLarge: _raleway(34, FontWeight.w700), // big hero
    displayMedium: _raleway(30, FontWeight.w700),
    headlineLarge: _raleway(26, FontWeight.w700),
    headlineMedium: _raleway(22, FontWeight.w600),
    titleLarge: _raleway(18, FontWeight.w600),

    // Body (Inter)
    bodyLarge: _inter(16, FontWeight.w400), // default paragraph
    bodyMedium: _inter(14, FontWeight.w400),
    bodySmall: _inter(12, FontWeight.w400),

    // Labels (buttons, chips)
    labelLarge: _inter(16, FontWeight.w600, height: 1.20, letter: 0.2),
    labelMedium: _inter(14, FontWeight.w600, height: 1.20, letter: 0.2),
    labelSmall: _inter(12, FontWeight.w600, height: 1.10, letter: 0.2),
  );
}
