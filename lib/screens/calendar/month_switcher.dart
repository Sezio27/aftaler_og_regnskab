import 'package:aftaler_og_regnskab/utils/string_extensions.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.select<CalendarViewModel, String>(
      (vm) => vm.monthTitle,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.read<CalendarViewModel>().prevMonth(),
          tooltip: 'Forrige måned',
        ),
        GestureDetector(
          onTap: () => context.read<CalendarViewModel>().jumpToCurrentMonth(),
          child: Text(
            title.capitalize(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => context.read<CalendarViewModel>().nextMonth(),
          tooltip: 'Næste måned',
        ),
      ],
    );
  }
}
