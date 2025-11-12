import 'package:aftaler_og_regnskab/ui/widgets/layout/app_layout.dart';
import 'package:aftaler_og_regnskab/utils/performance.dart';
import 'package:flutter/material.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfTimer.stop('tab:${widget.location}');
    });
  }

  @override
  void initState() {
    super.initState();
    _stopIfLocationChanged();
  }

  @override
  void didUpdateWidget(covariant NavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stopIfLocationChanged();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName =
        widget.routeName ?? routeNameFromLocation(widget.location);
    final idx = tabIndexForRouteName(effectiveName);
    final hideBars = effectiveName == 'newAppointment';

    final appLayout = AppLayout(
      idx: idx,
      showNavBar: !hideBars,
      routeName: effectiveName,
      child: widget.child,
    );

    return appLayout;
  }
}
