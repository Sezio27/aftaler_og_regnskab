// test/widgets/finance_screen_test.dart
import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/ui/finance_screen.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
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

    // Fallbacks for mocktail
    registerFallbackValue(Segment.month);
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(PaymentStatus.paid);
  });

  late MockFinanceVM financeVM;
  late MockAppointmentVM apptVM;

  setUp(() {
    financeVM = MockFinanceVM();
    apptVM = MockAppointmentVM();

    when(() => financeVM.ensureFinanceTotalsSeeded()).thenAnswer((_) async {});

    // Default summaries per segment
    when(
      () => financeVM.summaryNow(Segment.month),
    ).thenReturn((income: 111.0, count: 1));
    when(
      () => financeVM.summaryNow(Segment.year),
    ).thenReturn((income: 222.0, count: 2));
    when(
      () => financeVM.summaryNow(Segment.total),
    ).thenReturn((income: 333.0, count: 3));

    // Default status per segment
    final status = (paid: 1, waiting: 2, missing: 3, uninvoiced: 4);
    when(() => financeVM.statusNow(Segment.month)).thenReturn(status);
    when(() => financeVM.statusNow(Segment.year)).thenReturn(status);
    when(() => financeVM.statusNow(Segment.total)).thenReturn(status);
    // 🔹 Stub onUpdateStatus so it returns a Future<void>
    when(
      () => financeVM.onUpdateStatus(
        oldStatus: any(named: 'oldStatus'),
        newStatus: any(named: 'newStatus'),
        price: any(named: 'price'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async {});
    // Default recent list: empty
    when(
      () => apptVM.cardsForRange(any(), any()),
    ).thenReturn(const <AppointmentCardModel>[]);

    // New updateStatus signature: (id, newStatus)
    when(() => apptVM.updateStatus(any(), any())).thenAnswer((_) async {});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Init behaviour
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('calls ensureFinanceTotalsSeeded on first frame', (tester) async {
    await pumpWithShell(
      tester,
      child: const FinanceScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/finance',
      routeName: 'finance',
    );

    await tester.pump(const Duration(milliseconds: 1));

    verify(() => financeVM.ensureFinanceTotalsSeeded()).called(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Segmented control & summaries
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('shows segmented control and switches between tabs', (
    tester,
  ) async {
    await pumpWithShell(
      tester,
      child: const FinanceScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/finance',
      routeName: 'finance',
    );

    await tester.pump(const Duration(milliseconds: 1));

    // Segmented control labels
    expect(find.text('Måned'), findsOneWidget);
    expect(find.text('År'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    // Month is default
    expect(find.byKey(const ValueKey('sum-1-111')), findsOneWidget);

    await tester.tap(find.text('År'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sum-2-222')), findsOneWidget);
    verify(() => financeVM.summaryNow(Segment.year)).called(1);

    await tester.tap(find.text('Total'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sum-3-333')), findsOneWidget);
    verify(() => financeVM.summaryNow(Segment.total)).called(1);
  });

  testWidgets('renders summary cards and status counts', (tester) async {
    await pumpWithShell(
      tester,
      child: const FinanceScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/finance',
      routeName: 'finance',
    );

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Omsætning'), findsOneWidget);
    expect(find.text('Aftaler'), findsOneWidget);

    expect(find.text('Betalt'), findsOneWidget);
    expect(find.text('Afventer'), findsOneWidget);
    expect(find.text('Forfalden'), findsOneWidget);
    expect(find.text('Ufaktureret'), findsOneWidget);

    // Numbers from our stubbed status
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('4'), findsWidgets);

    verify(() => financeVM.summaryNow(Segment.month)).called(1);
    verify(() => financeVM.statusNow(Segment.month)).called(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Recent list states
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('shows empty recent list when no items', (tester) async {
    when(
      () => apptVM.cardsForRange(any(), any()),
    ).thenReturn(const <AppointmentCardModel>[]);

    await pumpWithShell(
      tester,
      child: const FinanceScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/finance',
      routeName: 'finance',
    );

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Seneste aftaler'), findsOneWidget);
    expect(find.text('Ingen kommende aftaler'), findsOneWidget);
    expect(find.text('Se alle'), findsOneWidget);
  });

  testWidgets('renders recent list items', (tester) async {
    final now = DateTime(2025, 1, 10, 14, 30);
    final items = <AppointmentCardModel>[
      AppointmentCardModel(
        id: 'r1',
        clientName: 'Anna',
        serviceName: 'Makeup',
        duration: '45',
        price: 50.0,
        status: 'Afventer',
        time: now,
        imageUrl: null,
      ),
      AppointmentCardModel(
        id: 'r2',
        clientName: 'Bo',
        serviceName: 'Hår',
        duration: '30',
        price: 75.0,
        status: 'Betalt',
        time: now.add(const Duration(hours: 1)),
        imageUrl: null,
      ),
    ];
    when(() => apptVM.cardsForRange(any(), any())).thenReturn(items);

    await pumpWithShell(
      tester,
      child: const FinanceScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/finance',
      routeName: 'finance',
    );

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(const ValueKey('appt-r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('appt-r2')), findsOneWidget);

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('Makeup'), findsOneWidget);
    expect(find.text('Hår'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Status change callback → updateStatus + FinanceViewModel.onUpdateStatus
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets(
    'changing status calls updateStatus and onUpdateStatus when status changes',
    (tester) async {
      final now = DateTime(2025, 6, 1, 10, 0);
      final row = AppointmentCardModel(
        id: 'x1',
        clientName: 'Carla',
        serviceName: 'Vipper',
        duration: '30',
        price: 100.0,
        status: 'Afventer', // current
        time: now,
        imageUrl: null,
      );
      when(() => apptVM.cardsForRange(any(), any())).thenReturn([row]);

      await pumpWithShell(
        tester,
        child: const FinanceScreen(),
        providers: [
          ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ],
        location: '/finance',
        routeName: 'finance',
      );

      await tester.pump(const Duration(milliseconds: 1));

      // Pull the rendered card and invoke the public callback directly
      final widgetObj = tester.widget(find.byKey(const ValueKey('appt-x1')));
      final card = widgetObj as dynamic; // AppointmentStatusCard
      final void Function(PaymentStatus) onChange =
          card.onChangeStatus as void Function(PaymentStatus);

      onChange(PaymentStatus.paid); // Afventer -> Betalt
      await tester.pump();

      // Appointment status updated with new label
      verify(
        () => apptVM.updateStatus('x1', PaymentStatus.paid.label),
      ).called(1);

      // Finance VM notified with old/new status, price and date
      verify(
        () => financeVM.onUpdateStatus(
          oldStatus: PaymentStatus.waiting,
          newStatus: PaymentStatus.paid,
          price: 100.0,
          date: now,
        ),
      ).called(1);
    },
  );

  testWidgets('no update when status stays the same', (tester) async {
    final now = DateTime(2025, 6, 1, 10, 0);
    final row = AppointmentCardModel(
      id: 'x2',
      clientName: 'Dina',
      serviceName: 'Bryn',
      duration: '30',
      price: 90.0,
      status: 'Betalt', // already paid
      time: now,
      imageUrl: null,
    );
    when(() => apptVM.cardsForRange(any(), any())).thenReturn([row]);

    await pumpWithShell(
      tester,
      child: const FinanceScreen(),
      providers: [
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
      ],
      location: '/finance',
      routeName: 'finance',
    );

    await tester.pump(const Duration(milliseconds: 1));

    final widgetObj = tester.widget(find.byKey(const ValueKey('appt-x2')));
    final card = widgetObj as dynamic;
    final void Function(PaymentStatus) onChange =
        card.onChangeStatus as void Function(PaymentStatus);

    // Same status: callback should early-return inside the widget.
    onChange(PaymentStatus.paid);
    await tester.pump();

    verifyNever(() => apptVM.updateStatus(any(), any()));
    verifyNever(
      () => financeVM.onUpdateStatus(
        oldStatus: any(named: 'oldStatus'),
        newStatus: any(named: 'newStatus'),
        price: any(named: 'price'),
        date: any(named: 'date'),
      ),
    );
  });
}
