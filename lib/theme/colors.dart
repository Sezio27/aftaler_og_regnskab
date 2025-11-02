import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color backgroundLight = Color(0xFFFCF9F4);
  static const Color backgroundDark = Color.fromARGB(255, 48, 47, 47);
  static const Color peach = Color(0xFFFFB6AD);
  static const Color peach2 = Color(0xFFF2BEAE);
  static const Color peachBackground = Color(0xFFFEEBE4);
  static const Color greenBackground = Color(0xFFD5F4E3);
  static const Color greenMain = Color.fromARGB(255, 2, 112, 59);
  static const Color orangeBackground = Color(0xFFFEE0C2);
  static const Color orangeMain = Color(0xFFFF9500);
  static const Color redMain = Color(0xFFC00F0C);
  static const Color redBackground = Color(0xFFFF9F9D);
  static const Color greyBackground = Color(0xFFD6D6D6);
  static const Color greyMain = Color.fromARGB(255, 98, 98, 98);
  static const Color greyText = Color(0xFF78736E);
  static const Color shadowColor = Color.fromRGBO(0, 0, 0, 0.25);
  static const Color peachSoft = Color(0xFFFDDBCD);
  static const Color peachDeep = Color(0xFFEBA39A);
  static const Color peachLight = Color(0xFFFDEFD2);

  static const Color accent1 = Color(0xFFE6AA6A);
}

double _cssDegToFlutterRad(double deg) => (deg - 90.0) * math.pi / 180.0;

List<double> _normalizeStops(List<double> stops) {
  final maxStop = stops.fold<double>(0, (m, s) => s > m ? s : m);
  if (maxStop <= 0) return List.filled(stops.length, 0.0);
  return stops.map((s) => s / maxStop).toList();
}

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

class AppGradients {
  AppGradients._();

  static final LinearGradient peach2 = _cssLinearGradient(
    angleDeg: 61,
    colors: const [AppColors.peach, AppColors.peachSoft],
    stops: const [0.0204, 1.7119],
  );

  static final LinearGradient peach3Reverse = _cssLinearGradient(
    angleDeg: 174,
    colors: const [AppColors.peachDeep, AppColors.peachLight],
    stops: const [-0.1043, 2.4389],
  );

  static final LinearGradient peach3 = _cssLinearGradient(
    angleDeg: 27,
    colors: const [AppColors.peachDeep, AppColors.peachLight],
    stops: const [-0.2154, 1.9530],
  );
}
