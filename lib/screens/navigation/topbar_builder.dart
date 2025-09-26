// lib/navigation/topbar_builder.dart
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

PreferredSizeWidget buildTopBarForIndex(int index) {
  String subtitleDate() {
    final now = DateTime.now();
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    return '${cap(DateFormat('EEEE', 'da').format(now))} den ${now.day}. ${cap(DateFormat('MMMM', 'da').format(now))}';
  }

  switch (index) {
    case 0:
      return AppTopBar(
        title: 'Godmorgen Jakob',
        subtitle: subtitleDate(),
        action: SizedBox(
          width: 140,
          child: Image.asset('assets/logo_white.png', fit: BoxFit.fitWidth),
        ),
      );
    case 1:
      return const AppTopBar(title: 'Kalender', subtitle: 'Ugeoversigt');
    case 2:
      return const AppTopBar(title: 'Regnskab');
    case 3:
      return const AppTopBar(
        title: 'Forretning',
        subtitle: 'Administrer services',
      );
    default:
      return const AppTopBar(title: 'Indstillinger');
  }
}
