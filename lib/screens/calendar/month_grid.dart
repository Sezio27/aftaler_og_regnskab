import 'package:aftaler_og_regnskab/screens/calendar/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewModel/calendar_view_model.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();
    final visibleMonth = vm.visibleMonth; // first day of month
    final days = _buildMonthDays(visibleMonth); // Mon..Sun, exact span
    final weeks = (days.length / 7).ceil(); // 4, 5, or 6

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final cellHeight = cellWidth + 36; // room for events

        return SizedBox(
          height: cellHeight * weeks,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              mainAxisExtent: cellHeight,
            ),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final date = days[i];
              final inMonth = date.month == visibleMonth.month;
              return DayCell(date: date, inCurrentMonth: inMonth);
            },
          ),
        );
      },
    );
  }

  List<DateTime> _buildMonthDays(DateTime monthFirstDay) {
    final firstOfMonth = DateTime(monthFirstDay.year, monthFirstDay.month, 1);
    final lastOfMonth = DateTime(
      monthFirstDay.year,
      monthFirstDay.month + 1,
      0,
    );

    // Shift start back to Monday (Monday=1..Sunday=7)
    final startShift = (firstOfMonth.weekday - DateTime.monday) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: startShift));

    // Shift end forward to Sunday
    final endShift = (DateTime.sunday - lastOfMonth.weekday) % 7;
    final gridEnd = lastOfMonth.add(Duration(days: endShift));

    final totalDays = gridEnd.difference(gridStart).inDays + 1; // inclusive
    return List.generate(
      totalDays,
      (i) => DateTime(gridStart.year, gridStart.month, gridStart.day + i),
    );
  }
}
