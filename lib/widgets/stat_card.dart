import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueColor,
    this.icon,
    required this.iconBgColor,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color valueColor;
  final Widget? icon;
  final Color iconBgColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomCard(
        constraints: const BoxConstraints(minHeight: 180),
        field: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              ],
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: AppTypography.h3),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.b2,
              ),
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
