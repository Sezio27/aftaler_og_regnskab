import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final Widget? icon;
  final String? subtitle;
  final String? stat;

  const StatCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.stat,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final s = (constraints.maxWidth / 320).clamp(1.0, 1.35);

        final vPad = 10.0 * s;
        final hPad = 16.0 * s;
        final gapIcon = 16.0 * s;
        final gapSubtitleTop = 20.0 * s;
        final gapStatTop = 6.0 * s;

        return CustomCard(
          blurRadius: 2,
          field: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, SizedBox(height: gapIcon)],

                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Optional: bump font a touch with s if you want
                  style: AppTypography.h3,
                ),

                if (subtitle != null) ...[
                  SizedBox(height: gapSubtitleTop),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.b2,
                  ),
                ],

                if (stat != null) ...[
                  SizedBox(height: gapStatTop),
                  Text(
                    stat!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.numStat,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
