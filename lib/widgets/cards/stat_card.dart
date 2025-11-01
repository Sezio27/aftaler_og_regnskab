import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/cards/custom_card.dart';
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.valueColor,
    this.icon,
    required this.iconBgColor,
    this.minHeight = 140,
  });

  final String title;
  final String? subtitle;
  final String value;
  final Color valueColor;
  final Widget? icon;
  final Color iconBgColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomCard(
        constraints: BoxConstraints(minHeight: minHeight),
        field: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: icon,
                ),
                const SizedBox(height: 18),
              ],

              Text(title, textAlign: TextAlign.center, style: AppTypography.h3),
              const SizedBox(height: 10),

              if (subtitle != null) ...[
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTypography.b2,
                ),
                const SizedBox(height: 6),
              ],
              Text(
                value,
                textAlign: TextAlign.center,
                style: AppTypography.numStat.copyWith(color: valueColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
