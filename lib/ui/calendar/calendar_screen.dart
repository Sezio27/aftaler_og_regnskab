import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/ui/calendar/month_grid.dart';
import 'package:aftaler_og_regnskab/ui/calendar/month_switcher.dart';
import 'package:aftaler_og_regnskab/ui/calendar/week_switcher.dart';
import 'package:aftaler_og_regnskab/ui/calendar/week_day_header.dart';
import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/cards/appointment_card.dart';
import 'package:aftaler_og_regnskab/ui/widgets/images/avatar.dart';
import 'package:aftaler_og_regnskab/ui/widgets/buttons/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentTab = context.watch<CalendarViewModel>().tab;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        6,
        0,
        6,
        6 + LayoutMetrics.navBarHeight(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: currentTab == Tabs.month
                  ? const _MonthViewBody(key: ValueKey('month'))
                  : const _WeekViewBody(key: ValueKey('week')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthViewBody extends StatelessWidget {
  const _MonthViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 6),
        MonthSwitcher(),
        SizedBox(height: 30),
        WeekdayHeader(),
        SizedBox(height: 12),
        Expanded(child: MonthGrid()),
      ],
    );
  }
}

class _WeekViewBody extends StatelessWidget {
  const _WeekViewBody({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedDay = context.select<CalendarViewModel, DateTime>(
      (vm) => vm.selectedDay,
    );

    final calVm = context.watch<CalendarViewModel>();

    final apptVm = context.watch<AppointmentViewModel>();

    final weekStart = mondayOf(calVm.visibleWeek);
    final weekEnd = weekStart.add(const Duration(days: 6));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      apptVm.setActiveWindow(weekEnd);
    });

    return Column(
      children: [
        const SizedBox(height: 14),
        const WeekSwitcher(),
        const SizedBox(height: 18),
        const WeekdayHeader(weekView: true),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<AppointmentCardModel>>(
            key: ValueKey(
              '${selectedDay.year}-${selectedDay.month}-${selectedDay.day}',
            ),
            future: apptVm.cardsForDate(selectedDay),
            builder: (context, snap) {
              final waiting = snap.connectionState == ConnectionState.waiting;
              final items = snap.data ?? const [];

              Widget listPart;
              if (waiting) {
                listPart = const Center(child: CircularProgressIndicator());
              } else if (items.isEmpty) {
                listPart = const _EmptyDayState();
              } else {
                listPart = ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = items[i];
                    final dateText = DateFormat('d/M', 'da').format(a.time);
                    final timeText = MaterialLocalizations.of(context)
                        .formatTimeOfDay(
                          TimeOfDay.fromDateTime(a.time),
                          alwaysUse24HourFormat: true,
                        );
                    return AppointmentCard(
                      avatar: Avatar(imageUrl: a.imageUrl),
                      title: a.clientName,
                      subtitle: a.serviceName,
                      price: a.price,
                      date: dateText,
                      time: timeText,
                      color: statusColor(a.status),
                      onTap: () {
                        context.pushNamed(
                          AppRoute.appointmentDetails.name,
                          pathParameters: {'id': a.id},
                        );
                      },
                    );
                  },
                );
              }

              return Column(
                children: [
                  Expanded(child: listPart),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: CustomButton(
                      text: "Ny aftale",
                      icon: Icon(Icons.add, size: 18, color: cs.onSurface),
                      color: cs.surface,
                      width: 170,
                      borderRadius: 18,
                      textStyle: AppTypography.button2.copyWith(
                        color: cs.onSurface,
                      ),

                      onTap: () => context.pushNamed(
                        AppRoute.newAppointment.name,
                        queryParameters: {
                          'date': selectedDay.toIso8601String(),
                        },
                      ),
                      elevation: 2.2,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyDayState extends StatelessWidget {
  const _EmptyDayState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Ingen aftaler denne dag',
          style: AppTypography.b5.copyWith(color: cs.onSurface.withAlpha(150)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
