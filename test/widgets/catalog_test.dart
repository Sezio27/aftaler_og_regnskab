// test/widgets/catalog_screen_test.dart
import 'package:aftaler_og_regnskab/ui/catalog/catalog_screen.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/search_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../support/mocks.dart';
import '../support/test_wrappers.dart'; // pumpWithShell + setTestViewSize

void main() {
  late MockServiceVM serviceVM;
  late MockChecklistVM checklistVM;

  setUpAll(() {
    // No special mocktail fallbacks needed here.
  });

  setUp(() {
    serviceVM = MockServiceVM();
    checklistVM = MockChecklistVM();

    // Default model data
    final services = <ServiceModel>[
      ServiceModel(id: 's1', name: 'Makeup', price: 500.0, image: ''),
      ServiceModel(id: 's2', name: 'Hår', price: 300.0, image: null),
    ];
    final checklists = <ChecklistModel>[
      ChecklistModel(
        id: 'c1',
        name: 'Bryllup',
        description: 'Stor dag',
        points: const ['Basispunkter'],
      ),
      ChecklistModel(
        id: 'c2',
        name: 'Fotoshoot',
        description: 'Lys & look',
        points: const ['Kamera', 'Lys'],
      ),
    ];

    when(() => serviceVM.saving).thenReturn(false);
    when(() => serviceVM.error).thenReturn(null);

    when(() => checklistVM.saving).thenReturn(false);
    when(() => checklistVM.error).thenReturn(null);

    when(() => serviceVM.allServices).thenReturn(services);
    when(() => checklistVM.allChecklists).thenReturn(checklists);

    when(() => serviceVM.initServiceFilters()).thenAnswer((_) {});
    when(() => checklistVM.initChecklistFilters()).thenAnswer((_) {});
    when(() => serviceVM.setServiceSearch(any())).thenAnswer((_) {});
    when(() => checklistVM.setChecklistSearch(any())).thenAnswer((_) {});
  });

  Future<void> _pump(WidgetTester tester) async {
    await pumpWithShell(
      tester,
      child: const CatalogScreen(),
      providers: [
        ChangeNotifierProvider<ServiceViewModel>.value(value: serviceVM),
        ChangeNotifierProvider<ChecklistViewModel>.value(value: checklistVM),
      ],
      location: '/catalog',
      routeName: 'catalog',
      width: 1280,
      height: 2856,
      devicePixelRatio: 1.0,
    );
  }

  testWidgets('initializes filters on first frame', (tester) async {
    await _pump(tester);
    // Allow post-frame callback in initState to run
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => serviceVM.initServiceFilters()).called(1);
    verify(() => checklistVM.initChecklistFilters()).called(1);
  });

  testWidgets('renders Services tab by default with a grid of services', (
    tester,
  ) async {
    await _pump(tester);

    final seg = find.byType(CupertinoSlidingSegmentedControl<Tabs>);
    expect(seg, findsOneWidget);
    expect(
      find.descendant(of: seg, matching: find.text('Services')),
      findsWidgets,
    );
    expect(
      find.descendant(of: seg, matching: find.text('Checklister')),
      findsWidgets,
    );

    // Service items are visible
    expect(find.text('Makeup'), findsOneWidget);
    expect(find.text('Hår'), findsOneWidget);

    // GridView present (services body)
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('switching to Checklister shows a list of checklists', (
    tester,
  ) async {
    await _pump(tester);

    // Switch tab
    await tester.tap(find.text('Checklister'));
    await tester.pumpAndSettle();

    // Checklist items visible
    expect(find.text('Bryllup'), findsOneWidget);
    expect(find.text('Fotoshoot'), findsOneWidget);

    // ListView present (checklists body)
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('search forwards query to the correct VM per tab', (
    tester,
  ) async {
    await _pump(tester);

    // On Services tab by default → should call setServiceSearch
    final searchField = find.byType(SearchField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'mak');
    await tester.pump();
    verify(() => serviceVM.setServiceSearch('mak')).called(1);

    // Switch to Checklists tab
    await tester.tap(find.text('Checklister'));
    await tester.pumpAndSettle();

    // After switching, SearchField is still the same widget; typing now
    // should call setChecklistSearch.
    await tester.enterText(searchField, 'bryl');
    await tester.pump();
    verify(() => checklistVM.setChecklistSearch('bryl')).called(1);
  });

  testWidgets('FAB is present and wired (does not throw on press)', (
    tester,
  ) async {
    await _pump(tester);

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    // Just ensure tapping it does not throw; overlay content is tested elsewhere.
    await tester.tap(fab);
    await tester.pump();
  });
}
