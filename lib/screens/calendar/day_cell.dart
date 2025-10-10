import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/status_color.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';

class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.date,
    required this.inCurrentMonth,
    this.monthChips = const [],
  });

  final DateTime date;
  final bool inCurrentMonth;
  final List<MonthChip> monthChips;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            '${date.day}',
            style: AppTypography.date1.copyWith(
              color: cs.onSurface.withAlpha(inCurrentMonth ? 255 : 150),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),

        _MonthChipsArea(chips: monthChips),
      ],
    );
  }
}

class _MonthChipsArea extends StatelessWidget {
  const _MonthChipsArea({required this.chips});
  final List<MonthChip> chips;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (chips.isEmpty) return const SizedBox.shrink();

    final visible = chips.take(2).toList();
    final remaining = chips.length - visible.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChipLine(chip: visible[0]),
          if (visible.length > 1) ...[
            const SizedBox(height: 4),
            _ChipLine(chip: visible[1]),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: 3),
            Text(
              '+ $remaining mere...',
              style: AppTypography.calChip.copyWith(
                color: cs.onSurface.withAlpha(200),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipLine extends StatelessWidget {
  const _ChipLine({required this.chip});
  final MonthChip chip;

  String _compactTitle(String s) {
    final t = s.trim();
    final space = t.indexOf(' ');
    if (space > 0) return '${t.substring(0, space)}...';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: statusColor(chip.status).withAlpha(220),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _compactTitle(chip.title),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.calChip.copyWith(color: Colors.white),
      ),
    );
  }
}
