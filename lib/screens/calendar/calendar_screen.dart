import 'package:aftaler_og_regnskab/screens/calendar/month_grid.dart';
import 'package:aftaler_og_regnskab/screens/calendar/month_switcher.dart';
import 'package:aftaler_og_regnskab/screens/calendar/weekday_header.dart';
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        SizedBox(height: 8),
        MonthSwitcher(),
        SizedBox(height: 12),
        WeekdayHeader(),
        SizedBox(height: 8),
        MonthGrid(),
      ],
    );
  }
}
