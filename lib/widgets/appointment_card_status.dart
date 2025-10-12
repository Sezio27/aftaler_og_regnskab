// widgets/appointment_status_card.dart
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';

class AppointmentStatusCard extends StatelessWidget {
  const AppointmentStatusCard({
    super.key,
    required this.title,
    required this.service,
    required this.dateText,
    required this.priceText,
    required this.status,
    required this.onChangeStatus,
    this.onSeeDetails,
  });

  final String title;
  final String service;
  final String dateText;
  final String priceText;
  final String status;
  final ValueChanged<PaymentStatus> onChangeStatus;
  final VoidCallback? onSeeDetails;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomCard(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      field: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(status: status),

                Column(
                  children: [
                    Text(
                      title,
                      style: AppTypography.acTtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      service,
                      style: AppTypography.acSubtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(dateText, style: AppTypography.f1),

                Text(priceText, style: AppTypography.num3),
              ],
            ),
            const SizedBox(height: 4),
            // "Ændr status" + "Se detaljer"
            Row(
              children: [
                Text(
                  'Ændr status',
                  style: AppTypography.b3.copyWith(color: cs.primary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSeeDetails,
                  child: Text(
                    'Se detaljer',
                    style: AppTypography.b3.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Pills row
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _StatusPill(
                  label: PaymentStatus.paid.label,
                  selected: status == PaymentStatus.paid,
                  fill: AppColors.greenMain,
                  outline: AppColors.greenMain,
                  onTap: () => onChangeStatus(PaymentStatus.paid),
                ),
                _StatusPill(
                  label: PaymentStatus.uninvoiced.label,
                  selected: status == PaymentStatus.uninvoiced,
                  fill: cs.onPrimary, // white
                  text: cs.onSurface,
                  outline: cs.onSurface.withOpacity(.35),
                  onTap: () => onChangeStatus(PaymentStatus.uninvoiced),
                ),
                _StatusPill(
                  label: PaymentStatus.waiting.label,
                  selected: status == PaymentStatus.waiting,
                  fill: AppColors.orangeMain,
                  outline: AppColors.orangeMain,
                  onTap: () => onChangeStatus(PaymentStatus.waiting),
                ),
                _StatusPill(
                  label: PaymentStatus.missing.label,
                  selected: status == PaymentStatus.missing,
                  fill: AppColors.redMain,
                  outline: AppColors.redMain,
                  onTap: () => onChangeStatus(PaymentStatus.missing),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.selected,
    required this.fill,
    required this.outline,
    required this.onTap,
    this.text,
  });

  final String label;
  final bool selected;
  final Color fill;
  final Color outline;
  final Color? text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? fill : Colors.transparent;
    final fg = selected ? Colors.white : (text ?? cs.onSurface);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: outline, width: 1.4),
        backgroundColor: bg,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(label, style: AppTypography.b3.copyWith(color: fg)),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
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
        key: ValueKey(status), // animate on change
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}
