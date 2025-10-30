// lib/screens/finance_screen.dart
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/stat_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card_status.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';

enum Tabs { month, year, lifetime }

typedef DateRange = ({DateTime? start, DateTime? end});

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Tabs _tab = Tabs.month;

  Segment _segForTab(Tabs t) => switch (t) {
    Tabs.month => Segment.month,
    Tabs.year => Segment.year,
    Tabs.lifetime => Segment.total,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FinanceViewModel>().ensureFinanceTotalsSeeded();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = LayoutMetrics.horizontalPadding(context);
    final seg = _segForTab(_tab);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: hPad / 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoSlidingSegmentedControl<Tabs>(
              groupValue: _tab,
              backgroundColor: cs.onPrimary,
              thumbColor: cs.secondary,
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _tab = v);
              },
              children: {
                Tabs.month: SegItem(text: 'Måned', active: _tab == Tabs.month),
                Tabs.year: SegItem(text: 'År', active: _tab == Tabs.year),
                Tabs.lifetime: SegItem(
                  text: 'Total',
                  active: _tab == Tabs.lifetime,
                ),
              },
            ),

            const SizedBox(height: 16),

            // Summary cards (income + count) — only these rebuild when VM data changes.
            Selector<FinanceViewModel, ({int count, double income})>(
              selector: (_, vm) => vm.summaryNow(seg),
              builder: (_, summary, __) {
                return Row(
                  key: ValueKey(
                    'sum-${summary.count}-${summary.income.round()}',
                  ),
                  children: [
                    StatCard(
                      title: "Omsætning",

                      value: formatDKK(summary.income),
                      icon: const Icon(
                        Icons.account_balance_outlined,
                        size: 18,
                        color: AppColors.greenMain,
                      ),
                      valueColor: AppColors.greenMain,
                      iconBgColor: AppColors.greenBackground,
                    ),

                    const SizedBox(width: 16),

                    StatCard(
                      title: "Aftaler",

                      value: summary.count.toString(),
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: AppColors.peach,
                      ),
                      valueColor: cs.onSurface,
                      iconBgColor: AppColors.peachBackground,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            Selector<
              FinanceViewModel,
              ({int paid, int waiting, int missing, int uninvoiced})
            >(
              selector: (_, vm) => vm.statusNow(seg),
              builder: (_, status, __) {
                return StatusCountCard(status: status);
              },
            ),

            const SizedBox(height: 16),

            // Recent list (cached Future + per-row Stream so only changed row rebuilds)
            CustomCard(
              color: cs.surface,
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 10,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined),
                          const SizedBox(width: 12),
                          Text(
                            'Seneste aftaler',
                            style: AppTypography.b2.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.pushNamed(
                              AppRoute.allAppointments.name,
                            ),
                            child: Text(
                              'Se alle',
                              style: AppTypography.b3.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Selector<AppointmentViewModel, List<AppointmentCardModel>>(
                      selector: (_, vm) {
                        final now = DateTime.now();
                        final r = monthRange(now);
                        return vm.cardsForRange(r.start, r.end);
                      },
                      shouldRebuild: (a, b) {
                        // Optional: micro-optimization; compare lengths or ids
                        if (a.length != b.length) return true;
                        for (var i = 0; i < a.length; i++) {
                          if (a[i].id != b[i].id ||
                              a[i].status != b[i].status ||
                              a[i].price != b[i].price) {
                            return true;
                          }
                        }
                        return false;
                      },
                      builder: (context, items, _) {
                        final cs = Theme.of(context).colorScheme;

                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Ingen kommende aftaler",
                                style: AppTypography.b3.copyWith(
                                  color: cs.onSurface.withAlpha(150),
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final a = items[i];
                            final dateText = DateFormat(
                              'd/M',
                              'da',
                            ).format(a.time);

                            return AppointmentStatusCard(
                              key: ValueKey('appt-${a.id}'),
                              title: a.clientName,
                              service: a.serviceName,
                              dateText: dateText,
                              price: a.price,
                              status: a.status,
                              onSeeDetails: () {
                                context.pushNamed(
                                  AppRoute.appointmentDetails.name,
                                  pathParameters: {'id': a.id},
                                );
                              },
                              onChangeStatus: (newStatus) {
                                if (PaymentStatusX.fromString(a.status) ==
                                    newStatus) {
                                  return;
                                }
                                context
                                    .read<AppointmentViewModel>()
                                    .updateStatus(
                                      a.id,
                                      a.status,
                                      a.price,
                                      newStatus.label,
                                      a.time,
                                    );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusCountCard extends StatelessWidget {
  const StatusCountCard({super.key, required this.status});

  final ({int missing, int paid, int uninvoiced, int waiting}) status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final items = [
      (
        Icons.check_circle_outlined,
        AppColors.greenMain,
        '${status.paid}',
        'Betalt',
      ),
      (
        Icons.access_time,
        AppColors.orangeMain,
        '${status.waiting}',
        'Afventer',
      ),
      (
        Icons.error_outline,
        AppColors.redMain,
        '${status.missing}',
        'Forfalden',
      ),
      (
        Icons.radio_button_unchecked,
        AppColors.greyMain,
        '${status.uninvoiced}',
        'Ufaktureret',
      ),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: CustomCard(
        field: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
          child: Row(
            children: items
                .map(
                  (e) => Expanded(
                    child: Column(
                      children: [
                        Icon(e.$1, color: e.$2, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          e.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.$4,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurface.withAlpha(180)),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
