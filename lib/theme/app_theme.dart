import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.purpleAccent,
      brightness: Brightness.light,
    ),
    textTheme: AppTypography.textTheme,
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    textTheme: AppTypography.textTheme,
  );
}
