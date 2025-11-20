import 'package:aftaler_og_regnskab/domain/appointment_model.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/domain/client_model.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/ui/appointment/appointment_details_screen.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/client_list_overlay.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/ui/widgets/status.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart';
import 'package:provider/provider.dart';

import '../support/mocks.dart';
import '../support/test_wrappers.dart';

class MockGoRouter extends Mock implements GoRouter {}

class FakeAppointmentModel extends Fake implements AppointmentModel {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAppointmentModel());
  });

  late MockAppointmentVM apptVM;
  late MockFinanceVM financeVM;
  late MockClientVM clientVM;
  late MockServiceVM serviceVM;
  late MockChecklistVM checklistVM;

  setUp(() {
    apptVM = MockAppointmentVM();
    financeVM = MockFinanceVM();
    clientVM = MockClientVM();
    serviceVM = MockServiceVM();
    checklistVM = MockChecklistVM();

    registerFallbackValue(PaymentStatus.uninvoiced);
    registerFallbackValue(DateTime(2000));

    // Default stubs
    when(() => apptVM.getAppointment(any())).thenReturn(null);
    when(
      () => apptVM.updateAppointmentFields(
        any(),
        clientId: any(named: 'clientId'),
        serviceId: any(named: 'serviceId'),
        checklistIds: any(named: 'checklistIds'),
        dateTime: any(named: 'dateTime'),
        payDate: any(named: 'payDate'),
        location: any(named: 'location'),
        note: any(named: 'note'),
        price: any(named: 'price'),
        status: any(named: 'status'),
        currentImageUrls: any(named: 'currentImageUrls'),
        removedImageUrls: any(named: 'removedImageUrls'),
        newImages: any(named: 'newImages'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => apptVM.delete(any(), any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => apptVM.checklistProgressStream(any()),
    ).thenAnswer((_) => Stream.value({}));
    when(
      () => apptVM.saveChecklistProgress(
        appointmentId: any(named: 'appointmentId'),
        progress: any(named: 'progress'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => financeVM.onUpdateAppointmentFields(
        oldStatus: any(named: 'oldStatus'),
        newStatus: any(named: 'newStatus'),
        oldPrice: any(named: 'oldPrice'),
        newPrice: any(named: 'newPrice'),
        oldDate: any(named: 'oldDate'),
        newDate: any(named: 'newDate'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => financeVM.onDeleteAppointment(
        date: any(named: 'date'),
        price: any(named: 'price'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async {});
    when(() => clientVM.getClient(any())).thenReturn(null);
    when(() => clientVM.prefetchClient(any())).thenAnswer((_) async {});
    when(() => serviceVM.getService(any())).thenReturn(null);
    when(() => serviceVM.prefetchService(any())).thenAnswer((_) async {});
    when(() => checklistVM.getChecklist(any())).thenReturn(null);
    when(() => checklistVM.prefetchChecklists(any())).thenAnswer((_) async {});
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Initial loading
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('pops if appointment is null', (tester) async {
    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: AppointmentDetailsScreen(appointmentId: 'invalid'),
      ),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/invalid',
      routeName: 'appointment_details',
    );

    await tester.pump();

    verify(() => mockRouter.pop()).called(1);
  });

  testWidgets('renders read pane if appointment exists', (tester) async {
    final appt = AppointmentModel(id: 'a1', status: 'Ufaktureret');
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    expect(find.text('Status og fakturering'), findsOneWidget);
    expect(find.text('Klient'), findsOneWidget);
    expect(find.text('Aftaleoplysninger'), findsOneWidget);
    expect(find.text('Checklister'), findsOneWidget);
    expect(find.text('Billeder'), findsOneWidget);
    expect(find.text('Noter'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Read pane rendering
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders status, pay date, price in read pane', (tester) async {
    final appt = AppointmentModel(
      id: 'a1',
      status: 'Betalt',
      payDate: DateTime(2025, 11, 20),
      price: 500.0,
    );
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    expect(find.text('Betalt'), findsOneWidget);
    expect(find.text('Torsdag den 20. November'), findsOneWidget);
    expect(find.text('500.0 DKK'), findsOneWidget);
  });

  testWidgets('renders client tile if client exists', (tester) async {
    final appt = AppointmentModel(
      id: 'a1',
      clientId: 'c1',
      status: 'Ufaktureret',
    );
    final client = ClientModel(id: 'c1', name: 'Test Client');
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    when(() => clientVM.getClient('c1')).thenReturn(client);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Client'), findsOneWidget);
  });

  testWidgets('renders date, time, location, cvr, service in read pane', (
    tester,
  ) async {
    final appt = AppointmentModel(
      id: 'a1',
      dateTime: DateTime(2025, 11, 20, 14, 30),
      location: 'Office',
      clientId: 'c1',
      serviceId: 's1',
      status: 'Ufaktureret',
    );
    final client = ClientModel(id: 'c1', cvr: '12345678');
    final service = ServiceModel(id: 's1', name: 'Test Service');
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    when(() => clientVM.getClient('c1')).thenReturn(client);
    when(() => serviceVM.getService('s1')).thenReturn(service);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    expect(find.text('Torsdag den 20. November'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
    expect(find.text('Test Service'), findsOneWidget);
  });

  testWidgets('renders checklists with ticks in read pane', (tester) async {
    final appt = AppointmentModel(
      id: 'a1',
      checklistIds: ['cl1'],
      status: 'Ufaktureret',
    );
    final checklist = ChecklistModel(
      id: 'cl1',
      name: 'Test Checklist',
      points: ['Item1', 'Item2'],
    );
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    when(() => checklistVM.getChecklist('cl1')).thenReturn(checklist);
    when(() => apptVM.checklistProgressStream('a1')).thenAnswer(
      (_) => Stream.value({
        'cl1': {0},
      }),
    );

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Checklist'), findsOneWidget);
    // Assume checkbox for Item1 is checked
  });

  testWidgets('toggles and saves checklist ticks in read pane', (tester) async {
    final appt = AppointmentModel(
      id: 'a1',
      checklistIds: ['cl1'],
      status: 'Ufaktureret',
    );
    final checklist = ChecklistModel(id: 'cl1', name: 'Test', points: ['Item']);
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    when(() => checklistVM.getChecklist('cl1')).thenReturn(checklist);
    when(
      () => apptVM.checklistProgressStream('a1'),
    ).thenAnswer((_) => Stream.value({}));
    when(
      () => apptVM.saveChecklistProgress(
        appointmentId: 'a1',
        progress: {
          'cl1': {0},
        },
      ),
    ).thenAnswer((_) async {});

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Åbn'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Item'));
    await tester.pumpAndSettle();

    expect(find.text('Gem ændringer'), findsOneWidget);

    await tester.tap(find.text('Gem ændringer'));
    await tester.pumpAndSettle();

    verify(
      () => apptVM.saveChecklistProgress(
        appointmentId: 'a1',
        progress: {
          'cl1': {0},
        },
      ),
    ).called(1);
  });

  testWidgets('renders images in read pane', (tester) async {
    await mockNetworkImages(() async {
      final appt = AppointmentModel(
        id: 'a1',
        imageUrls: ['https://example.com/image.jpg'],
        status: 'Ufaktureret',
      );
      when(() => apptVM.getAppointment('a1')).thenReturn(appt);

      await pumpWithShell(
        tester,
        child: const AppointmentDetailsScreen(appointmentId: 'a1'),
        providers: [
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
          ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
          ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
          ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
          ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ],
        location: '/appointment_details/a1',
        routeName: 'appointment_details',
      );

      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });
  });

  testWidgets('renders note in read pane', (tester) async {
    final appt = AppointmentModel(
      id: 'a1',
      note: 'Test note',
      status: 'Ufaktureret',
    );
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    expect(find.text('Test note'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Read pane interactions
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('tapping edit switches to edit pane', (tester) async {
    final appt = AppointmentModel(id: 'a1', status: 'Ufaktureret');
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    when(() => apptVM.saving).thenReturn(false);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Rediger'));
    await tester.pumpAndSettle();

    expect(
      find.byType(SoftTextField),
      findsNWidgets(3),
    ); // Price, location, note
  });

  testWidgets('tapping delete shows confirmation and deletes', (tester) async {
    final appt = AppointmentModel(
      id: 'a1',
      status: 'Ufaktureret',
      price: 100.0,
      dateTime: DateTime.now(),
    );

    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    // (optional but nice) stub checklist stream to something harmless:
    when(
      () => apptVM.checklistProgressStream('a1'),
    ).thenAnswer((_) => Stream.value(<String, Set<int>>{}));

    await pumpWithShell(
      tester,
      // no need for InheritedGoRouter here anymore
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    // 1) Tap the "Slet" button in the read pane
    await tester.tap(find.text('Slet'));
    await tester.pumpAndSettle();

    // 2) Tap the confirm "Slet" button in the dialog (a TextButton)
    final confirmFinder = find.widgetWithText(TextButton, 'Slet');
    expect(confirmFinder, findsOneWidget);

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    // 3) Verify calls
    verify(() => apptVM.delete('a1', 'Ufaktureret', 100.0, any())).called(1);
    verify(
      () => financeVM.onDeleteAppointment(
        date: any(named: 'date'),
        price: 100.0,
        status: PaymentStatus.uninvoiced,
      ),
    ).called(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Edit pane rendering and interactions
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders edit fields and switches back on cancel', (
    tester,
  ) async {
    final appt = AppointmentModel(id: 'a1', status: 'Ufaktureret');

    // When details screen asks for the appointment, return our model
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);

    // Selector<AppointmentViewModel, bool> expects a non-null bool
    when(() => apptVM.saving).thenReturn(false);

    // _AppointmentReadPane._loadTicks() awaits .first on this stream
    when(
      () => apptVM.checklistProgressStream('a1'),
    ).thenAnswer((_) => Stream.value(<String, Set<int>>{}));

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    // Switch to edit mode
    await tester.tap(find.text('Rediger'));
    await tester.pumpAndSettle();

    // Edit pane fields
    expect(find.text('Tilføj klient'), findsOneWidget);
    expect(find.text('Tilføj service'), findsOneWidget);
    expect(find.text('Tilføj checkliste'), findsOneWidget);
    expect(find.text('Tilføj billeder'), findsOneWidget);

    // Cancel edit → back to read view
    await tester.tap(find.text('Annuller'));
    await tester.pumpAndSettle();

    expect(find.text('Rediger'), findsOneWidget);
  });

  testWidgets('picks client in edit pane', (tester) async {
    final appt = AppointmentModel(id: 'a1', status: 'Ufaktureret');

    // Appointment lookup
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);

    // Selector<AppointmentViewModel, bool> expects a non-null bool
    when(() => apptVM.saving).thenReturn(false);

    // _AppointmentReadPane._loadTicks() awaits .first on this stream
    when(
      () => apptVM.checklistProgressStream('a1'),
    ).thenAnswer((_) => Stream.value(<String, Set<int>>{}));

    // (Optional, but keeps the overlay happy if it reads clients)
    when(() => clientVM.allClients).thenReturn(const <ClientModel>[]);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    // Enter edit mode
    await tester.tap(find.text('Rediger'));
    await tester.pumpAndSettle();

    // Open client picker overlay
    await tester.tap(find.text('Tilføj klient'));
    await tester.pumpAndSettle();

    // Overlay should be visible
    expect(find.byType(ClientListOverlay), findsOneWidget);
  });

  testWidgets('changes status in edit pane', (tester) async {
    final appt = AppointmentModel(id: 'a1', status: 'Ufaktureret');

    // Basic stubs used by AppointmentDetailsScreen
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    when(() => apptVM.saving).thenReturn(false);
    when(
      () => apptVM.checklistProgressStream('a1'),
    ).thenAnswer((_) => Stream.value(<String, Set<int>>{}));

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    // Go to edit mode
    await tester.tap(find.text('Rediger'));
    await tester.pumpAndSettle();

    // Open status choices
    await tester.tap(find.byType(StatusIconRect));
    await tester.pumpAndSettle();

    // Pick "Betalt"
    await tester.tap(find.text('Betalt'));
    await tester.pumpAndSettle();

    // New status should now be visible
    expect(find.text('Betalt'), findsOneWidget);
  });

  testWidgets('saves changes in edit pane with validation', (tester) async {
    final appt = AppointmentModel(
      id: 'a1',
      clientId: 'c1',
      status: 'Ufaktureret',
    );
    final client = ClientModel(id: 'c1');

    // Appointment + client lookup
    when(() => apptVM.getAppointment('a1')).thenReturn(appt);
    when(() => clientVM.getClient('c1')).thenReturn(client);

    // Selector<AppointmentViewModel, bool> needs a non-null bool
    when(() => apptVM.saving).thenReturn(false);

    // Read pane init: _loadTicks() waits on .first
    when(
      () => apptVM.checklistProgressStream('a1'),
    ).thenAnswer((_) => Stream.value(<String, Set<int>>{}));

    // Saving from edit pane must succeed
    when(
      () => apptVM.updateAppointmentFields(
        any(), // old appointment
        clientId: any(named: 'clientId'),
        serviceId: any(named: 'serviceId'),
        checklistIds: any(named: 'checklistIds'),
        dateTime: any(named: 'dateTime'),
        payDate: any(named: 'payDate'),
        location: any(named: 'location'),
        note: any(named: 'note'),
        price: any(named: 'price'),
        status: any(named: 'status'),
        currentImageUrls: any(named: 'currentImageUrls'),
        removedImageUrls: any(named: 'removedImageUrls'),
        newImages: any(named: 'newImages'),
      ),
    ).thenAnswer((_) async => true);

    // Finance handler (called after a successful update)
    when(
      () => financeVM.onUpdateAppointmentFields(
        oldStatus: any(named: 'oldStatus'),
        newStatus: any(named: 'newStatus'),
        oldPrice: any(named: 'oldPrice'),
        newPrice: any(named: 'newPrice'),
        oldDate: any(named: 'oldDate'),
        newDate: any(named: 'newDate'),
      ),
    ).thenAnswer((_) async {});

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    // Go to edit mode
    await tester.tap(find.text('Rediger'));
    await tester.pumpAndSettle();

    // Enter price in the first SoftTextField (the price field)
    await tester.enterText(find.byType(SoftTextField).first, '600');
    await tester.pump();

    // Tap confirm button ("Bekræft" in EditActionsRow)
    await tester.tap(find.text('Bekræft'));
    await tester.pumpAndSettle();

    // Verify the VM update call
    verify(
      () => apptVM.updateAppointmentFields(
        any(), // old appointment
        clientId: 'c1',
        serviceId: null,
        checklistIds: [],
        dateTime: null,
        payDate: null,
        location: '',
        note: '',
        price: 600.0,
        status: 'Ufaktureret',
        currentImageUrls: [],
        removedImageUrls: [],
        newImages: [],
      ),
    ).called(1);

    // And the finance update call
    verify(
      () => financeVM.onUpdateAppointmentFields(
        oldStatus: any(named: 'oldStatus'),
        newStatus: any(named: 'newStatus'),
        oldPrice: 0.0,
        newPrice: 600.0,
        oldDate: null,
        newDate: null,
      ),
    ).called(1);
  });

  testWidgets('shows snackbar if no client on save', (tester) async {
    final appt = AppointmentModel(id: 'a1', status: 'Ufaktureret');

    when(() => apptVM.getAppointment('a1')).thenReturn(appt);

    // Again: selector + checklist stream stubs
    when(() => apptVM.saving).thenReturn(false);
    when(
      () => apptVM.checklistProgressStream('a1'),
    ).thenAnswer((_) => Stream.value(<String, Set<int>>{}));

    // (Optional) stub update; it should NOT be called because validation fails,
    // but stubbing doesn't hurt:
    when(
      () => apptVM.updateAppointmentFields(
        any(),
        clientId: any(named: 'clientId'),
        serviceId: any(named: 'serviceId'),
        checklistIds: any(named: 'checklistIds'),
        dateTime: any(named: 'dateTime'),
        payDate: any(named: 'payDate'),
        location: any(named: 'location'),
        note: any(named: 'note'),
        price: any(named: 'price'),
        status: any(named: 'status'),
        currentImageUrls: any(named: 'currentImageUrls'),
        removedImageUrls: any(named: 'removedImageUrls'),
        newImages: any(named: 'newImages'),
      ),
    ).thenAnswer((_) async => true);

    await pumpWithShell(
      tester,
      child: const AppointmentDetailsScreen(appointmentId: 'a1'),
      providers: [
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/appointment_details/a1',
      routeName: 'appointment_details',
    );

    await tester.pumpAndSettle();

    // Go to edit mode
    await tester.tap(find.text('Rediger'));
    await tester.pumpAndSettle();

    // Try to save without a client
    await tester.tap(find.text('Bekræft'));
    await tester.pumpAndSettle();

    // Validation snackbars: we specifically look for the user-facing one
    expect(find.text('Vælg en kunde, før du gemmer.'), findsOneWidget);
  });
}
