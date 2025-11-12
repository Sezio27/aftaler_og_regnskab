import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:flutter/material.dart';

class SegItem extends StatelessWidget {
  const SegItem({
    super.key,
    this.icon,
    required this.text,
    required this.active,
    this.amount,
  });
  final IconData? icon;
  final String text;
  final bool active;
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = active ? cs.onPrimary : cs.onSurface;
    return Padding(
      padding: amount == null
          ? const EdgeInsets.all(13)
          : const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg)],
              const SizedBox(width: 8),
              Text(
                text,
                style: active
                    ? AppTypography.segActive.copyWith(color: fg)
                    : AppTypography.segPassive.copyWith(color: fg),
              ),
            ],
          ),
          if (amount != null) ...[
            const SizedBox(height: 6),
            Text(
              "$amount",
              style: active
                  ? AppTypography.segActiveNumber.copyWith(color: fg)
                  : AppTypography.segPassiveNumber.copyWith(color: fg),
            ),
          ],
        ],
      ),
    );
  }
}
