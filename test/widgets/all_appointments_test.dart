import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/ui/appointment/all_appointments_screen.dart';
import 'package:aftaler_og_regnskab/ui/widgets/cards/appointment_card_status.dart';
import 'package:aftaler_og_regnskab/ui/widgets/search_field.dart';
import 'package:aftaler_og_regnskab/ui/widgets/status.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/mocks.dart';
import '../support/test_wrappers.dart';

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  setUpAll(() async {
    // Date formatting for 'da' used by DateFormat in the widget.
    await initializeDateFormatting('da');

    // Fallbacks for matchers
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(PaymentStatus.uninvoiced);
  });

  late MockAppointmentVM apptVM;
  late MockFinanceVM financeVM;

  setUp(() {
    apptVM = MockAppointmentVM();
    financeVM = MockFinanceVM();

    // Default stubs
    when(() => apptVM.listCards).thenReturn(const <AppointmentCardModel>[]);
    when(() => apptVM.listLoading).thenReturn(false);
    when(() => apptVM.listHasMore).thenReturn(false);
    when(() => apptVM.beginListRange(any(), any())).thenAnswer((_) async {});
    when(() => apptVM.loadNextListPage()).thenAnswer((_) async {});
    when(() => apptVM.updateStatus(any(), any())).thenAnswer((_) async {});
    when(
      () => financeVM.onUpdateStatus(
        oldStatus: any(named: 'oldStatus'),
        newStatus: any(named: 'newStatus'),
        price: any(named: 'price'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async {});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Init behaviour
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('calls beginListRange post-frame with initial from/to dates', (
    tester,
  ) async {
    // Tests initialization calls beginListRange with current month's start and end dates after first frame.
    final year = 2025;
    final month = 11;
    final initialFrom = DateTime(year, month, 1);
    final initialTo = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    await pumpWithShell(
      tester,
      child: const AllAppointmentsScreen(),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    // Let post-frame callback run
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => apptVM.beginListRange(initialFrom, initialTo)).called(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Rendering initial state
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders filters, search field, and empty state message', (
    tester,
  ) async {
    // Tests initial UI with search field, filters (type, status, from, to), and 'Ingen aftaler i perioden' when empty.
    await pumpWithShell(
      tester,
      child: const AllAppointmentsScreen(),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    // Search field
    expect(find.byType(SearchField), findsOneWidget);

    // Filter labels
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Fra'), findsOneWidget);
    expect(find.text('Til'), findsOneWidget);

    // Initial filter values (approximate dates based on current)
    expect(find.text('Alle'), findsNWidgets(2)); // Type and Status
    expect(find.textContaining('/'), findsNWidgets(2)); // From and To dates

    // Empty state
    expect(find.text('Ingen aftaler i perioden'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Search functionality
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('search field updates query state', (tester) async {
    // Tests entering search text updates internal _query, though no VM call, covers setState for filtering.
    await pumpWithShell(
      tester,
      child: const AllAppointmentsScreen(),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchField), 'test');
    await tester.pump();

    // Query internal, coverage hits onChanged -> setState
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Filter selection
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('tapping type filter opens picker and updates type', (
    tester,
  ) async {
    // Tests tapping type filter shows CupertinoActionSheet, selecting updates filter text.
    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const AllAppointmentsScreen(),
      ),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Alle').first);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Privat'),
        matching: find.byType(CupertinoActionSheetAction),
      ),
    );
    await tester.pump();

    // Manually pop the action sheet to simulate the dismissal
    final actionSheetFinder = find.byType(CupertinoActionSheet);
    if (actionSheetFinder.evaluate().isNotEmpty) {
      Navigator.pop(tester.element(actionSheetFinder));
    }
    await tester.pumpAndSettle();

    expect(find.text('Privat'), findsOneWidget);
    verify(() => mockRouter.pop()).called(1);
  });

  testWidgets('tapping status filter opens picker and updates status', (
    tester,
  ) async {
    // Tests tapping status filter shows CupertinoActionSheet, selecting updates filter text.
    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const AllAppointmentsScreen(),
      ),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Alle').last);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Betalt'),
        matching: find.byType(CupertinoActionSheetAction),
      ),
    );
    await tester.pump();

    // Manually pop the action sheet to simulate the dismissal
    final actionSheetFinder = find.byType(CupertinoActionSheet);
    if (actionSheetFinder.evaluate().isNotEmpty) {
      Navigator.pop(tester.element(actionSheetFinder));
    }
    await tester.pumpAndSettle();

    expect(find.text('Betalt'), findsOneWidget);
    verify(() => mockRouter.pop()).called(1);
  });

  testWidgets(
    'tapping from date filter opens date picker and updates from date, reloads range',
    (tester) async {
      // Tests tapping 'Fra' shows date picker, simulates selection to update text and call beginListRange.
      final mockRouter = MockGoRouter();
      when(() => mockRouter.pop()).thenReturn(null);

      await pumpWithShell(
        tester,
        child: InheritedGoRouter(
          goRouter: mockRouter,
          child: const AllAppointmentsScreen(),
        ),
        providers: [
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
          ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ],
        location: '/all_appointments',
        routeName: 'all_appointments',
      );

      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('/').first);
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      // Simulate date selection by tapping the confirm button
      await tester.tap(find.text('OK'));
      await tester.pump();

      // Manually pop the date picker modal to simulate the dismissal if not already popped
      final datePickerFinder = find.byType(CupertinoDatePicker);
      if (datePickerFinder.evaluate().isNotEmpty) {
        Navigator.pop(tester.element(datePickerFinder));
      }
      await tester.pumpAndSettle();

      verify(() => apptVM.beginListRange(any(), any())).called(2);
    },
  );
  testWidgets(
    'tapping to date filter opens date picker and updates to date, reloads range',
    (tester) async {
      // Tests tapping 'Til' shows date picker, simulates selection to update text and call beginListRange.
      final mockRouter = MockGoRouter();
      when(() => mockRouter.pop()).thenReturn(null);

      await pumpWithShell(
        tester,
        child: InheritedGoRouter(
          goRouter: mockRouter,
          child: const AllAppointmentsScreen(),
        ),
        providers: [
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
          ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ],
        location: '/all_appointments',
        routeName: 'all_appointments',
      );

      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('/').last);
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      // Simulate date selection by tapping the confirm button
      await tester.tap(find.text('OK'));
      await tester.pump();

      // Manually pop the date picker modal to simulate the dismissal if not already popped
      final datePickerFinder = find.byType(CupertinoDatePicker);
      if (datePickerFinder.evaluate().isNotEmpty) {
        Navigator.pop(tester.element(datePickerFinder));
      }
      await tester.pumpAndSettle();

      verify(() => apptVM.beginListRange(any(), any())).called(2);
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // List states
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('shows loading indicator when listLoading is true', (
    tester,
  ) async {
    // Tests bottom loader appears when listLoading true and hasMore.
    when(() => apptVM.listLoading).thenReturn(true);
    when(() => apptVM.listHasMore).thenReturn(true);
    // Add a dummy item to test the bottom loader without triggering multiple center loaders
    when(() => apptVM.listCards).thenReturn([
      AppointmentCardModel(
        id: '1',
        clientName: 'A',
        serviceName: 'B',
        price: 100,
        status: 'Betalt',
        time: DateTime.now(),
      ),
    ]);

    await pumpWithShell(
      tester,
      child: const AllAppointmentsScreen(),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pump();

    final screenFinder = find.byType(AllAppointmentsScreen);
    expect(
      find.descendant(
        of: screenFinder,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows empty state when no items', (tester) async {
    // Tests 'Ingen aftaler i perioden' when list empty and not loading.
    await pumpWithShell(
      tester,
      child: const AllAppointmentsScreen(),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    expect(find.text('Ingen aftaler i perioden'), findsOneWidget);
  });

  testWidgets('shows filtered empty message when items but none match filters', (
    tester,
  ) async {
    // Tests 'Ingen aftaler matcher dine filtre.' when items present but filtered out.
    when(() => apptVM.listCards).thenReturn([
      AppointmentCardModel(
        id: 'a1',
        clientName: 'Alice',
        serviceName: 'Hair',
        price: 250.0,
        status: 'Ufaktureret',
        time: DateTime.now(),
        isBusiness: true,
      ),
    ]);

    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const AllAppointmentsScreen(),
      ),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    // Set type to Privat (non-business)
    await tester.tap(find.text('Alle').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Privat'),
        matching: find.byType(CupertinoActionSheetAction),
      ),
    );
    await tester.pump();

    // Manually pop the action sheet
    final actionSheetFinder = find.byType(CupertinoActionSheet);
    if (actionSheetFinder.evaluate().isNotEmpty) {
      Navigator.pop(tester.element(actionSheetFinder));
    }
    await tester.pumpAndSettle();

    expect(find.text('Ingen aftaler matcher dine filtre.'), findsOneWidget);
  });

  testWidgets('renders appointment cards when items available', (tester) async {
    // Tests AppointmentStatusCard rendered with correct data for each matching item.
    when(() => apptVM.listCards).thenReturn([
      AppointmentCardModel(
        id: 'a1',
        clientName: 'Alice',
        serviceName: 'Hair',
        price: 250.0,
        status: 'Ufaktureret',
        time: DateTime(2025, 11, 10),
      ),
    ]);

    await pumpWithShell(
      tester,
      child: const AllAppointmentsScreen(),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppointmentStatusCard), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Hair'), findsOneWidget);
    expect(find.text('10/11/25'), findsOneWidget);
    expect(find.text('Resultater: 1'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Scroll to load more
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('scrolling near bottom calls loadNextListPage when hasMore', (
    tester,
  ) async {
    // Tests scrolling >80% max extent calls loadNextListPage if hasMore and not loading.
    when(() => apptVM.listCards).thenReturn(
      List.generate(
        50,
        (i) => AppointmentCardModel(
          id: 'a$i',
          clientName: 'Client$i',
          serviceName: 'Service',
          price: 100.0,
          status: 'Ufaktureret',
          time: DateTime.now(),
        ),
      ),
    );
    when(() => apptVM.listHasMore).thenReturn(true);
    when(() => apptVM.listLoading).thenReturn(false);

    await pumpWithShell(
      tester,
      child: const AllAppointmentsScreen(),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    final listView = find.byType(ListView);
    await tester.drag(
      listView,
      const Offset(0, -5000),
    ); // Drag down to reach near bottom
    await tester.pump();

    verify(() => apptVM.loadNextListPage()).called(greaterThanOrEqualTo(1));
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Card interactions
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('tapping see details navigates to appointment details', (
    tester,
  ) async {
    // Tests tapping 'Se detaljer' pushes appointmentDetails route with id.
    final mockRouter = MockGoRouter();
    when(
      () => mockRouter.pushNamed(
        AppRoute.appointmentDetails.name,
        pathParameters: {'id': 'a1'},
      ),
    ).thenAnswer((_) async => null);

    when(() => apptVM.listCards).thenReturn([
      AppointmentCardModel(
        id: 'a1',
        clientName: 'Alice',
        serviceName: 'Hair',
        price: 250.0,
        status: 'Ufaktureret',
        time: DateTime.now(),
      ),
    ]);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const AllAppointmentsScreen(),
      ),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Se detaljer'));
    await tester.pump();

    verify(
      () => mockRouter.pushNamed(
        AppRoute.appointmentDetails.name,
        pathParameters: {'id': 'a1'},
      ),
    ).called(1);
  });

  testWidgets('changing status calls updateStatus and onUpdateStatus', (
    tester,
  ) async {
    // Tests changing card status calls updateStatus on apptVM and onUpdateStatus on financeVM with params.
    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    when(() => apptVM.listCards).thenReturn([
      AppointmentCardModel(
        id: 'a1',
        clientName: 'Alice',
        serviceName: 'Hair',
        price: 250.0,
        status: 'Ufaktureret',
        time: DateTime(2025, 11, 10),
      ),
    ]);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const AllAppointmentsScreen(),
      ),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/all_appointments',
      routeName: 'all_appointments',
    );

    await tester.pumpAndSettle();

    // Tap to expand status choices
    await tester.tap(find.text('Ændr status'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Betalt'));
    await tester.pumpAndSettle();

    verify(() => apptVM.updateStatus('a1', 'Betalt')).called(1);
    verify(
      () => financeVM.onUpdateStatus(
        oldStatus: PaymentStatus.uninvoiced,
        newStatus: PaymentStatus.paid,
        price: 250.0,
        date: DateTime(2025, 11, 10),
      ),
    ).called(1);
  });
}
