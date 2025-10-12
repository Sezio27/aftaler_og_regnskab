// widgets/appointment_status_card.dart
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';

class AppointmentStatusCard extends StatefulWidget {
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
  State<AppointmentStatusCard> createState() => _AppointmentStatusCardState();
}

class _AppointmentStatusCardState extends State<AppointmentStatusCard>
    with TickerProviderStateMixin {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = PaymentStatusX.fromString(widget.status);

    return CustomCard(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      field: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusIcon(status: widget.status),

                Column(
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.acTtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.service,
                      style: AppTypography.acSubtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(widget.dateText, style: AppTypography.f1),

                Text(widget.priceText, style: AppTypography.num3),
              ],
            ),
            const SizedBox(height: 4),
            // "Ændr status" + "Se detaljer"
            Row(
              children: [
                InkWell(
                  onTap: _toggle,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    child: Text(
                      'Ændr status',
                      style: AppTypography.b3.copyWith(color: cs.primary),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onSeeDetails,
                  child: Text(
                    'Se detaljer',
                    style: AppTypography.b3.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _pill(
                            label: PaymentStatus.paid.label,
                            selected: sel == PaymentStatus.paid,
                            fill: AppColors.greenMain,
                            outline: AppColors.greenMain,
                            onTap: () {
                              widget.onChangeStatus(PaymentStatus.paid);
                              setState(() => _expanded = false);
                            },
                          ),
                          _pill(
                            label: PaymentStatus.uninvoiced.label,
                            selected: sel == PaymentStatus.uninvoiced,
                            fill: cs.onPrimary,
                            text: cs.onSurface,
                            outline: cs.onSurface.withOpacity(.35),
                            onTap: () {
                              widget.onChangeStatus(PaymentStatus.uninvoiced);
                              setState(() => _expanded = false);
                            },
                          ),
                          _pill(
                            label: PaymentStatus.waiting.label,
                            selected: sel == PaymentStatus.waiting,
                            fill: AppColors.orangeMain,
                            outline: AppColors.orangeMain,
                            onTap: () {
                              widget.onChangeStatus(PaymentStatus.waiting);
                              setState(() => _expanded = false);
                            },
                          ),
                          _pill(
                            label: PaymentStatus.missing.label,
                            selected: sel == PaymentStatus.missing,
                            fill: AppColors.redMain,
                            outline: AppColors.redMain,
                            onTap: () {
                              widget.onChangeStatus(PaymentStatus.missing);
                              setState(() => _expanded = false);
                            },
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required Color fill,
    required Color outline,
    required VoidCallback onTap,
    Color? text,
  }) {
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
