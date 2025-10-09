import 'package:aftaler_og_regnskab/screens/calendar/month_grid.dart';
import 'package:aftaler_og_regnskab/screens/calendar/month_switcher.dart';
import 'package:aftaler_og_regnskab/screens/calendar/weekday_header.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<CalendarViewModel>().tab;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: tab == Tabs.month
                ? _MonthViewBody(key: const ValueKey('month'))
                : _WeekViewPlaceholder(key: const ValueKey('week')),
          ),
        ),
      ],
    );
  }
}

class _MonthViewBody extends StatelessWidget {
  const _MonthViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 8),
        MonthSwitcher(),
        SizedBox(height: 12),
        WeekdayHeader(),
        SizedBox(height: 8),
        Expanded(child: MonthGrid()),
      ],
    );
  }
}

class _WeekViewPlaceholder extends StatelessWidget {
  const _WeekViewPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Ugevisning kommer…'));
  }
}
