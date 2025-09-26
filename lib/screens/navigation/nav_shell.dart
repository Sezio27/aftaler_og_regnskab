// lib/navigation/nav_shell.dart
import 'package:aftaler_og_regnskab/widgets/app_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'tab_config.dart';
import 'topbar_builder.dart';

class NavShell extends StatelessWidget {
  const NavShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final idx = indexForLocation(location);

    return Scaffold(
      appBar: buildTopBarForIndex(idx),
      extendBody: true,
      body: child,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: idx,
        onItemSelected: (i) => goToTab(context, i),
      ),
    );
  }
}
