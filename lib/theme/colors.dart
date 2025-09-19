// lib/app/theme/gradients.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Convert a CSS/Figma angle (0° = up, 90° = right) to Flutter radians
double _cssDegToFlutterRad(double deg) => (deg - 90.0) * math.pi / 180.0;

/// Normalize stops so the largest = 1.0 (keeps relative spacing correct)
List<double> _normalizeStops(List<double> stops) {
  final maxStop = stops.fold<double>(0, (m, s) => s > m ? s : m);
  if (maxStop <= 0) return List.filled(stops.length, 0.0);
  return stops.map((s) => s / maxStop).toList();
}

/// Create a Flutter LinearGradient that matches a CSS/Figma linear-gradient
LinearGradient cssLinearGradient({
  required double angleDeg,
  required List<Color> colors,
  required List<double> stops, // e.g. [0.0204, 1.7119]
}) {
  return LinearGradient(
    // Always define left→right, then rotate to match the angle.
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: colors,
    stops: _normalizeStops(stops),
    transform: GradientRotation(_cssDegToFlutterRad(angleDeg)),
  );
}

/// Your tokens
class AppGradients {
  // Figma/CSS: linear-gradient(61deg, #FFB6AD 2.04%, #FDDBCD 171.19%)
  static final LinearGradient peach2 = cssLinearGradient(
    angleDeg: 61,
    colors: const [Color(0xFFFFB6AD), Color(0xFFFDDBCD)],
    stops: const [0.0204, 1.7119],
  );

  // Figma/CSS: linear-gradient(174deg, #EBA39A -10.43%, #FDEFD2 243.89%)
  static final LinearGradient peach3Reverse = cssLinearGradient(
    angleDeg: 174,
    colors: const [Color(0xFFEBA39A), Color(0xFFFDEFD2)],
    stops: const [-0.1043, 2.4389],
  );

  // Figma/CSS: linear-gradient(27deg, #EBA39A -21.54%, #FDEFD2 195.3%)
  static final LinearGradient peach3 = cssLinearGradient(
    angleDeg: 27,
    colors: const [Color(0xFFFFB6AD), Color(0xFFFDDBCD)],
    stops: const [-0.2154, 1.9530],
  );
}
