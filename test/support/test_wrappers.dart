// test/support/test_wrappers.dart
import 'package:aftaler_og_regnskab/navigation/nav_shell.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setTestViewSize(
  WidgetTester tester, {
  double width = 1300,
  double height = 2856,
  double devicePixelRatio = 1.0,
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = Size(
    width * devicePixelRatio,
    height * devicePixelRatio,
  );

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // Make sure the new metrics are applied before building.
  await tester.pump();
}

/// Pump your widget with providers + NavShell and a fixed viewport.
Future<void> pumpWithShell(
  WidgetTester tester, {
  required Widget child,
  required List<SingleChildWidget> providers,
  String location = '/',
  String? routeName,
  double width = 1280,
  double height = 2856,
  double devicePixelRatio = 1.0,
}) async {
  await setTestViewSize(
    tester,
    width: width,
    height: height,
    devicePixelRatio: devicePixelRatio,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('da'), Locale('en')],
        home: NavShell(location: location, routeName: routeName, child: child),
      ),
    ),
  );

  // Allow first frame/layout to settle if needed by callers.
  await tester.pump();
}
