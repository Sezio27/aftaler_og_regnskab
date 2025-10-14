// lib/navigation/topbar_builder.dart
import 'package:aftaler_og_regnskab/screens/calendar/calendar_tab_switcher.dart';
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';

PreferredSizeWidget buildTopBarForRouteName(
  String? routeName, {
  required double maxContentWidth,
  required double fixedHeight,
}) {
  switch (routeName) {
    case 'home':
      return AppTopBar(width: maxContentWidth, height: fixedHeight);
    case 'calendar':
      return AppTopBar(
        title: 'Kalender',
        center: false,
        width: maxContentWidth,
        height: fixedHeight,
        action: SizedBox(width: 220, child: CalendarTabSwitcher()),
      );
    case 'finance':
      return AppTopBar(
        title: 'Regnskab',

        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'services':
      return AppTopBar(
        title: 'Forretning',

        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'settings':
      return AppTopBar(
        title: 'Indstillinger',

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

    case 'appointmentDetails':
      return AppTopBar(
        title: 'Aftaler detaljer',
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
