import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/string_extensions.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WeekSwitcher extends StatelessWidget {
  const WeekSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = context.select<CalendarViewModel, String>(
      (vm) => vm.weekTitle,
    );

    final subTitle = context.select<CalendarViewModel, String>(
      (vm) => vm.weekSubTitle,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: cs.onSurface),
            onPressed: () => context.read<CalendarViewModel>().prevWeek(),
          ),
          GestureDetector(
            onTap: () => context.read<CalendarViewModel>().jumpToCurrentWeek(),
            child: Column(
              children: [
                Text(title.capitalize(), style: AppTypography.acTtitle),
                const SizedBox(height: 4),
                Text(subTitle.capitalize(), style: AppTypography.acSubtitle),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: cs.onSurface),
            onPressed: () => context.read<CalendarViewModel>().nextWeek(),
          ),
        ],
      ),
    );
  }
}
