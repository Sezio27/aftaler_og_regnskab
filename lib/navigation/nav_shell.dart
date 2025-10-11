// lib/navigation/nav_shell.dart
import 'package:aftaler_og_regnskab/app_layout.dart';
import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/utils/performance.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tab_config.dart';

class NavShell extends StatefulWidget {
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
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  String? _lastLocation;

  void _stopIfLocationChanged() {
    if (_lastLocation == widget.location) return;
    _lastLocation = widget.location;

    // Stop on the first frame of the new tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfTimer.stop('tab:${widget.location}');
    });
  }

  @override
  void initState() {
    super.initState();
    _stopIfLocationChanged(); // handles the initial mount too
  }

  @override
  void didUpdateWidget(covariant NavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stopIfLocationChanged(); // runs when location changes
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName =
        widget.routeName ?? routeNameFromLocation(widget.location);
    final idx = tabIndexForRouteName(effectiveName);
    final hideBars = effectiveName == 'newAppointment';
    final isCalendar = effectiveName == 'calendar';
    final appLayout = AppLayout(
      idx: idx,
      showNavBar: !hideBars,
      routeName: effectiveName,
      child: widget.child,
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
