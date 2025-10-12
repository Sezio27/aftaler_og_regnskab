// lib/screens/finance_screen.dart
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card_status.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';

enum Tabs { week, month, year }

typedef DateRange = ({DateTime start, DateTime end});

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Tabs _tab = Tabs.week;

  // Cache the "recent" list query to avoid refetching on unrelated rebuilds.
  Future<List<AppointmentCardModel>>? _recentFuture;

  @override
  void initState() {
    super.initState();
    // Top-level already did: vm.setActiveRange(Jan 1..Dec 31 of current year).
    // Here we only build the recent-list future once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildRecentFuture();
      setState(() {});
    });
  }

  DateRange _rangeForTab(Tabs t, DateTime now) => switch (t) {
    Tabs.week => weekRange(now),
    Tabs.month => monthRange(now),
    Tabs.year => yearRange(now),
  };

  void _buildRecentFuture() {
    final vm = context.read<AppointmentViewModel>();
    final now = DateTime.now();
    final r = monthRange(now); // "Seneste aftaler" for current month
    _recentFuture = vm.cardsForRange(r.start, r.end);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat.currency(
      locale: 'da',
      symbol: 'kr.',
      decimalDigits: 0,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: LayoutMetrics.minHPadPhone,
        ),
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
                // No setActiveRange here — top-level manages a year window.
                // If you want the "recent" list to follow the tab, you can:
                // _buildRecentFuture(); setState(() {});
              },
              children: {
                Tabs.week: SegItem(
                  icon: Icons.face_retouching_natural,
                  text: 'Uge',
                  active: _tab == Tabs.week,
                ),
                Tabs.month: SegItem(
                  icon: Icons.event_note_outlined,
                  text: 'Måned',
                  active: _tab == Tabs.month,
                ),
                Tabs.year: SegItem(
                  icon: Icons.event_note_outlined,
                  text: 'År',
                  active: _tab == Tabs.year,
                ),
              },
            ),

            const SizedBox(height: 16),

            // Summary cards (income + count) — only these rebuild when VM data changes.
            Selector<AppointmentViewModel, ({int count, double income})>(
              selector: (_, vm) {
                final r = _rangeForTab(_tab, DateTime.now());
                return (
                  count: vm.countAppointmentsInRange(r.start, r.end),
                  income: vm.sumPaidInRangeDKK(r.start, r.end),
                );
              },
              shouldRebuild: (a, b) =>
                  a.count != b.count || a.income != b.income,
              builder: (_, data, __) {
                return Row(
                  children: [
                    _SummaryCard(
                      title: 'Indtægt',
                      value: nf.format(data.income),
                      change: '+12% siden sidste uge',
                      changeColor: Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _SummaryCard(
                      title: 'Aftaler',
                      value: '${data.count}',
                      change: '+8% siden sidste uge',
                      changeColor: Colors.green,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // KPI block (status buckets) — rebuilt independently via Selector.
            Selector<
              AppointmentViewModel,
              ({int paid, int waiting, int missing, int uninvoiced})
            >(
              selector: (_, vm) {
                final r = _rangeForTab(_tab, DateTime.now());
                final s = vm.statusCount(r.start, r.end);
                return (
                  paid: s.paid,
                  waiting: s.waiting,
                  missing: s.missing,
                  uninvoiced: s.uninvoiced,
                );
              },
              shouldRebuild: (a, b) =>
                  a.paid != b.paid ||
                  a.waiting != b.waiting ||
                  a.missing != b.missing ||
                  a.uninvoiced != b.uninvoiced,
              builder: (_, s, __) {
                final k = [
                  (
                    Icons.check_circle_outlined,
                    AppColors.greenMain,
                    '${s.paid}',
                    'Betalt',
                  ),
                  (
                    Icons.access_time,
                    AppColors.orangeMain,
                    '${s.waiting}',
                    'Afventer',
                  ),
                  (
                    Icons.error_outline,
                    AppColors.redMain,
                    '${s.missing}',
                    'Forfalden',
                  ),
                  (
                    Icons.radio_button_unchecked,
                    AppColors.greyMain,
                    '${s.uninvoiced}',
                    'Ufaktureret',
                  ),
                ];
                return CustomCard(
                  field: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 30,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        for (final e in k)
                          Expanded(
                            child: _KpiCard(
                              icon: e.$1,
                              color: e.$2,
                              value: e.$3,
                              label: e.$4,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Recent list (cached Future + per-row Stream so only changed row rebuilds)
            CustomCard(
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
                        final r = monthRange(now); // or whatever you want here
                        return vm.cardsForRangeSync(r.start, r.end);
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
                            horizontal: 16,
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
                              priceText: a.price ?? '---',
                              status: a.status,
                              onSeeDetails: () {},
                              onChangeStatus: (newStatus) {
                                context
                                    .read<AppointmentViewModel>()
                                    .updateStatus(a.id, newStatus.label);
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.change,
    required this.changeColor,
  });

  final String title;
  final String value;
  final String change;
  final Color changeColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomCard(
        constraints: const BoxConstraints(minHeight: 160),
        field: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, textAlign: TextAlign.center, style: AppTypography.b2),
              const SizedBox(height: 6),
              Text(
                value,
                textAlign: TextAlign.center,
                style: AppTypography.num4,
              ),
              const SizedBox(height: 2),
              Text(
                change,
                style: AppTypography.num5.copyWith(color: changeColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withAlpha(180)),
        ),
      ],
    );
  }
}
