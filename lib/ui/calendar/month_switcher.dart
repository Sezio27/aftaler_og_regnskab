import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/string_extensions.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = context.select<CalendarViewModel, String>(
      (vm) => vm.monthTitle,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: cs.onSurface),
            onPressed: () => context.read<CalendarViewModel>().prevMonth(),
          ),
          GestureDetector(
            onTap: () => context.read<CalendarViewModel>().jumpToCurrentMonth(),
            child: Text(title.capitalize(), style: AppTypography.acTtitle),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: cs.onSurface),
            onPressed: () => context.read<CalendarViewModel>().nextMonth(),
          ),
        ],
      ),
    );
  }
}
