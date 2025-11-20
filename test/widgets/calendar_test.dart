import 'dart:async';

import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/ui/calendar/calendar_screen.dart';
import 'package:aftaler_og_regnskab/ui/calendar/month_grid.dart';
import 'package:aftaler_og_regnskab/ui/calendar/month_switcher.dart';
import 'package:aftaler_og_regnskab/ui/calendar/week_switcher.dart';
import 'package:aftaler_og_regnskab/ui/calendar/week_day_header.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../support/mocks.dart';
import '../support/test_wrappers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('da');

    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(Tabs.month);
  });

  late MockCalendarVM calVM;
  late MockAppointmentVM apptVM;

  setUp(() {
    apptVM = MockAppointmentVM();
    calVM = MockCalendarVM();

    // Default tab: month view.
    when(() => calVM.tab).thenReturn(Tabs.month);

    // Month state.
    when(() => calVM.monthTitle).thenReturn('Juni 2025');
    when(() => calVM.visibleMonth).thenReturn(DateTime(2025, 6, 1));

    // Week state.
    when(() => calVM.visibleWeek).thenReturn(DateTime(2025, 6, 2));
    when(() => calVM.selectedDay).thenReturn(DateTime(2025, 6, 3));
    when(() => calVM.weekTitle).thenReturn('Uge 23');
    when(() => calVM.weekSubTitle).thenReturn('2–8 juni 2025');
    when(() => calVM.weekDays).thenReturn(
      List.generate(7, (i) => DateTime(2025, 6, 2 + i)), // Mon..Sun
    );

    // Switching tabs mutates calVM.tab and notifies listeners.
    when(() => calVM.setTab(any())).thenAnswer((inv) {
      final next = inv.positionalArguments[0] as Tabs;
      when(() => calVM.tab).thenReturn(next);
      calVM.notifyListeners();
    });

    // We do not need prev/next week/month behaviour for these tests, so they
    // can just be no-ops if called.
    when(() => calVM.prevMonth()).thenAnswer((_) {});
    when(() => calVM.nextMonth()).thenAnswer((_) {});
    when(() => calVM.prevWeek()).thenAnswer((_) {});
    when(() => calVM.nextWeek()).thenAnswer((_) {});
    when(() => calVM.jumpToCurrentMonth()).thenAnswer((_) {});
    when(() => calVM.jumpToCurrentWeek()).thenAnswer((_) {});
    when(() => calVM.selectDay(any())).thenAnswer((_) {});

    // Appointment VM: default no events / cards, no-op loading.
    when(() => apptVM.monthChipsOn(any())).thenReturn(const <MonthChip>[]);
    when(() => apptVM.hasEventsOn(any())).thenReturn(false);
    when(
      () => apptVM.cardsForDate(any()),
    ).thenAnswer((_) async => const <AppointmentCardModel>[]);
    when(() => apptVM.ensureMonthLoaded(any())).thenAnswer((_) async {});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Month vs Week body
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets(
    'renders Month body by default (MonthSwitcher + WeekdayHeader + MonthGrid)',
    (tester) async {
      await pumpWithShell(
        tester,
        child: const CalendarScreen(),
        providers: [
          ChangeNotifierProvider<CalendarViewModel>.value(value: calVM),
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ],
        location: '/calendar',
        routeName: 'calendar',
      );

      await tester.pump(const Duration(milliseconds: 1));

      // Month UI pieces
      expect(find.byType(MonthSwitcher), findsOneWidget);
      expect(find.byType(WeekdayHeader), findsOneWidget);
      expect(find.byType(MonthGrid), findsOneWidget);

      // Week-only pieces are not shown.
      expect(find.byType(WeekSwitcher), findsNothing);

      // AnimatedSwitcher shows the month body keyed as 'month'
      expect(find.byKey(const ValueKey('month')), findsOneWidget);
      expect(find.byKey(const ValueKey('week')), findsNothing);
    },
  );

  testWidgets(
    'switching to Week tab shows Week body and calls ensureMonthLoaded for week end',
    (tester) async {
      await pumpWithShell(
        tester,
        child: const CalendarScreen(),
        providers: [
          ChangeNotifierProvider<CalendarViewModel>.value(value: calVM),
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ],
        location: '/calendar',
        routeName: 'calendar',
      );

      // Switch to week tab through the mocked VM.
      calVM.setTab(Tabs.week);

      // Let AnimatedSwitcher build the week body.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      // Week UI pieces visible.
      expect(find.byType(WeekSwitcher), findsOneWidget);

      // Because AnimatedSwitcher keeps old+new children during the transition,
      // we may briefly have 2 WeekdayHeader widgets in the tree. Just assert
      // that at least one exists.
      expect(find.byType(WeekdayHeader), findsAtLeastNWidgets(1));

      expect(find.byKey(const ValueKey('week')), findsOneWidget);

      // Week range [mondayOf(visibleWeek) .. +6 days] is passed to ensureMonthLoaded.
      final weekStart = mondayOf(calVM.visibleWeek);
      final expectedEnd = weekStart.add(const Duration(days: 6));

      // Run the post-frame callback that calls ensureMonthLoaded.
      await tester.pump();

      verify(() => apptVM.ensureMonthLoaded(expectedEnd)).called(1);
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // FutureBuilder states (loading / empty / data) in Week view
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('Week view shows loader while cardsForDate is pending', (
    tester,
  ) async {
    // Make the future pending via Completer to force the loading state.
    final completer = Completer<List<AppointmentCardModel>>();
    when(() => apptVM.cardsForDate(any())).thenAnswer((_) => completer.future);

    await pumpWithShell(
      tester,
      child: const CalendarScreen(),
      providers: [
        ChangeNotifierProvider<CalendarViewModel>.value(value: calVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/calendar',
      routeName: 'calendar',
    );

    calVM.setTab(Tabs.week);
    await tester.pump(); // build Week body
    await tester.pump(); // trigger FutureBuilder waiting

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete to avoid dangling async work and let the tree settle.
    completer.complete(const <AppointmentCardModel>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('Week view shows empty state when no items', (tester) async {
    when(
      () => apptVM.cardsForDate(any()),
    ).thenAnswer((_) async => const <AppointmentCardModel>[]);

    await pumpWithShell(
      tester,
      child: const CalendarScreen(),
      providers: [
        ChangeNotifierProvider<CalendarViewModel>.value(value: calVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/calendar',
      routeName: 'calendar',
    );

    calVM.setTab(Tabs.week);
    await tester.pumpAndSettle();

    expect(find.text('Ingen aftaler denne dag'), findsOneWidget);
    expect(find.text('Ny aftale'), findsOneWidget); // CTA under list
  });

  testWidgets('Week view renders items when data exists', (tester) async {
    final now = DateTime(2025, 6, 3, 10, 30);
    final items = <AppointmentCardModel>[
      AppointmentCardModel(
        id: 'w1',
        clientName: 'Alice',
        serviceName: 'Makeup',
        duration: '45',
        price: 250.0,
        status: 'Afventer',
        time: now,
        imageUrl: null,
      ),
      AppointmentCardModel(
        id: 'w2',
        clientName: 'Bob',
        serviceName: 'Hår',
        duration: '30',
        price: 300.0,
        status: 'Betalt',
        time: now.add(const Duration(hours: 1)),
        imageUrl: null,
      ),
    ];
    when(() => apptVM.cardsForDate(any())).thenAnswer((_) async => items);

    await pumpWithShell(
      tester,
      child: const CalendarScreen(),
      providers: [
        ChangeNotifierProvider<CalendarViewModel>.value(value: calVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/calendar',
      routeName: 'calendar',
    );

    calVM.setTab(Tabs.week);
    await tester.pumpAndSettle();

    // Items are rendered via AppointmentCard; assert by visible text.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Makeup'), findsOneWidget);
    expect(find.text('Hår'), findsOneWidget);

    // CTA present.
    expect(find.text('Ny aftale'), findsOneWidget);
  });
}
