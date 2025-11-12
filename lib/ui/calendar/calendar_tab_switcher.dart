import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/seg_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CalendarTabSwitcher extends StatelessWidget {
  const CalendarTabSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();
    final cs = Theme.of(context).colorScheme;

    return CupertinoSlidingSegmentedControl<Tabs>(
      groupValue: vm.tab,
      padding: const EdgeInsets.all(2),
      backgroundColor: cs.surface,
      thumbColor: cs.secondary,
      onValueChanged: (v) =>
          v != null ? context.read<CalendarViewModel>().setTab(v) : null,
      children: {
        Tabs.week: SegItem(
          icon: Icons.view_week,
          text: 'Uge',
          active: vm.tab == Tabs.week,
        ),
        Tabs.month: SegItem(
          icon: Icons.calendar_month,
          text: 'Måned',
          active: vm.tab == Tabs.month,
        ),
      },
    );
  }
}
