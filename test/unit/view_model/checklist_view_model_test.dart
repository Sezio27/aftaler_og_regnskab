import 'dart:async';

import 'package:aftaler_og_regnskab/data/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/data/checklist_repository.dart';
import 'package:aftaler_og_regnskab/model/checklist_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test doubles
// ─────────────────────────────────────────────────────────────────────────────

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class _FakeFetchRepo extends Fake implements ChecklistRepository {
  _FakeFetchRepo([Map<String, ChecklistModel?>? seed]) : _store = {...?seed};
  final Map<String, ChecklistModel?> _store;

  @override
  Future<Map<String, ChecklistModel?>> getChecklists(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }

  Future<ChecklistModel?> getChecklistOnce(String id) async => _store[id];
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(const ChecklistModel());
  });

  late MockChecklistRepository repo;
  late ChecklistCache cache;
  late ChecklistViewModel vm;

  setUp(() {
    repo = MockChecklistRepository();
    cache = ChecklistCache(_FakeFetchRepo());
    vm = ChecklistViewModel(repo, cache);

    // Default: avoid "Null is not a subtype of Stream<List<ChecklistModel>>"
    when(
      () => repo.watchChecklists(),
    ).thenAnswer((_) => const Stream<List<ChecklistModel>>.empty());
  });

  tearDown(() {
    vm.dispose();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // init / filtering
  // ───────────────────────────────────────────────────────────────────────────
  group('initChecklistFilters & filtering', () {
    test(
      'subscribes once, caches, filters by name/description; clearSearch resets',
      () async {
        final items = <ChecklistModel>[
          const ChecklistModel(
            id: 'a',
            name: 'Wedding',
            description: 'Bridal prep',
            points: ['x'],
          ),
          const ChecklistModel(
            id: 'b',
            name: 'Photoshoot',
            description: 'Camera ready',
            points: ['y'],
          ),
          const ChecklistModel(
            id: 'c',
            name: 'Trial',
            description: 'wedding tryout',
            points: [],
          ),
        ];
        when(
          () => repo.watchChecklists(),
        ).thenAnswer((_) => Stream.value(items));

        vm.initChecklistFilters(initialQuery: 'wedding');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 'Wedding' (name) and 'Trial' (description contains 'wedding')
        expect(vm.allChecklists.map((m) => m.id).toSet(), equals({'a', 'c'}));

        vm.setChecklistSearch('photo');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allChecklists.map((m) => m.id), equals(['b']));

        vm.clearSearch();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allChecklists.length, 3);

        // Calling init again is a no-op
        vm.initChecklistFilters();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        verify(() => repo.watchChecklists()).called(1);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // subscribe / unsubscribe single checklist
  // ───────────────────────────────────────────────────────────────────────────
  group('subscribeToChecklist / unsubscribeFromChecklist', () {
    test('subscribes once, caches incoming doc and removes on null', () async {
      final ctrl = StreamController<ChecklistModel?>();
      when(() => repo.watchChecklist('cl1')).thenAnswer((_) => ctrl.stream);

      vm.subscribeToChecklist('cl1');

      ctrl.add(
        const ChecklistModel(id: 'cl1', name: 'Steps', points: ['A', 'B']),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cache.getChecklist('cl1')?.name, 'Steps');

      ctrl.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cache.getChecklist('cl1'), isNull);

      // Guard against duplicate subscription
      vm.subscribeToChecklist('cl1');
      verify(() => repo.watchChecklist('cl1')).called(1);

      vm.unsubscribeFromChecklist('cl1');
      await ctrl.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // getters
  // ───────────────────────────────────────────────────────────────────────────
  group('getters', () {
    test(
      'getById returns null for null/empty; returns from cache otherwise',
      () {
        expect(vm.getById(null), isNull);
        expect(vm.getById(''), isNull);

        cache.cacheChecklist(const ChecklistModel(id: 'x', name: 'Any'));
        expect(vm.getById('x')!.name, 'Any');
      },
    );

    test('getChecklist finds from cache or from in-memory list', () async {
      when(() => repo.watchChecklists()).thenAnswer(
        (_) =>
            Stream.value([const ChecklistModel(id: 'm1', name: 'FromStream')]),
      );
      vm.initChecklistFilters();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // memory hit
      expect(vm.getChecklist('m1')?.name, 'FromStream');

      // cache hit
      cache.cacheChecklist(const ChecklistModel(id: 'c1', name: 'FromCache'));
      expect(vm.getChecklist('c1')?.name, 'FromCache');

      // missing
      expect(vm.getChecklist('nope'), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // prefetchChecklists
  // ───────────────────────────────────────────────────────────────────────────
  group('prefetchChecklists', () {
    test('returns early when all ids are already cached', () async {
      final fetchRepo = MockChecklistRepository();
      final fetchCache = ChecklistCache(fetchRepo);
      final theVm = ChecklistViewModel(repo, fetchCache);

      fetchCache.cacheChecklist(const ChecklistModel(id: 'i1', name: 'Seed'));
      await theVm.prefetchChecklists(['i1']);

      verifyNever(() => fetchRepo.getChecklists(any()));

      theVm.dispose();
    });

    test('fetches missing ids via cache and notifies', () async {
      final seed = {'i2': const ChecklistModel(id: 'i2', name: 'Fetched')};
      final theVm = ChecklistViewModel(
        repo,
        ChecklistCache(_FakeFetchRepo(seed)),
      );

      var ticks = 0;
      theVm.addListener(() => ticks++);

      expect(theVm.getChecklist('i2'), isNull);
      await theVm.prefetchChecklists(['i2']);

      expect(theVm.getChecklist('i2')!.name, 'Fetched');
      expect(ticks, greaterThanOrEqualTo(1));

      theVm.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // addChecklist / addChecklistWithPoints
  // ───────────────────────────────────────────────────────────────────────────
  group('addChecklist', () {
    test('validation: fails when name is empty', () async {
      final ok = await vm.addChecklist(
        name: '  ',
        description: 'desc',
        pointTexts: ['a', ''],
      );
      expect(ok, isFalse);
      expect(vm.error, 'Angiv navn på checklisten');
      verifyNever(() => repo.addChecklist(any()));
    });

    test('creates checklist, caches and filters', () async {
      // init with a query that will match 'Wedding' after add
      vm.initChecklistFilters(initialQuery: 'wed');

      when(() => repo.addChecklist(any())).thenAnswer(
        (_) async => const ChecklistModel(
          id: 'new1',
          name: 'Wedding',
          description: '  Bridal  ',
          points: ['A', 'B'], // already normalized by repo return
        ),
      );

      final ok = await vm.addChecklist(
        name: '  Wedding  ',
        description: '  Bridal  ',
        pointTexts: const ['A', ' ', 'B', ''],
      );
      expect(ok, isTrue);
      expect(vm.error, isNull);

      final cached = cache.getChecklist('new1');
      expect(cached, isNotNull);
      expect(cached!.name, 'Wedding');
      expect(cached.description, '  Bridal  ');
      expect(cached.points, equals(['A', 'B']));

      // Filter should include the newly added item (query 'wed')
      expect(vm.allChecklists.map((e) => e.id), contains('new1'));

      verify(() => repo.addChecklist(any())).called(1);
    });

    test('addChecklistWithPoints delegates and succeeds', () async {
      when(() => repo.addChecklist(any())).thenAnswer(
        (_) async => const ChecklistModel(
          id: 'p1',
          name: 'Photoshoot',
          description: null,
          points: ['Lens', 'Lights'],
        ),
      );

      final ok = await vm.addChecklistWithPoints(
        name: 'Photoshoot',
        description: null,
        points: const ['Lens', '', 'Lights', '   '],
      );

      expect(ok, isTrue);
      final cached = cache.getChecklist('p1');
      expect(cached!.points, equals(['Lens', 'Lights']));
      verify(() => repo.addChecklist(any())).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // updateChecklistFields
  // ───────────────────────────────────────────────────────────────────────────
  group('updateChecklistFields', () {
    setUp(() {
      cache.cacheChecklist(
        const ChecklistModel(
          id: 'u1',
          name: 'Old Name',
          description: 'Old Desc',
          points: ['X'],
        ),
      );
      when(
        () => repo.updateChecklist(any(), fields: any(named: 'fields')),
      ).thenAnswer((_) async {});
    });

    test('updates fields and points; cache reflects changes', () async {
      final ok = await vm.updateChecklistFields(
        'u1',
        name: '  New N ',
        description: ' New D ',
        points: const [' A ', ' ', 'B'],
      );
      expect(ok, isTrue);

      final captured =
          verify(
                () => repo.updateChecklist(
                  'u1',
                  fields: captureAny(named: 'fields'),
                ),
              ).captured.single
              as Map<String, Object?>;

      expect(captured['name'], 'New N');
      expect(captured['description'], 'New D');
      // points written as cleaned list (helper handles trimming/removal)
      expect(captured['points'], equals(['A', 'B']));

      final updated = cache.getChecklist('u1')!;
      expect(updated.name, 'New N');
      expect(updated.description, 'New D');
      expect(updated.points, equals(['A', 'B']));
    });

    test(
      'no-op: nothing to update → skips repo call and returns true',
      () async {
        final before = cache.getChecklist('u1');
        final ok = await vm.updateChecklistFields('u1');
        expect(ok, isTrue);

        verifyNever(
          () => repo.updateChecklist(any(), fields: any(named: 'fields')),
        );

        final after = cache.getChecklist('u1');
        expect(after, same(before));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // delete
  // ───────────────────────────────────────────────────────────────────────────
  group('delete', () {
    test('deletes repo doc, clears from cache and filtered list', () async {
      when(() => repo.watchChecklists()).thenAnswer(
        (_) => Stream.value([
          const ChecklistModel(id: 'd1', name: 'To Delete', points: []),
          const ChecklistModel(id: 'keep', name: 'Keep', points: []),
        ]),
      );
      vm.initChecklistFilters();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      when(() => repo.deleteChecklist('d1')).thenAnswer((_) async {});

      await vm.delete('d1');

      expect(cache.getChecklist('d1'), isNull);
      expect(vm.allChecklists.map((e) => e.id), equals(['keep']));

      verify(() => repo.deleteChecklist('d1')).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // reset
  // ───────────────────────────────────────────────────────────────────────────
  group('reset', () {
    test('clears in-memory state and notifies', () async {
      when(() => repo.watchChecklists()).thenAnswer(
        (_) => Stream.value([
          const ChecklistModel(id: 'r1', name: 'Any', points: []),
        ]),
      );
      vm.initChecklistFilters();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.allChecklists, isNotEmpty);

      var ticks = 0;
      vm.addListener(() => ticks++);

      vm.reset();
      expect(vm.allChecklists, isEmpty);
      expect(ticks, greaterThanOrEqualTo(1));
    });
  });
}
