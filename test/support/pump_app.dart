// test/support/pump_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget pumpApp(Widget child) {
  return MaterialApp(
    locale: const Locale('da'),
    supportedLocales: const [Locale('da'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: child,
  );
}
