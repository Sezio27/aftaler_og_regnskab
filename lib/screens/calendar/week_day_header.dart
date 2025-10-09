import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/string_extensions.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WeekdayHeader extends StatelessWidget {
  final bool weekView;
  const WeekdayHeader({super.key, this.weekView = false});
  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<String> _weekdayShortLabels(BuildContext c) {
    final loc = Localizations.localeOf(c).toLanguageTag();
    final start = MaterialLocalizations.of(c).firstDayOfWeekIndex; // 0..6
    final ds = DateFormat('EEE', loc).dateSymbols;
    final base = ds.STANDALONESHORTWEEKDAYS;

    return List.generate(7, (i) {
      return base[(start + i) % 7];
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = _weekdayShortLabels(context);

    if (!weekView) {
      return Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(l.capitalize(), style: AppTypography.b5),
              ),
            ),
        ],
      );
    }

    final vm = context.watch<CalendarViewModel>();
    final days = vm.weekDays;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        const minVelocity = 250;
        if (v > minVelocity) {
          context.read<CalendarViewModel>().nextWeek();
        } else if (v < -minVelocity) {
          context.read<CalendarViewModel>().prevWeek();
        }
      },
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _DayPill(
                date: days[i],
                weekdayLabel: labels[i].capitalize(),
                isSelected: _sameDate(days[i], vm.selectedDay),
                isToday: _sameDate(days[i], DateTime.now()),
                eventCount: vm.eventCountFor(days[i]),
                onTap: () =>
                    context.read<CalendarViewModel>().selectDay(days[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.date,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.eventCount,

    required this.onTap,
  });

  final DateTime date;
  final String weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final int eventCount;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = isSelected ? cs.secondary : Colors.transparent;
    final fg = isSelected ? Colors.white : cs.onSurface;
    final selected = AppTypography.b8.copyWith(color: fg);
    final notSelected = AppTypography.b5.copyWith(color: fg);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(weekdayLabel, style: isSelected ? selected : notSelected),
              const SizedBox(height: 6),
              Text(
                '${date.day}',
                style: AppTypography.num7.copyWith(color: fg),
              ),
              const SizedBox(height: 8),
              _EventDots(
                count: eventCount,
                color: isSelected ? cs.onSecondary : cs.secondary,
                todayHint: isToday && eventCount == 0,
                todayColor: isSelected ? cs.onSecondary : cs.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDots extends StatelessWidget {
  const _EventDots({
    required this.count,
    required this.color,
    required this.todayHint,
    required this.todayColor,
  });

  final int count;
  final Color color;
  final bool todayHint;
  final Color todayColor;

  @override
  Widget build(BuildContext context) {
    if (count > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: _dot(color),
      );
    }
    if (todayHint) return _dot(todayColor);
    return const SizedBox(height: 6);
  }

  Widget _dot(Color c) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
