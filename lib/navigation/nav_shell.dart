// lib/navigation/nav_shell.dart
import 'package:aftaler_og_regnskab/app_layout.dart';
import 'package:flutter/material.dart';
import 'tab_config.dart';

class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final idx = indexForLocation(location);
    final hideNav = location.startsWith('/appointments/');
    final hideTop = location.startsWith('/appointments/');
    return AppLayout(
      idx: idx,
      showNavBar: !hideNav,
      showTopBar: !hideTop,
      child: child,
    );
  }
}
