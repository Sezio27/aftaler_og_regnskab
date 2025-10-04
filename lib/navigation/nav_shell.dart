// lib/navigation/nav_shell.dart
import 'package:aftaler_og_regnskab/app_layout.dart';
import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:flutter/material.dart';
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

    return AppLayout(
      idx: idx, // bottom tab index
      showNavBar: !hideBars,
      showTopBar: !hideBars,
      routeName:
          effectiveName, // <-- pass to AppLayout so it can build the top bar
      child: child,
    );
  }
}
