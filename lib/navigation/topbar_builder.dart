// lib/navigation/topbar_builder.dart
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';

Widget buildTopBarForRouteName(
  String? routeName, {
  required double maxContentWidth,
  required double fixedHeight,
}) {
  switch (routeName) {
    case 'home':
      return AppTopBarSliver(
        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );
    case 'calendar':
      return AppTopBarSliver(
        title: 'Kalender',

        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );
    case 'finance':
      return AppTopBarSliver(
        title: 'Regnskab',

        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );
    case 'services':
      return AppTopBarSliver(
        title: 'Forretning',

        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );
    case 'settings':
      return AppTopBarSliver(
        title: 'Indstillinger',

        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );

    case 'newAppointment':
      return AppTopBarSliver(
        title: 'Ny aftale',
        showBackButton: true,
        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );

    case 'allClients':
      return AppTopBarSliver(
        title: 'Klienter',
        showBackButton: true,
        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );

    case 'clientDetails':
      return AppTopBarSliver(
        title: 'Klient detaljer',
        showBackButton: true,
        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );

    case 'allAppointments':
      return AppTopBarSliver(
        title: 'Alle aftaler',
        showBackButton: true,
        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );

    default:
      return AppTopBarSliver(
        title: 'Indstillinger',
        maxContentWidth: maxContentWidth,
        fixedHeight: fixedHeight,
      );
  }
}
