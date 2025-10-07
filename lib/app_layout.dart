import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:flutter/gestures.dart';
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

    final sliverExtraction = _extractSlivers(child);
    final scrollViewConfig = sliverExtraction.config;

    final contentSlivers = sliverExtraction.slivers
        .map(
          (sliver) => SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: sliver,
          ),
        )
        .toList(growable: false);


    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: false,

      // Horizontal: 1 | 10 | 1
      body: CustomScrollView(
        scrollDirection: scrollViewConfig?.scrollDirection ?? Axis.vertical,
        reverse: scrollViewConfig?.reverse ?? false,
        controller: scrollViewConfig?.controller,
        primary: scrollViewConfig?.primary,
        physics: scrollViewConfig?.physics,
        shrinkWrap: scrollViewConfig?.shrinkWrap ?? false,
        cacheExtent: scrollViewConfig?.cacheExtent,
        anchor: scrollViewConfig?.anchor ?? 0.0,
        center: scrollViewConfig?.center,
        semanticChildCount: scrollViewConfig?.semanticChildCount,
        dragStartBehavior:
            scrollViewConfig?.dragStartBehavior ?? DragStartBehavior.start,
        keyboardDismissBehavior: scrollViewConfig?.keyboardDismissBehavior ??
            ScrollViewKeyboardDismissBehavior.manual,
        restorationId: scrollViewConfig?.restorationId,
        clipBehavior: scrollViewConfig?.clipBehavior ?? Clip.hardEdge,
        scrollBehavior: scrollViewConfig?.scrollBehavior,
        slivers: [
          topBarSliver,
          ...contentSlivers,
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

  _SliverExtractionResult _extractSlivers(Widget sliverCandidate) {
    if (sliverCandidate is CustomScrollView) {
      return _SliverExtractionResult(
        slivers: List<Widget>.from(sliverCandidate.slivers, growable: false),
        config: _ScrollViewConfig(
          scrollDirection: sliverCandidate.scrollDirection,
          reverse: sliverCandidate.reverse,
          controller: sliverCandidate.controller,
          primary: sliverCandidate.primary,
          physics: sliverCandidate.physics,
          shrinkWrap: sliverCandidate.shrinkWrap,
          cacheExtent: sliverCandidate.cacheExtent,
          anchor: sliverCandidate.anchor,
          center: sliverCandidate.center,
          semanticChildCount: sliverCandidate.semanticChildCount,
          dragStartBehavior: sliverCandidate.dragStartBehavior,
          keyboardDismissBehavior:
              sliverCandidate.keyboardDismissBehavior,
          restorationId: sliverCandidate.restorationId,
          clipBehavior: sliverCandidate.clipBehavior,
          scrollBehavior: sliverCandidate.scrollBehavior,
        ),
      );
    }

    return _SliverExtractionResult(
      slivers: <Widget>[
        SliverToBoxAdapter(child: sliverCandidate),
      ],
    );
  }
}

class _SliverExtractionResult {
  const _SliverExtractionResult({
    required this.slivers,
    this.config,
  });

  final List<Widget> slivers;
  final _ScrollViewConfig? config;
}

class _ScrollViewConfig {
  const _ScrollViewConfig({
    required this.scrollDirection,
    required this.reverse,
    required this.controller,
    required this.primary,
    required this.physics,
    required this.shrinkWrap,
    required this.cacheExtent,
    required this.anchor,
    required this.center,
    required this.semanticChildCount,
    required this.dragStartBehavior,
    required this.keyboardDismissBehavior,
    required this.restorationId,
    required this.clipBehavior,
    required this.scrollBehavior,
  });

  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double? cacheExtent;
  final double anchor;
  final Key? center;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final ScrollBehavior? scrollBehavior;
}
