import 'dart:async';

import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/domain/appointment_model.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/ui/appointment/appointment_details_screen.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/cards/appointment_checklist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../support/mocks.dart';
import '../support/test_wrappers.dart';

void main() {
  // ────────────────────────────────────────────────────────────────────────────
  // Test setup
  // ────────────────────────────────────────────────────────────────────────────
  setUpAll(() async {
    await initializeDateFormatting('da');
    // Fallbacks that are commonly needed by mocktail
    registerFallbackValue(DateTime(2000, 1, 1));
  });

  late MockAppointmentVM apptVM;
  late MockClientVM clientVM;
  late MockServiceVM serviceVM;
  late MockChecklistVM checklistVM;

  // Handy fixture
  AppointmentModel appt({
    String id = 'a1',
    String? clientId,
    String? serviceId,
    List<String> checklistIds = const [],
    DateTime? dateTime,
    DateTime? payDate,
    String? location,
    String? note,
    double? price,
    String status = 'Afventer',
    List<String> imageUrls = const [],
  }) {
    return AppointmentModel(
      id: id,
      clientId: clientId,
      serviceId: serviceId,
      checklistIds: checklistIds,
      dateTime: dateTime,
      payDate: payDate,
      location: location,
      note: note,
      price: price,
      status: status,
      imageUrls: imageUrls,
    );
  }

  setUp(() {
    apptVM = MockAppointmentVM();
    clientVM = MockClientVM();
    serviceVM = MockServiceVM();
    checklistVM = MockChecklistVM();

    // Default: appointment exists, minimal content
    when(() => apptVM.getAppointment('a1')).thenReturn(
      appt(
        dateTime: DateTime(2025, 1, 10, 10, 30),
        imageUrls: const [],
        checklistIds: const [],
      ),
    );

    // Checklist progress stream defaults to an empty progress map
    when(
      () => apptVM.checklistProgressStream(any()),
    ).thenAnswer((_) => Stream.value(<String, Set<int>>{}));

    // Saving checklist progress is a no-op by default
    when(
      () => apptVM.saveChecklistProgress(
        appointmentId: any(named: 'appointmentId'),
        progress: any(named: 'progress'),
      ),
    ).thenAnswer((_) async {});

    // Client/service/checklist prefetch are no-ops
    when(() => clientVM.prefetchClient(any())).thenAnswer((_) async {});
    when(() => serviceVM.prefetchService(any())).thenAnswer((_) async {});
    when(() => checklistVM.prefetchChecklists(any())).thenAnswer((_) async {});

    // Selections used by Selectors in the screen; default to “not loaded”
    when(() => clientVM.getClient(any())).thenReturn(null);
    when(() => serviceVM.getService(any())).thenReturn(null);
    when(() => checklistVM.getById(any())).thenReturn(null);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Null-appointment → auto-pop (renders nothing)
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('pops when appointment is missing (renders nothing)', (
    tester,
  ) async {
    // The selector will resolve to null → screen schedules a pop on next frame.
    when(() => apptVM.getAppointment('missing')).thenReturn(null);

    // Minimal, stable router for this test only.
    final router = GoRouter(
      initialLocation: '/base',
      routes: [
        GoRoute(
          path: '/base',
          builder: (_, __) => const Scaffold(body: Text('base')),
        ),
        GoRoute(
          path: '/appointments/:id',
          builder: (_, state) => AppointmentDetailsScreen(
            appointmentId: state.pathParameters['id']!,
          ),
        ),
      ],
    );

    // Pump providers + router.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
          ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
          ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
          ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Push details WITHOUT awaiting; waiting would deadlock until pop completes.
    unawaited(router.push('/appointments/missing'));

    // Let details build, schedule its post-frame pop, then run it.
    await tester.pump(); // build details
    await tester.pump(
      const Duration(milliseconds: 1),
    ); // run addPostFrameCallback(pop)
    await tester.pump(); // finish microtasks

    // We popped back to /base; details scroll view isn't in the tree.
    expect(find.text('base'), findsOneWidget);
    expect(
      find.byKey(const PageStorageKey('appointmentDetailsScroll')),
      findsNothing,
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Read pane: basic rendering and empty states
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('renders read view sections and empty states', (tester) async {
    when(() => apptVM.getAppointment('a1')).thenReturn(
      appt(
        // No client, no service, no price, no images, no checklists
        dateTime: DateTime(2025, 1, 10, 10, 0),
        note: '',
        imageUrls: const [],
        checklistIds: const [],
        price: null,
      ),
    );

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointments/a1',
      routeName: 'appointmentDetails',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    // Section headers
    expect(find.text('Status og fakturering'), findsOneWidget);
    expect(find.text('Klient'), findsOneWidget);
    expect(find.text('Aftaleoplysninger'), findsOneWidget);
    expect(find.text('Checklister'), findsOneWidget);
    expect(find.text('Billeder'), findsOneWidget);
    expect(find.text('Noter'), findsOneWidget);

    // Read-view fallbacks
    expect(find.text('Ingen klient tilknyttet'), findsOneWidget);
    expect(find.text('Ingen checklister tilknyttet'), findsOneWidget);
    expect(find.text('Ingen billeder tilføjet'), findsOneWidget);
    expect(find.text('Ingen note'), findsOneWidget);

    // Price shows placeholder when null
    expect(find.text('Pris'), findsOneWidget);
    expect(
      find.text('---'),
      findsWidgets,
    ); // multiple '---' (price/date/location)
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Prefetching related entities when IDs exist
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('prefetches client, service and checklists on init', (
    tester,
  ) async {
    when(() => apptVM.getAppointment('a1')).thenReturn(
      appt(
        clientId: 'c1',
        serviceId: 's1',
        checklistIds: const ['k1', 'k2'],
        dateTime: DateTime(2025, 1, 10, 10, 0),
      ),
    );

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointments/a1',
      routeName: 'appointmentDetails',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => clientVM.prefetchClient('c1')).called(1);
    verify(() => serviceVM.prefetchService('s1')).called(1);
    verify(() => checklistVM.prefetchChecklists(['k1', 'k2'])).called(1);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Checklist progress: toggle → "Gem ændringer" → saveChecklistProgress
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'toggling a checklist item enables "Gem ændringer" and saves progress',
    (tester) async {
      // Appointment with one checklist
      when(() => apptVM.getAppointment('a1')).thenReturn(
        appt(
          checklistIds: const ['k1'],
          dateTime: DateTime(2025, 1, 10, 10, 0),
        ),
      );

      // Checklist fully loaded by selector
      final k1 = ChecklistModel(
        id: 'k1',
        name: 'Forberedelse',
        points: const ['P1', 'P2', 'P3'],
        description: null,
      );
      when(() => checklistVM.getById('k1')).thenReturn(k1);

      // Server says item 0 is already completed
      when(() => apptVM.checklistProgressStream('a1')).thenAnswer(
        (_) => Stream<Map<String, Set<int>>>.value({
          'k1': {0},
        }),
      );

      // Capture the saved progress
      when(
        () => apptVM.saveChecklistProgress(
          appointmentId: any(named: 'appointmentId'),
          progress: any(named: 'progress'),
        ),
      ).thenAnswer((_) async {});

      await pumpWithShell(
        tester,
        child: const AppointmentDetailsScreen(appointmentId: 'a1'),
        providers: [
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
          ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
          ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
          ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ],
        location: '/appointments/a1',
        routeName: 'appointmentDetails',
      );
      await tester.pump(); // build
      await tester.pump(const Duration(milliseconds: 1)); // load ticks

      // Find the rendered checklist card
      final cardFinder = find.byType(AppointmentChecklistCard);
      expect(cardFinder, findsOneWidget);

      // Call the public callback to simulate ticking item #1
      final card = tester.widget(cardFinder) as AppointmentChecklistCard;
      expect(card.onToggleItem, isNotNull);
      card.onToggleItem!(1, true); // add item 1

      await tester.pump();

      // "Gem ændringer" button becomes visible
      final saveBtn = find.text('Gem ændringer');
      expect(saveBtn, findsOneWidget);

      await tester.tap(saveBtn);
      await tester.pump();

      // Verify the saved map now contains {0,1} for 'k1'
      final captured =
          verify(
                () => apptVM.saveChecklistProgress(
                  appointmentId: 'a1',
                  progress: captureAny(named: 'progress'),
                ),
              ).captured.single
              as Map<String, Set<int>>;

      expect(captured.containsKey('k1'), isTrue);
      expect(captured['k1'], containsAll(<int>{0, 1}));
    },
  );
}
