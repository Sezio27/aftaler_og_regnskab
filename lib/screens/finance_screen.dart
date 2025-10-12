import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card_status.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum Tabs { week, month, year }

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Tabs _tab = Tabs.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final y = yearRange(now);
      context.read<AppointmentViewModel>().setActiveRange(y.start, y.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final apptVm = context.watch<AppointmentViewModel>();
    final nf = NumberFormat.currency(
      locale: 'da',
      symbol: 'kr.',
      decimalDigits: 0,
    );
    final now = DateTime.now();

    final range = switch (_tab) {
      Tabs.week => weekRange(now),
      Tabs.month => monthRange(now),
      Tabs.year => yearRange(now),
    };

    final prevMonth = prevMonthRange(now);

    final count = apptVm.countAppointmentsInRange(range.start, range.end);
    final income = apptVm.sumPaidInRangeDKK(range.start, range.end);
    final statusCount = apptVm.statusCount(range.start, range.end);

    final kpis = [
      (
        icon: Icons.check_circle_outlined,
        color: AppColors.greenMain,
        value: '${statusCount.paid}',
        label: 'Betalt',
      ),
      (
        icon: Icons.access_time,
        color: AppColors.orangeMain,
        value: '${statusCount.waiting}',
        label: 'Afventer',
      ),
      (
        icon: Icons.error_outline,
        color: AppColors.redMain,
        value: '${statusCount.missing}',
        label: 'Forfalden',
      ),
      (
        icon: Icons.radio_button_unchecked,
        color: AppColors.greyMain,
        value: '${statusCount.uninvoiced}',
        label: 'Ufaktureret',
      ),
    ];

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
              onValueChanged: (v) => setState(() => _tab = v!),
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

            Row(
              children: [
                _SummaryCard(
                  title: 'Indtægt',
                  value: nf.format(income),
                  change: '+12% siden sidste uge',
                  changeColor: Colors.green,
                ),

                const SizedBox(width: 16),
                _SummaryCard(
                  title: 'Aftaler',
                  value: count.toString(),
                  change: '+8% siden sidste uge',
                  changeColor: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 16),
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final k in kpis)
                      Expanded(
                        child: _KpiCard(
                          icon: k.icon,
                          color: k.color,
                          value: k.value,
                          label: k.label,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined),
                              SizedBox(width: 12),
                              Text(
                                'Seneste aftaler',
                                style: AppTypography.b2.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
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
                    FutureBuilder<List<AppointmentCardModel>>(
                      future: cardsForRange(
                        apptVm,
                        prevMonth.start,
                        prevMonth.end,
                      ),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final items = snap.data ?? const [];
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
                            final timeText = MaterialLocalizations.of(context)
                                .formatTimeOfDay(
                                  TimeOfDay.fromDateTime(a.time),
                                  alwaysUse24HourFormat: true,
                                );

                            return AppointmentStatusCard(
                              title: a.clientName,
                              service: a.serviceName,
                              dateText: dateText,
                              priceText: a.price ?? "---",
                              status: a.status,
                              onSeeDetails: () {},
                              onChangeStatus: (newStatus) {
                                setState(() {});
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
