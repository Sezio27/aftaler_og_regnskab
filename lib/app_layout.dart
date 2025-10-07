import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:flutter/material.dart';
import 'navigation/tab_config.dart';
import 'navigation/topbar_builder.dart';
import 'widgets/app_bottom_nav_bar.dart';

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
    final horizontalPadding = LayoutMetrics.horizontalPadding(context);

    final topBarSliver = buildTopBarForRouteName(
      routeName,
      maxContentWidth: maxW,
      fixedHeight: topH,
    );

    final contentSliver = _ensureSliver(child);


    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: false,

      // Horizontal: 1 | 10 | 1
      body: CustomScrollView(
        slivers: [
          topBarSliver,
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: contentSliver,
          ),
        ],
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

  Widget _ensureSliver(Widget sliverCandidate) {
    final isKnownSliver = sliverCandidate is Sliver ||
        sliverCandidate is SliverPersistentHeader ||
        sliverCandidate is SliverPadding ||
        sliverCandidate is SliverToBoxAdapter ||
        sliverCandidate is SliverWithKeepAliveWidget ||
        sliverCandidate is SliverMultiBoxAdaptorWidget ||
        sliverCandidate is SliverFillRemaining ||
        sliverCandidate is SliverList ||
        sliverCandidate is SliverGrid ||
        sliverCandidate is SliverFixedExtentList ||
        sliverCandidate is SliverPrototypeExtentList ||
        sliverCandidate is SliverFillViewport ||
        sliverCandidate is SliverLayoutBuilder ||
        sliverCandidate is SliverAnimatedList;

    assert(() {
      if (!isKnownSliver) {
        debugPrint(
          'AppLayout expected a sliver child but received '
          '${sliverCandidate.runtimeType}. Wrapping it in a SliverToBoxAdapter.',
        );
      }
      return true;
    }());

    if (isKnownSliver) {
      return sliverCandidate;
    }

    return SliverToBoxAdapter(child: sliverCandidate);
  }
}
