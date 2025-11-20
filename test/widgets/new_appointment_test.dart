import 'package:aftaler_og_regnskab/domain/client_model.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/ui/appointment/new_appointment_screen.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/ui/widgets/pickers/date_picker.dart';
import 'package:aftaler_og_regnskab/ui/widgets/pickers/image/images_picker_grid.dart';
import 'package:aftaler_og_regnskab/ui/widgets/pickers/time_picker.dart';
import 'package:aftaler_og_regnskab/ui/widgets/search_field.dart';
import 'package:aftaler_og_regnskab/ui/widgets/status.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/add_client_panel.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/add_checklist_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/mocks.dart';
import '../support/test_wrappers.dart';

class MockGoRouter extends Mock implements GoRouter {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  setUpAll(() async {
    // Date formatting for 'da' used by DateFormat in the widget.
    await initializeDateFormatting('da');

    // Fallbacks for matchers
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(PaymentStatus.uninvoiced);
  });

  late MockClientVM clientVM;
  late MockServiceVM serviceVM;
  late MockChecklistVM checklistVM;
  late MockAppointmentVM apptVM;
  late MockFinanceVM financeVM;

  setUp(() {
    clientVM = MockClientVM();
    serviceVM = MockServiceVM();
    checklistVM = MockChecklistVM();
    apptVM = MockAppointmentVM();
    financeVM = MockFinanceVM();

    // Default stubs
    when(() => clientVM.initClientFilters()).thenAnswer((_) {});
    when(() => serviceVM.initServiceFilters()).thenAnswer((_) {});
    when(() => checklistVM.initChecklistFilters()).thenAnswer((_) {});
    when(() => clientVM.setClientSearch(any())).thenAnswer((_) {});
    when(() => serviceVM.setServiceSearch(any())).thenAnswer((_) {});
    when(() => checklistVM.setChecklistSearch(any())).thenAnswer((_) {});
    when(() => clientVM.clearSearch()).thenAnswer((_) {});
    when(() => serviceVM.clearSearch()).thenAnswer((_) {});
    when(() => checklistVM.clearSearch()).thenAnswer((_) {});

    when(() => clientVM.allClients).thenReturn(const <ClientModel>[]);
    when(() => serviceVM.allServices).thenReturn(const <ServiceModel>[]);
    when(() => checklistVM.allChecklists).thenReturn(const <ChecklistModel>[]);

    when(() => clientVM.saving).thenReturn(false);
    when(() => clientVM.error).thenReturn(null);
    when(() => serviceVM.saving).thenReturn(false);
    when(() => serviceVM.error).thenReturn(null);
    when(() => checklistVM.saving).thenReturn(false);
    when(() => checklistVM.error).thenReturn(null);

    when(() => apptVM.saving).thenReturn(false);
    when(() => apptVM.error).thenReturn(null);
    when(
      () => apptVM.addAppointment(
        clientId: any(named: 'clientId'),
        serviceId: any(named: 'serviceId'),
        dateTime: any(named: 'dateTime'),
        checklistIds: any(named: 'checklistIds'),
        location: any(named: 'location'),
        note: any(named: 'note'),
        price: any(named: 'price'),
        images: any(named: 'images'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => true);

    when(
      () => financeVM.onAddAppointment(
        status: any(named: 'status'),
        price: any(named: 'price'),
        dateTime: any(named: 'dateTime'),
      ),
    ).thenAnswer((_) async {});

    when(() => serviceVM.priceFor(any())).thenReturn(null);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Init behaviour
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('calls init filters on view models post-frame', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    // Let post-frame callback run
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => clientVM.initClientFilters()).called(1);
    verify(() => serviceVM.initServiceFilters()).called(1);
    verify(() => checklistVM.initChecklistFilters()).called(1);
  });

  testWidgets('calls clearSearch on view models during dispose', (
    tester,
  ) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Simulate dispose by removing the widget
    await tester.pumpWidget(const SizedBox.shrink());

    verify(() => clientVM.clearSearch()).called(1);
    verify(() => serviceVM.clearSearch()).called(1);
    verify(() => checklistVM.clearSearch()).called(1);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Rendering initial state
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders all sections and initial UI elements', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Section titles
    expect(find.text('Vælg klient'), findsOneWidget);
    expect(find.text('Vælg service'), findsOneWidget);
    expect(find.text('Tilknyt checklister'), findsOneWidget);
    expect(find.text('Vælg tidspunkt'), findsOneWidget);
    expect(find.text('Vælg lokation'), findsOneWidget);
    expect(find.text('Tilpas pris (valgfri)'), findsOneWidget);
    expect(find.text('Billeder'), findsOneWidget);
    expect(find.text('Vælg status'), findsOneWidget);
    expect(find.text('Note (valgfri)'), findsOneWidget);

    // Buttons
    expect(find.text('Tilføj ny klient'), findsOneWidget);
    expect(find.text('Tilføj ny service'), findsOneWidget);
    expect(find.text('Tilføj ny checkliste'), findsOneWidget);
    expect(find.text('Annuller'), findsOneWidget);
    expect(find.text('Opret aftale'), findsOneWidget);

    // Initial hints
    expect(find.text('Indtast pris'), findsOneWidget);
    expect(find.text('Indtast addresse'), findsOneWidget);
    expect(find.text('Tilføj note til denne aftale'), findsOneWidget);

    // No saving overlay initially
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Client selection
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders search field and add button when no client selected', (
    tester,
  ) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Search field present
    expect(find.byType(SearchField), findsNWidgets(3));
    expect(find.text('Tilføj ny klient'), findsOneWidget);

    // Tap add button shows overlay
    await tester.tap(find.text('Tilføj ny klient'));
    await tester.pumpAndSettle();

    expect(find.byType(AddClientPanel), findsOneWidget);
  });

