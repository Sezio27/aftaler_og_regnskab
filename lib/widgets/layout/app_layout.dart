import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:flutter/material.dart';
import '../../navigation/tab_config.dart';
import '../../navigation/topbar_builder.dart';
import 'app_bottom_nav_bar.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    this.routeName,
    required this.idx,
    required this.child,
    this.showNavBar = true,
  });

  final String? routeName;
  final int? idx;
  final Widget child;
  final bool showNavBar;

  @override
  Widget build(BuildContext context) {
    final maxW = LayoutMetrics.contentMaxWidth(context);
    final topH = LayoutMetrics.topBarHeight(context);

    return Scaffold(
      appBar: buildTopBarForRouteName(
        routeName,
        maxContentWidth: maxW,
        fixedHeight: topH,
      ),

      extendBody: true,

      // Horizontal: 1 | 10 | 1
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LayoutMetrics.horizontalPadding(context),
        ),
        child: child,
      ),

      // Nav bar spans full width; inner content clamped; fixed sizes per your rule
      bottomNavigationBar: showNavBar
          ? AppBottomNavBar(
              currentIndex: idx,
              onItemSelected: (i) => goToTab(context, i),
              maxContentWidth: maxW,
              iconSize: 24, // keep icon/text size constant across devices
            )
          : null,
    );
  }
}
