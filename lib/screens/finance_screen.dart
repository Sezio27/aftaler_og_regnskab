import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/seg_item.dart';
import 'package:aftaler_og_regnskab/widgets/stat_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum Tabs { week, month, year }

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Tabs _tab = Tabs.week;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  const SizedBox(height: 8),

                  // Row 1
                  Row(
                    children: [
                      Expanded(
                        child: CustomCard(
                          constraints: const BoxConstraints(minHeight: 170),
                          field: _SummaryCard(
                            title: 'Indtægt',
                            value: '7,500 Kr.',
                            change: '+12% siden sidste uge',
                            changeColor: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomCard(
                          constraints: const BoxConstraints(minHeight: 170),
                          field: _SummaryCard(
                            title: 'Aftaler',
                            value: '5',
                            change: '+8% siden sidste uge',
                            changeColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomCard(
                          field: _KpiCard(
                            icon: Icons.check_circle_outlined,
                            color: Colors.green,
                            value: '2',
                            label: 'Betalt',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomCard(
                          field: _KpiCard(
                            icon: Icons.access_time,
                            color: Colors.orange,
                            value: '1',
                            label: 'Afventer',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomCard(
                          field: _KpiCard(
                            icon: Icons.error_outline,
                            color: Colors.red,
                            value: '1',
                            label: 'Forfalden',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomCard(
                          field: _KpiCard(
                            icon: Icons.radio_button_unchecked,
                            color: cs.onSurface,
                            value: '1',
                            label: 'Ikke faktureret',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.center, style: AppTypography.b2),
          const SizedBox(height: 6),
          Text(value, textAlign: TextAlign.center, style: AppTypography.num4),
          const SizedBox(height: 2),
          Text(change, style: AppTypography.num5.copyWith(color: changeColor)),
        ],
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
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}
