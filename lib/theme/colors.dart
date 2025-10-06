import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Brand color tokens used throughout the app.
///
/// Keeping them here makes it easy to audit or update the palette without
/// hunting through UI widgets.
class AppColors {
  AppColors._();

  // Core brand colors
  static const Color backgroundLight = Color(0xFFFCF9F4);
  static const Color peach = Color(0xFFFFB6AD);
  static const Color peach2 = Color(0xFFF2BEAE);
  static const Color peachBackground = Color(0xFFFEEBE4);
  static const Color greenBackground = Color(0xFFD5F4E3);
  static const Color greenMain = Color(0xFF02542D);
  static const Color orangeBackground = Color(0xFFFEE0C2);
  static const Color orangeMain = Color(0xFFFF9500);
  static const Color redMain = Color(0xFFC00F0C);
  static const Color redBackground = Color(0xFFFF9F9D);
  static const Color greyBackground = Color(0xFFD6D6D6);
  static const Color greyMain = Color(0xFF5A5A5A);
  static const Color greyText = Color(0xFF78736E);
  static const Color shadowColor = Color.fromRGBO(0, 0, 0, 0.25);
  // Supporting tints still used in gradients.
  static const Color peachSoft = Color(0xFFFDDBCD);
  static const Color peachDeep = Color(0xFFEBA39A);
  static const Color peachLight = Color(0xFFFDEFD2);

  static const Color accent1 = Color(0xFFE6AA6A);
}

/// Convert a CSS/Figma angle (0 deg = up, 90 deg = right) to Flutter radians.
double _cssDegToFlutterRad(double deg) => (deg - 90.0) * math.pi / 180.0;

/// Normalize stops so the largest = 1.0 (keeps relative spacing correct).
List<double> _normalizeStops(List<double> stops) {
  final maxStop = stops.fold<double>(0, (m, s) => s > m ? s : m);
  if (maxStop <= 0) return List.filled(stops.length, 0.0);
  return stops.map((s) => s / maxStop).toList();
}

/// Create a Flutter LinearGradient that matches a CSS/Figma linear-gradient.
LinearGradient _cssLinearGradient({
  required double angleDeg,
  required List<Color> colors,
  required List<double> stops,
}) {
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: colors,
    stops: _normalizeStops(stops),
    transform: GradientRotation(_cssDegToFlutterRad(angleDeg)),
  );
}

/// Gradient tokens extracted from the design system.
class AppGradients {
  AppGradients._();

  // Figma/CSS: linear-gradient(61deg, #FFB6AD 2.04%, #FDDBCD 171.19%)
  static final LinearGradient peach2 = _cssLinearGradient(
    angleDeg: 61,
    colors: const [AppColors.peach, AppColors.peachSoft],
    stops: const [0.0204, 1.7119],
  );

  // Figma/CSS: linear-gradient(174deg, #EBA39A -10.43%, #FDEFD2 243.89%)
  static final LinearGradient peach3Reverse = _cssLinearGradient(
    angleDeg: 174,
    colors: const [AppColors.peachDeep, AppColors.peachLight],
    stops: const [-0.1043, 2.4389],
  );

  // Figma/CSS: linear-gradient(27deg, #EBA39A -21.54%, #FDEFD2 195.3%)
  static final LinearGradient peach3 = _cssLinearGradient(
    angleDeg: 27,
    colors: const [AppColors.peachDeep, AppColors.peachLight],
    stops: const [-0.2154, 1.9530],
  );
}
