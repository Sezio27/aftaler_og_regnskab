import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final Widget? icon;
  final String? subtitle;
  final String? stat;
  final BoxConstraints? constraints;

  const StatCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.stat,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      constraints: constraints,
      blurRadius: 2,
      field: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(height: 16)],

            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: AppTypography.h3,
              overflow: TextOverflow.ellipsis,
            ),

            if (subtitle != null) ...[
              const SizedBox(height: 20),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppTypography.b2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (stat != null) ...[
              const SizedBox(height: 6),
              Text(
                stat!,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppTypography.numStat,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
