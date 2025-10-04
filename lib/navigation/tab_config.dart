import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum TabItem { home, calendar, finance, services, settings }

const _paths = {
  TabItem.home: '/home',
  TabItem.calendar: '/calendar',
  TabItem.finance: '/finance',
  TabItem.services: '/services',
  TabItem.settings: '/settings',
};

int? tabIndexForRouteName(String? name) {
  switch (name) {
    case 'home':
      return 0;
    case 'calendar':
      return 1;
    case 'finance':
      return 2;
    case 'services':
      return 3;
    case 'settings':
      return 4;
    default:
      return null;
  }
}

// Derive a leaf route name from the URL if state.name is null
String? routeNameFromLocation(String loc) {
  if (loc.startsWith('/appointments/new')) return 'newAppointment';
  if (loc.startsWith('/appointments/all')) return 'allAppointments';

  if (loc.startsWith('/clients')) {
    if (loc == "/clients/all") return "allClients";
    return 'clientDetails';
  }

  if (loc.startsWith('/calendar')) return 'calendar';
  if (loc.startsWith('/finance')) return 'finance';
  if (loc.startsWith('/services')) return 'services';
  if (loc.startsWith('/settings')) return 'settings';
  if (loc.startsWith('/home')) return 'home';
  return null;
}

void goToTab(BuildContext context, int i) {
  switch (i) {
    case 0:
      context.go(_paths[TabItem.home]!);
      break;
    case 1:
      context.go(_paths[TabItem.calendar]!);
      break;
    case 2:
      context.go(_paths[TabItem.finance]!);
      break;
    case 3:
      context.go(_paths[TabItem.services]!);
      break;
    case 4:
      context.go(_paths[TabItem.settings]!);
      break;
  }
}
