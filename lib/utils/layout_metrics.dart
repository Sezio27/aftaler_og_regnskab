import 'package:flutter/material.dart';

class LayoutMetrics {
  static const double tabletBreakpoint = 600;
  static const double maxWidthTablet = 900;
  static const double maxWidthPhone = double.infinity;
  static const double navBarHeightTablet = 120;
  static const double topBarHeightTablet = 180;

  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.shortestSide >= tabletBreakpoint;

  static double contentMaxWidth(BuildContext ctx) =>
      isTablet(ctx) ? maxWidthTablet : maxWidthPhone;

  static double navBarHeight(BuildContext ctx) => isTablet(ctx)
      ? navBarHeightTablet
      : (MediaQuery.of(ctx).size.height * 0.10);

  static double topBarHeight(BuildContext ctx) => isTablet(ctx)
      ? topBarHeightTablet
      : (MediaQuery.of(ctx).size.height * 0.16);
}
