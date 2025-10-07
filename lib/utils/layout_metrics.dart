import 'package:flutter/material.dart';

class LayoutMetrics {
  static const double tabletBreakpoint = 600;
  static const double maxWidthTablet = 900;
  static const double maxWidthPhone = double.infinity;
  static const double navBarHeightTablet = 120;
  static const double topBarHeightTablet = 180;

  static const double minHPadPhone = 14; // or 20
  static const double minHPadTablet = 32; // or 40

  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.shortestSide >= tabletBreakpoint;

  static double contentMaxWidth(BuildContext ctx) =>
      isTablet(ctx) ? maxWidthTablet : maxWidthPhone;

  static double navBarHeight(BuildContext ctx) => isTablet(ctx)
      ? navBarHeightTablet
      : (MediaQuery.of(ctx).size.height * 0.1);

  static double topBarHeight(BuildContext ctx) => isTablet(ctx)
      ? topBarHeightTablet
      : (MediaQuery.of(ctx).size.height * 0.14);

  static double horizontalPadding(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final screenW = mq.size.width;
    final leftInset = mq.viewPadding.left;
    final rightInset = mq.viewPadding.right;

    final maxW = contentMaxWidth(ctx);
    final minPad = isTablet(ctx) ? minHPadTablet : minHPadPhone;

    if (maxW != double.infinity) {
      final side = ((screenW - maxW) / 2).clamp(minPad, double.infinity);
      return side + ((leftInset + rightInset) / 2);
    }

    return minPad + ((leftInset + rightInset) / 2);
  }
}
