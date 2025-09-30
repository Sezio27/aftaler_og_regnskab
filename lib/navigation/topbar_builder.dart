// lib/navigation/topbar_builder.dart
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

PreferredSizeWidget buildTopBarForIndex(
  int index, {
  required double maxContentWidth,
  required double fixedHeight,
}) {
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
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 1:
      return AppTopBar(
        title: 'Kalender',
        subtitle: 'Ugeoversigt',
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 2:
      return AppTopBar(
        title: 'Regnskab',
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 3:
      return AppTopBar(
        title: 'Forretning',
        subtitle: 'Administrer dine services og checklister',
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 4:
      return AppTopBar(
        title: 'Indstillinger',
        subtitle: "Administrer dine indstillinger",
        width: maxContentWidth,
        height: fixedHeight,
      );

    case 5:
      return AppTopBar(
        title: 'Ny aftale',
        showBackButton: true,
        width: maxContentWidth,
        height: fixedHeight,
      );

    default:
      return AppTopBar(
        title: 'Indstillinger',
        width: maxContentWidth,
        height: fixedHeight,
      );
  }
}
