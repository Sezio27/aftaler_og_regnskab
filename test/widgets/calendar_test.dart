import 'dart:async';

import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/screens/calendar/calendar_screen.dart';
import 'package:aftaler_og_regnskab/screens/calendar/month_grid.dart';
import 'package:aftaler_og_regnskab/screens/calendar/month_switcher.dart';
import 'package:aftaler_og_regnskab/screens/calendar/week_switcher.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

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

    when(() => calVM.tab).thenReturn(Tabs.month);

    when(() => calVM.monthTitle).thenReturn('Juni 2025');
    when(() => calVM.visibleMonth).thenReturn(DateTime(2025, 6, 1));

    when(() => calVM.visibleWeek).thenReturn(DateTime(2025, 6, 2));
    when(() => calVM.selectedDay).thenReturn(DateTime(2025, 6, 3));

    when(() => calVM.setTab(any())).thenAnswer((inv) {
      final next = inv.positionalArguments[0] as Tabs;
      when(() => calVM.tab).thenReturn(next);
      calVM.notifyListeners();
    });

    when(() => calVM.nextMonth()).thenAnswer((_) {
      when(() => calVM.visibleMonth).thenReturn(DateTime(2025, 7, 1));
      when(() => calVM.monthTitle).thenReturn('Juli 2025');
      calVM.notifyListeners();
    });
    when(() => calVM.prevMonth()).thenAnswer((_) {
      when(() => calVM.visibleMonth).thenReturn(DateTime(2025, 5, 1));
      when(() => calVM.monthTitle).thenReturn('Maj 2025');
      calVM.notifyListeners();
    });

    when(() => calVM.weekTitle).thenReturn('Uge 23');
    when(() => calVM.weekSubTitle).thenReturn('2–8 juni 2025');
    when(() => calVM.weekDays).thenReturn(
      List.generate(7, (i) => DateTime(2025, 6, 2 + i)), // Mon..Sun
    );

    when(() => apptVM.monthChipsOn(any())).thenReturn(const <MonthChip>[]);
    when(() => apptVM.hasEventsOn(any())).thenReturn(false);

    when(
      () => apptVM.cardsForDate(any()),
    ).thenAnswer((_) async => const <AppointmentCardModel>[]);
    when(() => apptVM.setActiveWindow(any())).thenAnswer((_) {});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Month vs Week body
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders Month body by default (MonthSwitcher + MonthGrid)', (
    tester,
  ) async {
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

    expect(find.byType(MonthSwitcher), findsOneWidget);
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.byType(WeekSwitcher), findsNothing);
    // AnimatedSwitcher shows the month body keyed as 'month'
    expect(find.byKey(const ValueKey('month')), findsOneWidget);
  });

  testWidgets(
    'switching to Week tab shows Week body and calls setActiveWindow',
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

      // Flip to week
      calVM.setTab(Tabs.week);
      await tester.pumpAndSettle();

      expect(find.byType(WeekSwitcher), findsOneWidget);
      expect(find.byKey(const ValueKey('week')), findsOneWidget);

      // Post-frame callback should call setActiveWindow(weekEnd)
      final weekStart = mondayOf(calVM.visibleWeek);
      final expectedEnd = weekStart.add(const Duration(days: 6));

      // Let the post-frame callback run
      await tester.pump();

      verify(() => apptVM.setActiveWindow(expectedEnd)).called(1);
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // FutureBuilder states (loading / empty / data) in Week view
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('Week view shows loader while cardsForDate is pending', (
    tester,
  ) async {
    // Make the future pending via Completer
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
      routeName: 'calendar', // avoids tab_config lookups
    );
    calVM.setTab(Tabs.week);
    await tester.pump(); // build Week body
    await tester.pump(); // trigger FutureBuilder waiting

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete to avoid dangling async work
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
      routeName: 'calendar', // avoids tab_config lookups
    );
    calVM.setTab(Tabs.week);
    await tester.pumpAndSettle();

    expect(find.text('Ingen aftaler denne dag'), findsOneWidget);
    expect(find.text('Ny aftale'), findsOneWidget); // CTA is visible under list
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
      routeName: 'calendar', // avoids tab_config lookups
    );
    calVM.setTab(Tabs.week);
    await tester.pumpAndSettle();

    // List items rendered via AppointmentCard (we assert by visible text)
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Makeup'), findsOneWidget);
    expect(find.text('Hår'), findsOneWidget);

    // CTA present
    expect(find.text('Ny aftale'), findsOneWidget);
  });
}
