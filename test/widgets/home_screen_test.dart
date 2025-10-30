/* // test/widgets/home_screen_test.dart
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/screens/home_screen.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 👈 add
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart'; // 👈 add
import 'package:intl/date_symbol_data_local.dart'; // 👈 add
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _MockAppointmentViewModel extends Mock
    with ChangeNotifier
    implements AppointmentViewModel {}

Widget _app(Widget child, AppointmentViewModel vm) {
  return ChangeNotifierProvider<AppointmentViewModel>.value(
    value: vm,
    child: MaterialApp(
      // 👇 give the app Danish locale + delegates so MaterialLocalizations works
      locale: const Locale('da'),
      supportedLocales: const [Locale('da'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Intl.defaultLocale = 'da'; // 👈 set default
    await initializeDateFormatting('da'); // 👈 init Intl for Danish
    registerFallbackValue(DateTime(2024));
  });

  testWidgets('renders summary, create button, and upcoming appointment', (
    tester,
  ) async {
    final vm = _MockAppointmentViewModel();

    when(() => vm.ensureFinanceForHomeSeeded()).thenAnswer((_) async {});
    when(
      () => vm.summaryNow(Segment.month),
    ).thenReturn((income: 1550.0, count: 3));
    when(() => vm.isReady).thenReturn(true);
    when(() => vm.cardsForRange(any<DateTime>(), any<DateTime>())).thenReturn([
      AppointmentCardModel(
        id: '1',
        clientName: 'Ada Lovelace',
        serviceName: 'Cut & style',
        time: DateTime(2024, 1, 1, 10, 0),
        price: 450,
        status: 'Betalt',
      ),
    ]);

    await tester.pumpWidget(_app(const HomeScreen(), vm));
    await tester.pumpAndSettle(); // let post-frame & list build

    verify(() => vm.ensureFinanceForHomeSeeded()).called(1);
    expect(find.text('Omsætning'), findsOneWidget);
    expect(find.text('Ny aftale'), findsOneWidget);
    expect(find.text('Kommende aftaler'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget); // now found ✅
  });

  testWidgets('shows loading indicator while appointments are seeding', (
    tester,
  ) async {
    final vm = _MockAppointmentViewModel();

    when(() => vm.ensureFinanceForHomeSeeded()).thenAnswer((_) async {});
    when(
      () => vm.summaryNow(Segment.month),
    ).thenReturn((income: 0.0, count: 0));
    when(() => vm.isReady).thenReturn(false);
    when(
      () => vm.cardsForRange(any<DateTime>(), any<DateTime>()),
    ).thenReturn(const []);

    await tester.pumpWidget(_app(const HomeScreen(), vm));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
 */
