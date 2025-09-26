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

int indexForLocation(String loc) {
  if (loc.startsWith('/calendar')) return 1;
  if (loc.startsWith('/finance')) return 2;
  if (loc.startsWith('/services')) return 3;
  if (loc.startsWith('/settings')) return 4;
  return 0;
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
