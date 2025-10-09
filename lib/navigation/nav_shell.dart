// lib/navigation/nav_shell.dart
import 'package:aftaler_og_regnskab/app_layout.dart';
import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tab_config.dart';

class NavShell extends StatelessWidget {
  const NavShell({
    super.key,
    required this.child,
    required this.location,
    required this.routeName,
  });
  final Widget child;
  final String location;
  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final effectiveName = routeName ?? routeNameFromLocation(location);
    final idx = tabIndexForRouteName(effectiveName);
    final hideBars = effectiveName == 'newAppointment';
    final isCalendar = effectiveName == 'calendar';
    final appLayout = AppLayout(
      idx: idx,
      showNavBar: !hideBars,
      routeName: effectiveName,
      child: child,
    );
    if (isCalendar) {
      return ChangeNotifierProvider(
        create: (_) => CalendarViewModel(),
        child: appLayout,
      );
    }
    return appLayout;
  }
}
