import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._(); // no instances
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

  // Headings
  static final TextStyle h1 = _raleway(28, FontWeight.w700);
  static final TextStyle h2 = _raleway(24, FontWeight.w600);
  static final TextStyle h3 = _raleway(22, FontWeight.w600);
  static final TextStyle b1 = _raleway(18, FontWeight.w500);
  static final TextStyle b2 = _raleway(15, FontWeight.w400);
  static final TextStyle button1 = _raleway(17, FontWeight.w700);
  static final TextStyle num1 = _inter(16, FontWeight.w400);
  static final TextStyle phoneInput = _inter(16, FontWeight.w400, letter: 0.3);
  static final TextStyle num2 = _inter(15, FontWeight.w500);
  static final TextStyle numBig = _inter(24, FontWeight.w600);

  // Optional helpers for theming colors quickly
  static TextStyle onSurface(BuildContext c, TextStyle s) =>
      s.copyWith(color: Theme.of(c).colorScheme.onSurface);
  static TextStyle primary(BuildContext c, TextStyle s) =>
      s.copyWith(color: Theme.of(c).colorScheme.primary);
  static TextStyle onPrimary(BuildContext c, TextStyle s) =>
      s.copyWith(color: Theme.of(c).colorScheme.onPrimary);
}