  testWidgets('client search updates view model', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Enter search text
    await tester.enterText(find.byType(SearchField).first, 'test');
    await tester.pump();

    verify(() => clientVM.setClientSearch('test')).called(1);
  });

  testWidgets('selects client, shows undo button, hides search', (
    tester,
  ) async {
    when(
      () => clientVM.allClients,
    ).thenReturn([ClientModel(id: 'c1', name: 'Alice')]);

    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('Fotryd'), findsOneWidget);
    expect(find.byType(SearchField), findsNWidgets(2));
  });

  testWidgets('undo client selection restores search and add button', (
    tester,
  ) async {
    when(
      () => clientVM.allClients,
    ).thenReturn([ClientModel(id: 'c1', name: 'Alice')]);

    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('Fotryd'), findsOneWidget);

    await tester.tap(find.text('Fotryd'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchField), findsNWidgets(3));
    expect(find.text('Tilføj ny klient'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Service selection
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders search field and add button when no service selected', (
    tester,
  ) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Search field for service
    expect(find.byType(SearchField), findsNWidgets(3));
    expect(find.text('Tilføj ny service'), findsOneWidget);

    // Tap add button shows overlay
    await tester.tap(find.text('Tilføj ny service'));
    await tester.pumpAndSettle();

    expect(find.byType(AddServicePanel), findsOneWidget);
  });

  testWidgets('service search updates view model', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Enter search
    await tester.enterText(
      find.byType(SearchField).hitTestable().at(1),
      'service',
    );
    await tester.pump();

    verify(() => serviceVM.setServiceSearch('service')).called(1);
  });

  testWidgets('selects service, updates price hint, shows undo button', (
    tester,
  ) async {
    when(
      () => serviceVM.allServices,
    ).thenReturn([ServiceModel(id: 's1', name: 'Hair', price: 250.0)]);
    when(() => serviceVM.priceFor('s1')).thenReturn(250.0);

    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    expect(find.text('Hair'), findsOneWidget);

    await tester.tap(find.text('Hair'));
    await tester.pumpAndSettle();

    expect(find.text('Fotryd'), findsOneWidget);
    expect(find.text('250'), findsNWidgets(3));
    expect(find.byType(SearchField), findsNWidgets(2));
  });

  testWidgets(
    'undo service selection restores search and add button, clears price',
    (tester) async {
      when(
        () => serviceVM.allServices,
      ).thenReturn([ServiceModel(id: 's1', name: 'Hair', price: 250.0)]);
      when(() => serviceVM.priceFor('s1')).thenReturn(250.0);

      await pumpWithShell(
        tester,
        child: const NewAppointmentScreen(),
        providers: [
          ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
          ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
          ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
          ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
          ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
        ],
        location: '/new_appointment',
        routeName: 'new_appointment',
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Hair'));
      await tester.pumpAndSettle();

      expect(find.text('Fotryd'), findsOneWidget);

      await tester.tap(find.text('Fotryd'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchField), findsNWidgets(3));
      expect(find.text('Tilføj ny service'), findsOneWidget);
      expect(find.text('Indtast pris'), findsOneWidget);
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // Checklist attachment
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders search field and add button for checklists', (
    tester,
  ) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Search field for checklist
    expect(find.byType(SearchField), findsNWidgets(3));
    expect(find.text('Tilføj ny checkliste'), findsOneWidget);

    // Tap add button shows overlay
    await tester.tap(find.text('Tilføj ny checkliste'));
    await tester.pumpAndSettle();

    expect(find.byType(AddChecklistPanel), findsOneWidget);
  });

  testWidgets('checklist search updates view model', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Enter search
    await tester.enterText(find.byType(SearchField).last, 'check');
    await tester.pump();

    verify(() => checklistVM.setChecklistSearch('check')).called(1);
  });

  testWidgets('toggles checklists selection', (tester) async {
    when(
      () => checklistVM.allChecklists,
    ).thenReturn([ChecklistModel(id: 'ch1', name: 'Checklist1')]);

    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    expect(find.text('Checklist1'), findsOneWidget);

    await tester.tap(find.text('Checklist1'));
    await tester.pumpAndSettle();

    // Toggle back
    await tester.tap(find.text('Checklist1'));
    await tester.pumpAndSettle();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Date and time pickers
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders date and time pickers', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Find DatePicker and TimePicker
    expect(find.byType(DatePicker), findsOneWidget);
    expect(find.byType(TimePicker), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Location input
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('enters location text', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Enter text
    await tester.enterText(find.byType(SoftTextField).first, 'Test Location');
    await tester.pump();

    expect(find.text('Test Location'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Custom price
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('enters custom price', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Enter text
    await tester.enterText(
      find.byType(SoftTextField).hitTestable().at(1),
      '300',
    );
    await tester.pump();

    expect(find.text('300'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Images picker
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders images picker grid', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    expect(find.byType(ImagesPickerGrid), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Status choice
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('renders status choice', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    expect(find.byType(StatusChoice), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Note input
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('enters note text', (tester) async {
    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    // Enter text
    await tester.enterText(find.byType(SoftTextField).last, 'Test Note');
    await tester.pump();

    expect(find.text('Test Note'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Actions: Cancel and Create
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('cancel button triggers pop', (tester) async {
    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const NewAppointmentScreen(),
      ),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Annuller'));
    await tester.pumpAndSettle();

    verify(() => mockRouter.pop()).called(1);
  });

  testWidgets('create button submits successfully, shows snackbar, pops', (
    tester,
  ) async {
    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    when(
      () => apptVM.addAppointment(
        clientId: null,
        serviceId: null,
        dateTime: any(named: 'dateTime'),
        checklistIds: const [],
        location: '',
        note: '',
        price: null,
        images: const [],
        status: 'Ufaktureret',
      ),
    ).thenAnswer((_) async => true);

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const NewAppointmentScreen(),
      ),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Opret aftale'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Aftale oprettet'), findsOneWidget);

    verify(
      () => apptVM.addAppointment(
        clientId: null,
        serviceId: null,
        dateTime: any(named: 'dateTime'),
        checklistIds: const [],
        location: '',
        note: '',
        price: null,
        images: const [],
        status: 'Ufaktureret',
      ),
    ).called(1);

    verify(
      () => financeVM.onAddAppointment(
        status: PaymentStatus.uninvoiced,
        price: 0.0,
        dateTime: any(named: 'dateTime'),
      ),
    ).called(1);

    verify(() => mockRouter.pop()).called(1);
  });

  testWidgets('create button handles failure, shows error snackbar', (
    tester,
  ) async {
    final mockRouter = MockGoRouter();
    when(() => mockRouter.pop()).thenReturn(null);

    when(
      () => apptVM.addAppointment(
        clientId: null,
        serviceId: null,
        dateTime: any(named: 'dateTime'),
        checklistIds: const [],
        location: '',
        note: '',
        price: null,
        images: const [],
        status: 'Ufaktureret',
      ),
    ).thenAnswer((_) async => false);
    when(() => apptVM.error).thenReturn('Test Error');

    await pumpWithShell(
      tester,
      child: InheritedGoRouter(
        goRouter: mockRouter,
        child: const NewAppointmentScreen(),
      ),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Opret aftale'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Test Error'), findsOneWidget);

    verifyNever(
      () => financeVM.onAddAppointment(
        status: any(named: 'status'),
        price: any(named: 'price'),
        dateTime: any(named: 'dateTime'),
      ),
    );

    verifyNever(() => mockRouter.pop());
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Saving states
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('shows loading overlay when saving', (tester) async {
    when(() => apptVM.saving).thenReturn(true);

    await pumpWithShell(
      tester,
      child: const NewAppointmentScreen(),
      providers: [
        ChangeNotifierProvider<ClientViewModel>.value(value: clientVM),
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
        ChangeNotifierProvider<AppointmentViewModel>.value(value: apptVM),
        ChangeNotifierProvider<FinanceViewModel>.value(value: financeVM),
      ],
      location: '/new_appointment',
      routeName: 'new_appointment',
    );

    await tester.pump();

    final screenFinder = find.byType(NewAppointmentScreen);
    expect(
      find.descendant(
        of: screenFinder,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: screenFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ModalBarrier &&
              widget.dismissible == false &&
              widget.color == Colors.black38,
        ),
      ),
      findsOneWidget,
    );
  });
}
