import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/mocks.dart';
import '../support/test_wrappers.dart';

void main() {
  setUpAll(() async {
    // Date formatting for 'da' used by DateFormat in the widget.
    await initializeDateFormatting('da');

    // Fallbacks for matchers
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(Segment.month);
  });

  late MockFinanceVM financeVM;
  late MockAppointmentVM apptVM;

  setUp(() {
    financeVM = MockFinanceVM();
    apptVM = MockAppointmentVM();

    // Default stubs
    when(() => financeVM.ensureFinanceForHomeSeeded()).thenAnswer((_) async {});
    when(() => financeVM.summaryNow(any())).thenReturn((income: 0.0, count: 0));

    // New flag used by HomeScreen selector
    when(() => apptVM.hasLoadedInitialWindow).thenReturn(false);

    when(
      () => apptVM.cardsForRange(any(), any()),
    ).thenReturn(const <AppointmentCardModel>[]);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Init behaviour
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('calls ensureFinanceForHomeSeeded on first frame', (
    tester,
  ) async {
    await pumpWithShell(
      tester,
      child: const HomeScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/home',
      routeName: 'home',
    );

    // Let post-frame callback run
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => financeVM.ensureFinanceForHomeSeeded()).called(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Summary cards
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders month summary (Omsætning/Aftaler) via selector', (
    tester,
  ) async {
    when(
      () => financeVM.summaryNow(Segment.month),
    ).thenReturn((income: 12345.0, count: 3));

    // We only care that the list does not show the spinner here
    when(() => apptVM.hasLoadedInitialWindow).thenReturn(true);

    await pumpWithShell(
      tester,
      child: const HomeScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/home',
      routeName: 'home',
    );

    // One extra pump is enough; summary is synchronous
    await tester.pump();

    // Summary labels
    expect(find.text('Omsætning'), findsOneWidget);
    expect(find.text('Aftaler'), findsOneWidget);
    expect(find.text('Denne måned'), findsNWidgets(2));

    // Count should be rendered as "3"
    expect(find.text('3'), findsWidgets);

    // The “Ny aftale” CTA is visible
    expect(find.text('Ny aftale'), findsOneWidget);

    // Selector invoked summaryNow(Segment.month)
    verify(() => financeVM.summaryNow(Segment.month)).called(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Upcoming list states
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('shows loading spinner when appointments not loaded yet', (
    tester,
  ) async {
    when(() => apptVM.hasLoadedInitialWindow).thenReturn(false);

    await pumpWithShell(
      tester,
      child: const HomeScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/home',
      routeName: 'home',
    );

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty state when loaded but no items', (tester) async {
    when(() => apptVM.hasLoadedInitialWindow).thenReturn(true);
    when(
      () => apptVM.cardsForRange(any(), any()),
    ).thenReturn(const <AppointmentCardModel>[]);

    await pumpWithShell(
      tester,
      child: const HomeScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/home',
      routeName: 'home',
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Ingen kommende aftaler'), findsOneWidget);
  });

  testWidgets('renders upcoming list items when loaded with data', (
    tester,
  ) async {
    when(() => apptVM.hasLoadedInitialWindow).thenReturn(true);

    final now = DateTime(2025, 1, 10, 14, 30);
    final items = <AppointmentCardModel>[
      AppointmentCardModel(
        id: 'a1',
        clientName: 'Alice',
        serviceName: 'Makeup',
        duration: '45',
        price: 250.0,
        status: 'Afventer',
        time: now,
        imageUrl: null,
      ),
      AppointmentCardModel(
        id: 'a2',
        clientName: 'Bob',
        serviceName: 'Hår',
        duration: '30',
        price: 300.0,
        status: 'Betalt',
        time: now.add(const Duration(hours: 1)),
        imageUrl: null,
      ),
    ];

    when(() => apptVM.cardsForRange(any(), any())).thenReturn(items);

    await pumpWithShell(
      tester,
      child: const HomeScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/home',
      routeName: 'home',
    );

    await tester.pump(const Duration(milliseconds: 1));

    // Two AppointmentCard widgets keyed by 'appt-<id>'
    expect(find.byKey(const ValueKey('appt-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('appt-a2')), findsOneWidget);

    // Visible text bits
    expect(find.text('Kommende aftaler'), findsOneWidget);
    expect(find.text('Se alle'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Makeup'), findsOneWidget);
    expect(find.text('Hår'), findsOneWidget);
  });

  // (We still don't tap “Ny aftale” / “Se alle” here to avoid go_router wiring.)
}
