import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final Widget? icon;
  final String? subtitle;
  final String? stat;
  final double height;
  final double width;

  const StatCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.stat,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.25),
            spreadRadius: 0,
            blurRadius: 2,
            offset: Offset(0, 1), // changes position of shadow
          ),
        ],
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[const SizedBox(width: 12), icon!],

          Text(title, maxLines: 1, style: AppTypography.h3),

          const SizedBox(height: 20),

          if (subtitle != null) ...[
            Text(subtitle!, maxLines: 1, style: AppTypography.b2),
          ],

          const SizedBox(height: 6),

          if (stat != null) ...[
            Text(stat!, maxLines: 1, style: AppTypography.numStat),
          ],
        ],
      ),
    );
  }
}
