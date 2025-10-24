// widgets/appointment_status_card.dart
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/widgets/status.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';

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
  final double? priceText;
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
                StatusIconRound(status: widget.status),

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

                Text(
                  widget.priceText == null ? "---" : "${widget.priceText}",
                  style: AppTypography.num3,
                ),
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
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: StatusChoice(
                        value: sel, // sel is a PaymentStatus
                        onChanged: (s) {
                          widget.onChangeStatus(
                            s,
                          ); // keep your existing callback
                          setState(() => _expanded = false); // close after pick
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
