import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/screens/calendar/month_grid.dart';
import 'package:aftaler_og_regnskab/screens/calendar/month_switcher.dart';

import 'package:aftaler_og_regnskab/screens/calendar/week_switcher.dart';
import 'package:aftaler_og_regnskab/screens/calendar/week_day_header.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<CalendarViewModel>().tab;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: tab == Tabs.month
                ? _MonthViewBody(key: const ValueKey('month'))
                : _WeekViewBody(key: const ValueKey('week')),
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
        SizedBox(height: 6),
        MonthSwitcher(),
        SizedBox(height: 12),
        WeekdayHeader(),
        SizedBox(height: 8),
        Expanded(child: MonthGrid()),
      ],
    );
  }
}

class _WeekViewBody extends StatelessWidget {
  const _WeekViewBody({super.key});
  @override
  Widget build(BuildContext context) {
    final selectedDay = context.select<CalendarViewModel, DateTime>(
      (vm) => vm.selectedDay,
    );
    return Column(
      children: [
        const SizedBox(height: 14),
        WeekSwitcher(),
        const SizedBox(height: 10),
        WeekdayHeader(weekView: true),
        const SizedBox(height: 30),
        Expanded(
          child: FutureBuilder<List<AppointmentCardModel>>(
            // ensure a new future when the date changes
            key: ValueKey(
              '${selectedDay.year}-${selectedDay.month}-${selectedDay.day}',
            ),
            future: context.read<AppointmentViewModel>().cardsForDate(
              selectedDay,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return _EmptyDayState();
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final a = items[i];

                  // Localized date/time for the card
                  final dateText = DateFormat('d/M', 'da').format(a.time);
                  final timeText = MaterialLocalizations.of(context)
                      .formatTimeOfDay(
                        TimeOfDay.fromDateTime(a.time),
                        alwaysUse24HourFormat: true,
                      );

                  return AppointmentCard(
                    title: a.clientName,
                    subtitle: a.serviceName,
                    price: a.price, // shows top-right
                    // If you add these props to the card (see below), pass them:
                    date: dateText, // bottom-right date
                    time: timeText, // bottom-right time
                    // You can also pass phone/email to trailing actions if you expose them
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyDayState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Ingen aftaler denne dag',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
