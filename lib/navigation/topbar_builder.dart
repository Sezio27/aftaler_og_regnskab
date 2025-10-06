// lib/navigation/topbar_builder.dart
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _subtitleDate() {
  final now = DateTime.now();
  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  return '${cap(DateFormat('EEEE', 'da').format(now))} den ${now.day}. ${cap(DateFormat('MMMM', 'da').format(now))}';
}

PreferredSizeWidget buildTopBarForRouteName(
  String? routeName, {
  required double maxContentWidth,
  required double fixedHeight,
}) {
  switch (routeName) {
    case 'home':
      return AppTopBar(
        title: 'Godmorgen Jakob',
        subtitle: _subtitleDate(),
        action: SizedBox(
          width: 140,
          child: Image.asset('assets/logo_white.png', fit: BoxFit.fitWidth),
        ),
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'calendar':
      return AppTopBar(
        title: 'Kalender',
        subtitle: 'Ugeoversigt',
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'finance':
      return AppTopBar(
        title: 'Regnskab',
        subtitle: 'Oversigt over indtægter og aftaler',
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'services':
      return AppTopBar(
        title: 'Forretning',
        subtitle: 'Administrer dine services og checklister',
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'settings':
      return AppTopBar(
        title: 'Indstillinger',
        subtitle: 'Administrer dine indstillinger',
        width: maxContentWidth,
        height: fixedHeight,
      );

    case 'newAppointment':
      return AppTopBar(
        title: 'Ny aftale',
        showBackButton: true,
        width: maxContentWidth,
        height: fixedHeight,
      );

    case 'allClients':
      return AppTopBar(
        title: 'Klienter',
        showBackButton: true,
        width: maxContentWidth,
        height: fixedHeight,
      );

    case 'clientDetails':
      return AppTopBar(
        title: 'Klient detaljer',
        showBackButton: true,
        width: maxContentWidth,
        height: fixedHeight,
      );

    case 'allAppointments':
      return AppTopBar(
        title: 'Alle aftaler',
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
