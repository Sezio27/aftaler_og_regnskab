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
  static final TextStyle h3 = _raleway(18, FontWeight.w600);
  static final TextStyle h4 = _raleway(16, FontWeight.w600);
  static final TextStyle b1 = _raleway(16, FontWeight.w400);
  static final TextStyle b2 = _raleway(15, FontWeight.w400);
  static final TextStyle b3 = _raleway(15, FontWeight.w600);
  static final TextStyle b4 = _raleway(14, FontWeight.w300);
  static final TextStyle b5 = _raleway(14, FontWeight.w500);
  static final TextStyle b6 = _raleway(13, FontWeight.w400);
  static final TextStyle nav1 = _raleway(13, FontWeight.w800);
  static final TextStyle nav2 = _raleway(13, FontWeight.w500);
  static final TextStyle button1 = _raleway(17, FontWeight.w700);
  static final TextStyle button2 = _raleway(15, FontWeight.w500);
  static final TextStyle button3 = _raleway(16, FontWeight.w600);
  static final TextStyle num1 = _inter(16, FontWeight.w400);
  static final TextStyle phoneInput = _inter(16, FontWeight.w400, letter: 0.3);
  static final TextStyle num2 = _inter(15, FontWeight.w500);
  static final TextStyle num3 = _inter(15, FontWeight.w400);
  static final TextStyle num4 = _inter(16, FontWeight.w700);
  static final TextStyle num5 = _inter(13, FontWeight.w600);
  static final TextStyle numBig = _inter(24, FontWeight.w600);
  static final TextStyle numStat = _inter(20, FontWeight.w500);
  static final TextStyle input1 = _inter(14, FontWeight.w500);
  static final TextStyle input2 = _inter(14, FontWeight.w300);
  static final TextStyle bold = _inter(17, FontWeight.w800);

  static final TextStyle acTtitle = _inter(16, FontWeight.w700);
  static final TextStyle acSubtitle = _inter(14, FontWeight.w400);
  static final TextStyle f1 = _inter(12, FontWeight.w400);

  static final TextStyle segActive = _raleway(14, FontWeight.w600);
  static final TextStyle segPassive = _raleway(14, FontWeight.w500);
  static final TextStyle segActiveNumber = _inter(15, FontWeight.w600);
  static final TextStyle segPassiveNumber = _inter(15, FontWeight.w400);

  static final TextStyle settingsTitle = _raleway(17, FontWeight.w700);
  static final TextStyle settingsLabel = _raleway(14, FontWeight.w600);
  static final TextStyle settingsValue = _raleway(14, FontWeight.w400);

  static TextStyle onSurface(BuildContext c, TextStyle s) =>
      s.copyWith(color: Theme.of(c).colorScheme.onSurface);
  static TextStyle primary(BuildContext c, TextStyle s) =>
      s.copyWith(color: Theme.of(c).colorScheme.primary);
  static TextStyle onPrimary(BuildContext c, TextStyle s) =>
      s.copyWith(color: Theme.of(c).colorScheme.onPrimary);
}
