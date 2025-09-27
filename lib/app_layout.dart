// lib/app_layout.dart
import 'package:flutter/material.dart';
import 'navigation/tab_config.dart';
import 'navigation/topbar_builder.dart';
import 'widgets/app_bottom_nav_bar.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    required this.idx, // selected tab index (for topbar + nav highlight)
    required this.child, // routed page content
    this.showNavBar = true,
  });

  final int idx;
  final Widget child;
  final bool showNavBar;

  // ---- exact values you specified ----
  static const double tabletBreakpoint = 600;
  static const double maxWidthTablet = 900;
  static const double maxWidthPhone = double.infinity;
  static const double navBarHeightTablet = 120;
  static const double topBarHeightTablet = 180;

  bool _isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.shortestSide >= tabletBreakpoint;

  double _contentMaxWidth(BuildContext ctx) =>
      _isTablet(ctx) ? maxWidthTablet : maxWidthPhone;

  double _navBarHeight(BuildContext ctx) => _isTablet(ctx)
      ? navBarHeightTablet
      : (MediaQuery.of(ctx).size.height * 0.10);

  double _topBarHeight(BuildContext ctx) => _isTablet(ctx)
      ? topBarHeightTablet
      : (MediaQuery.of(ctx).size.height * 0.16);

  @override
  Widget build(BuildContext context) {
    final maxW = _contentMaxWidth(context);
    final topH = _topBarHeight(context);
    final navH = _navBarHeight(context);

    return Scaffold(
      appBar: buildTopBarForIndex(
        idx,
        maxContentWidth:
            maxW, // top bar spans full width; inner content clamped
        fixedHeight: topH, // 16% phone, 180 tablet
      ),
      extendBody: true,

      // Horizontal: 1 | 10 | 1
      body: Row(
        children: [
          const Expanded(flex: 1, child: SizedBox()),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
          const Expanded(flex: 1, child: SizedBox()),
        ],
      ),

      // Nav bar spans full width; inner content clamped; fixed sizes per your rule
      bottomNavigationBar: showNavBar
          ? AppBottomNavBar(
              currentIndex: idx,
              onItemSelected: (i) => goToTab(context, i),
              maxContentWidth: maxW,
              fixedHeight: navH, // 10% phone, 120 tablet
              iconSize: 24, // keep icon/text size constant across devices
            )
          : null,
    );
  }
}
