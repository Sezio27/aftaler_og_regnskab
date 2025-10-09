import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';

class DayCell extends StatelessWidget {
  const DayCell({super.key, required this.date, required this.inCurrentMonth});

  final DateTime date;
  final bool inCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _isSameDate(date, DateTime.now());

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: today ? cs.primary : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: AppTypography.num5.copyWith(
                color: cs.onSurface.withAlpha(inCurrentMonth ? 255 : 150),
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: _EventPlaceholderRow(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EventPlaceholderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _pill(cs.tertiary.withOpacity(0.25), width: 44),
        _pill(cs.primary.withOpacity(0.25), width: 36),
      ],
    );
  }

  Widget _pill(Color color, {double width = 40}) {
    return Container(
      height: 14,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
