import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/date_range.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:aftaler_og_regnskab/widgets/stat_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final now = DateTime.now();

    final w = weekRange(now);
    final m = monthRange(now);
    final y = yearRange(now);

    final weeklyCount = apptVm.countAppointmentsInRange(w.start, w.end);
    final weeklyPaid = apptVm.sumPaidInRangeDKK(w.start, w.end);
    final monthlyCount = apptVm.countAppointmentsInRange(m.start, m.end);
    final monthlyPaid = apptVm.sumPaidInRangeDKK(m.start, m.end);
    final yearlyCount = apptVm.countAppointmentsInRange(y.start, y.end);
    final yearlyPaid = apptVm.sumPaidInRangeDKK(y.start, y.end);
    final isYearActive =
        apptVm.activeRangeStart ==
            DateTime(y.start.year, y.start.month, y.start.day) &&
        apptVm.activeRangeEnd == DateTime(y.end.year, y.end.month, y.end.day);

    // 🔒 gate Year view until first year snapshot has landed
    if (_tab == Tabs.year && (!isYearActive || !apptVm.hasDataForActiveRange)) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    final income = switch (_tab) {
      Tabs.week => weeklyPaid,
      Tabs.month => monthlyPaid,
      Tabs.year => yearlyPaid,
    };
    final appointmentCount = switch (_tab) {
      Tabs.week => weeklyCount,
      Tabs.month => monthlyCount,
      Tabs.year => yearlyCount,
    };

    debugPrint(
      'Finance gate: tab=$_tab '
      'isYearActive=$isYearActive '
      'hasData=${apptVm.hasDataForActiveRange} '
      'all=${apptVm.all.length}',
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
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

            Expanded(
              child: Row(
                children: [
                  _SummaryCard(
                    title: 'Indtægt',
                    value: '${income.toStringAsFixed(0)} Kr.',
                    change: '+12% siden sidste uge',
                    changeColor: Colors.green,
                  ),

                  const SizedBox(width: 16),
                  _SummaryCard(
                    title: 'Aftaler',
                    value: appointmentCount.toString(),
                    change: '+8% siden sidste uge',
                    changeColor: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            CustomCard(
              constraints: const BoxConstraints(minHeight: 145),
              field: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: _KpiCard(
                          icon: Icons.check_circle_outlined,
                          color: Colors.green,
                          value: '2',
                          label: 'Betalt',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _KpiCard(
                          icon: Icons.access_time,
                          color: Colors.orange,
                          value: '1',
                          label: 'Afventer',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _KpiCard(
                          icon: Icons.error_outline,
                          color: Colors.red,
                          value: '1',
                          label: 'Forfalden',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _KpiCard(
                          icon: Icons.radio_button_unchecked,
                          color: cs.onSurface,
                          value: '1',
                          label: 'Ufaktureret',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: CustomCard(
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
                    ],
                  ),
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
        constraints: const BoxConstraints(minHeight: 180),
        field: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
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

/// Compact KPI style (icon + number centered, label below)
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 2),
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
          style: TextStyle(color: cs.onSurface.withOpacity(.7)),
        ),
      ],
    );
  }
}
