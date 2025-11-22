import 'package:aftaler_og_regnskab/ui/calendar/calendar_tab_switcher.dart';
import 'package:aftaler_og_regnskab/ui/widgets/layout/app_top_bar.dart';
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
        action: SizedBox(width: 260, child: CalendarTabSwitcher()),
      );
    case 'finance':
      return AppTopBar(
        title: 'Regnskab',

        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'catalog':
      return AppTopBar(
        title: 'Services og Checklister',

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
    case 'checklistDetails':
      return AppTopBar(
        title: 'Checkliste detaljer',
        showBackButton: true,
        width: maxContentWidth,
        height: fixedHeight,
      );
    case 'serviceDetails':
      return AppTopBar(
        title: 'Service detaljer',
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
