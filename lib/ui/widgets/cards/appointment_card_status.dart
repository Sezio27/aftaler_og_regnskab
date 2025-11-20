// widgets/appointment_status_card.dart
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/ui/widgets/status.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/ui/widgets/cards/custom_card.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';

class AppointmentStatusCard extends StatefulWidget {
  const AppointmentStatusCard({
    super.key,
    required this.title,
    required this.service,
    required this.dateText,
    required this.price,
    required this.status,
    required this.onChangeStatus,
    this.onSeeDetails,
  });

  final String title;
  final String service;
  final String dateText;
  final double? price;
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
  late PaymentStatus _status = PaymentStatusX.fromString(widget.status);

  @override
  void didUpdateWidget(covariant AppointmentStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _status = PaymentStatusX.fromString(widget.status);
    }
  }

  void _pick(PaymentStatus s) {
    setState(() {
      _status = s;
      _expanded = false;
    });

    widget.onChangeStatus(s);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomCard(
      constraints: const BoxConstraints(minHeight: 88),
      field: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 60% with overflow becoming "..."
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      StatusIconRound(status: _status.label),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: AppTypography.acTtitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.service,
                              style: AppTypography.acSubtitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 40 % with spacebetween
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.dateText,
                          style: AppTypography.f1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatDKK(widget.price),
                        style: AppTypography.num3,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: InkWell(
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
                ),

                Flexible(
                  child: TextButton(
                    onPressed: widget.onSeeDetails,
                    child: Text(
                      'Se detaljer',
                      style: AppTypography.b3.copyWith(color: cs.onSurface),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: StatusChoice(value: _status, onChanged: _pick),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
