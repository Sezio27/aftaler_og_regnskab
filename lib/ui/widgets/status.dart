import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StatusChoice extends StatelessWidget {
  const StatusChoice({super.key, required this.value, required this.onChanged});
  final PaymentStatus value;
  final ValueChanged<PaymentStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            StatusPill(
              label: PaymentStatus.paid.label,
              selected: PaymentStatus.paid == value,
              onTap: () => onChanged(PaymentStatus.paid),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: PaymentStatus.waiting.label,
              selected: PaymentStatus.waiting == value,
              onTap: () => onChanged(PaymentStatus.waiting),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            StatusPill(
              label: PaymentStatus.missing.label,
              selected: PaymentStatus.missing == value,
              onTap: () => onChanged(PaymentStatus.missing),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: PaymentStatus.uninvoiced.label,
              selected: PaymentStatus.uninvoiced == value,
              onTap: () => onChanged(PaymentStatus.uninvoiced),
            ),
          ],
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: selected ? statusColor(label) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? statusColor(label) : cs.onSurface.withAlpha(80),
            width: 0.6,
          ),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderRadius: BorderRadius.circular(12),
          onPressed: onTap,
          child: Text(
            label,
            style: AppTypography.button2.copyWith(
              color: selected ? Colors.white : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class StatusIconRound extends StatelessWidget {
  const StatusIconRound({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final icon = statusIcon(status);
    final fg = statusColor(status);
    final bg = statusBackground(status);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey(status),
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 24, color: fg),
      ),
    );
  }
}

class StatusIconRect extends StatelessWidget {
  const StatusIconRect({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final icon = statusIcon(status);
    final fg = statusColor(status);
    final bg = statusBackground(status);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey(status),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 7, 5),
          child: Row(
            children: [
              Text(status, style: AppTypography.b5.copyWith(color: fg)),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
