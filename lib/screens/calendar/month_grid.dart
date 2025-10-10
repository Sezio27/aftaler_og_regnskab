import 'package:aftaler_og_regnskab/screens/calendar/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewModel/calendar_view_model.dart';
import '../../viewModel/appointment_view_model.dart';

class MonthGrid extends StatefulWidget {
  const MonthGrid({super.key});

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid> {
  DateTime? _lastStart;
  DateTime? _lastEnd;

  @override
  Widget build(BuildContext context) {
    final calVm = context.watch<CalendarViewModel>();
    final apptVm = context.watch<AppointmentViewModel>();

    final visibleMonth = calVm.visibleMonth;
    final days = _buildMonthDays(visibleMonth);
    final weeks = (days.length / 7).ceil();

    // final start = days.first;
    // final end = days.last;
    // if (_lastStart != start || _lastEnd != end) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     context.read<AppointmentViewModel>().prefetchForRange(start, end);
    //   });
    //   _lastStart = start;
    //   _lastEnd = end;
    // }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight / weeks;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            mainAxisExtent: rowHeight,
          ),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final date = days[i];
            final inMonth = date.month == visibleMonth.month;

            final chips = apptVm.monthChipsOn(date);
            return DayCell(
              date: date,
              inCurrentMonth: inMonth,
              monthChips: chips,
            );
          },
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

    final startShift = (firstOfMonth.weekday - DateTime.monday) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: startShift));
    final endShift = (DateTime.sunday - lastOfMonth.weekday) % 7;
    final gridEnd = lastOfMonth.add(Duration(days: endShift));

    final totalDays = gridEnd.difference(gridStart).inDays + 1;
    return List.generate(
      totalDays,
      (i) => DateTime(gridStart.year, gridStart.month, gridStart.day + i),
    );
  }
}
