import 'dart:async';

import 'package:aftaler_og_regnskab/domain/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/checklist_repository.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChecklistRepository extends Mock implements ChecklistRepository {}

/// A tiny fake ChecklistRepository for ChecklistCache.fetchChecklists().
class _FakeFetchRepo extends Fake implements ChecklistRepository {
  _FakeFetchRepo([Map<String, ChecklistModel?>? seed]) : _store = {...?seed};
  final Map<String, ChecklistModel?> _store;

  @override
  Future<Map<String, ChecklistModel?>> getChecklists(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }
}

/// Spy cache that lets us see if fetchChecklists was called (used for
/// prefetchChecklists tests).
class SpyChecklistCache extends ChecklistCache {
  SpyChecklistCache(ChecklistRepository repo) : super(repo);

  bool fetchCalled = false;
  Set<String>? lastIds;

  @override
  Future<Map<String, ChecklistModel?>> fetchChecklists(Set<String> ids) async {
    fetchCalled = true;
    lastIds = ids;
    return super.fetchChecklists(ids);
  }
}

void main() {
  setUpAll(() {
    // Required so we can use any() / captureAny() with these types.
    registerFallbackValue(<String, Object?>{}); // for fields
    registerFallbackValue(const ChecklistModel()); // for addChecklist(...)
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

  group('initChecklistFilters, search & getChecklist', () {
    // initChecklistFilters should subscribe once, cache incoming items,
    // and recompute the filtered list whenever the stream emits.
    test('initChecklistFilters subscribes and recomputes from cache', () async {
      final controller = StreamController<List<ChecklistModel>>();
      when(() => repo.watchChecklists()).thenAnswer((_) => controller.stream);

      vm.initChecklistFilters();
      controller.add([
        const ChecklistModel(id: 'a', name: 'Hudpleje', description: 'A'),
        const ChecklistModel(id: 'b', name: 'Makeup', description: 'B'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.allChecklists.map((c) => c.id), containsAll(['a', 'b']));

      await controller.close();
    });

    // setChecklistSearch should filter by name/description and clearSearch
    // should restore the full list.
    test(
      'setChecklistSearch filters by name/description and clearSearch resets',
      () {
        final items = [
          const ChecklistModel(
            id: '1',
            name: 'Brudens hud',
            description: 'Hudpleje før bryllup',
          ),
          const ChecklistModel(
            id: '2',
            name: 'Makeup tjek',
            description: 'Læber og øjne',
          ),
        ];
        cache.cacheChecklists(items);

        // Force initial recompute with empty query.
        vm.setChecklistSearch('');

        vm.setChecklistSearch('hud');
        expect(vm.allChecklists.map((c) => c.id), ['1']);

        vm.clearSearch();
        expect(vm.allChecklists.length, 2);

        // Calling with the same trimmed query should be a no-op.
        vm.setChecklistSearch('makeup');
        vm.setChecklistSearch('  makeup  ');
      },
    );

    // clearSearch should return immediately if the query is already empty.
    test('clearSearch returns early when query already empty', () {
      // _query starts empty; calling clearSearch should just return.
      vm.clearSearch();
    });

    // getChecklist should simply return whatever is cached for the id.
    test('getChecklist returns checklist from cache when present', () {
      final cl = const ChecklistModel(id: 'c1', name: 'Cached');
      cache.cacheChecklist(cl);

      final result = vm.getChecklist('c1');

      expect(result, same(cl));
    });

    // If no checklist is cached for the id, getChecklist returns null.
    test('getChecklist returns null when not cached', () {
      final result = vm.getChecklist('missing');
      expect(result, isNull);
    });
  });

  group('initChecklistFilters and reset', () {
    // initChecklistFilters should be a no-op when called again while the
    // subscription is active. After reset() it should be allowed again.
    test(
      'initChecklistFilters is no-op when called twice until reset',
      () async {
        final controller = StreamController<List<ChecklistModel>>.broadcast();
        var listenCount = 0;

        when(() => repo.watchChecklists()).thenAnswer((_) {
          listenCount++;
          return controller.stream;
        });

        vm.initChecklistFilters();
        vm.initChecklistFilters(); // should be ignored because _sub != null
        expect(listenCount, 1);

        vm.reset();
        vm.initChecklistFilters(); // now allowed again
        expect(listenCount, 2);

        await controller.close();
      },
    );

    // reset should clear the query and filtered list and cancel the subscription,
    // and allow re-initialisation via initChecklistFilters.
    test('reset clears query and list and allows re-initialisation', () async {
      cache.cacheChecklist(const ChecklistModel(id: 'c1', name: 'Existing'));
      vm.setChecklistSearch('existing'); // sets _query and recomputes

      expect(vm.allChecklists, isNotEmpty);

      vm.reset();

      expect(vm.allChecklists, isEmpty);

      final controller = StreamController<List<ChecklistModel>>();
      when(() => repo.watchChecklists()).thenAnswer((_) => controller.stream);

      vm.initChecklistFilters();
      controller.add([const ChecklistModel(id: 'c2', name: 'New')]);
      await Future<void>.delayed(Duration.zero);

      final ids = vm.allChecklists.map((c) => c.id).toList();
      expect(ids, contains('c2'));

      await controller.close();
    });
  });

  group('prefetchChecklists', () {
    // If all requested ids are already present in the cache, prefetchChecklists
    // should return early and not trigger a fetch or notify listeners.
    test('returns early when all requested ids already cached', () async {
      final spyCache = SpyChecklistCache(_FakeFetchRepo());
      final localVm = ChecklistViewModel(repo, spyCache);

      spyCache.cacheChecklist(
        const ChecklistModel(id: 'c1', name: 'Already here'),
      );

      var notified = false;
      localVm.addListener(() => notified = true);

      await localVm.prefetchChecklists(['c1']);

      expect(spyCache.fetchCalled, isFalse);
      expect(notified, isFalse);
    });

    // When some ids are missing and at least one non-null checklist is fetched,
    // prefetchChecklists should notify listeners.
    test(
      'fetches missing ids and notifies when any non-null is returned',
      () async {
        final spyCache = SpyChecklistCache(
          _FakeFetchRepo({
            'c2': const ChecklistModel(id: 'c2', name: 'Fetched'),
          }),
        );
        final localVm = ChecklistViewModel(repo, spyCache);

        var notified = false;
        localVm.addListener(() => notified = true);

        await localVm.prefetchChecklists(['c2']);

        expect(spyCache.fetchCalled, isTrue);
        expect(spyCache.lastIds, contains('c2'));
        expect(notified, isTrue);
      },
    );

    // If everything fetched is null, prefetchChecklists should still call
    // fetchChecklists but must not notify listeners.
    test('fetches missing ids but does not notify when all are null', () async {
      final spyCache = SpyChecklistCache(_FakeFetchRepo({'c3': null}));
      final localVm = ChecklistViewModel(repo, spyCache);

      var notified = false;
      localVm.addListener(() => notified = true);

      await localVm.prefetchChecklists(['c3']);

      expect(spyCache.fetchCalled, isTrue);
      expect(spyCache.lastIds, contains('c3'));
      expect(notified, isFalse);
    });
  });

  group('addChecklist & addChecklistWithPoints', () {
    // If the name is missing/blank, addChecklist should fail fast, set an
    // error, and never talk to the repository.
    test('returns false and sets error when name is empty', () async {
      final notified = <bool>[];
      vm.addListener(() => notified.add(true));

      final result = await vm.addChecklist(
        name: null,
        description: 'Ignored',
        pointTexts: ['A'],
      );

      expect(result, isFalse);
      expect(vm.error, isNotNull);
      expect(vm.saving, isFalse);
      verifyNever(() => repo.addChecklist(any()));
      expect(notified, isNotEmpty);
    });

    // For a valid name, addChecklist should normalise strings, normalise
    // points (trim + drop empties), call the repo, cache the created model
    // if it has an id, and reset the saving flag.
    test('creates checklist, caches it and resets saving flag', () async {
      when(() => repo.addChecklist(any())).thenAnswer((invocation) async {
        final model = invocation.positionalArguments[0] as ChecklistModel;
        // Simulate Firestore assigning an id.
        return model.copyWith(id: 'ch1');
      });

      final result = await vm.addChecklist(
        name: '  My list  ',
        description: '  Beskrivelse  ',
        pointTexts: ['  A  ', '', 'B ', '   '],
      );

      expect(result, isTrue);
      expect(vm.saving, isFalse);
      expect(vm.error, isNull);

      final cached = cache.getChecklist('ch1');
      expect(cached, isNotNull);
      expect(cached!.name, 'My list');
      expect(cached.description, 'Beskrivelse');
      expect(cached.points, ['A', 'B']);
      expect(vm.allChecklists.map((c) => c.id), contains('ch1'));

      verify(() => repo.addChecklist(any())).called(1);
    });

    // If the repository returns a model with a null id, addChecklist should
    // still succeed but skip caching and recomputing the list.
    test('does not cache checklist when created has null id', () async {
      when(() => repo.addChecklist(any())).thenAnswer(
        (_) async => const ChecklistModel(id: null, name: 'No id', points: []),
      );

      final result = await vm.addChecklist(
        name: 'No id',
        description: null,
        pointTexts: const [],
      );

      expect(result, isTrue);
      expect(cache.allCachedChecklists, isEmpty);
      expect(vm.allChecklists, isEmpty);
    });

    // If the repository throws during addChecklist, the view model should
    // expose an error, reset saving and return false.
    test(
      'sets error and returns false when repo.addChecklist throws',
      () async {
        when(() => repo.addChecklist(any())).thenThrow(Exception('boom'));

        final result = await vm.addChecklist(
          name: 'Error',
          description: 'X',
          pointTexts: ['1'],
        );

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke tilføje checklist'));
        expect(vm.saving, isFalse);
      },
    );

    // addChecklistWithPoints is a small wrapper around addChecklist. This
    // test checks that it forwards the values correctly and calls the repo.
    test(
      'addChecklistWithPoints forwards to addChecklist and repo.addChecklist',
      () async {
        ChecklistModel? passed;
        when(() => repo.addChecklist(any())).thenAnswer((invocation) async {
          passed = invocation.positionalArguments[0] as ChecklistModel;
          return passed!.copyWith(id: 'forward-id');
        });

        final result = await vm.addChecklistWithPoints(
          name: 'Forwarded',
          description: 'Desc',
          points: [' p1 ', 'p2', '   '],
        );

        expect(result, isTrue);
        expect(passed, isNotNull);
        expect(passed!.name, 'Forwarded');
        expect(passed!.description, 'Desc');
        expect(passed!.points, ['p1', 'p2']);
        verify(() => repo.addChecklist(any())).called(1);
      },
    );
  });

  group('updateChecklistFields & handleUpdateFields', () {
    // If no changes are provided, updateChecklistFields should return true
    // but not call into the repository.
    test(
      'returns true and does not call repo when no changes provided',
      () async {
        final result = await vm.updateChecklistFields('id1');

        expect(result, isTrue);
        expect(vm.error, isNull);
        verifyNever(
          () => repo.updateChecklist(any(), fields: any(named: 'fields')),
        );
      },
    );

    // Passing updated name/description/points should produce the correct
    // fields map and update the cached checklist accordingly.
    test('updates fields and then caches updated checklist', () async {
      final original = const ChecklistModel(
        id: 'id1',
        name: 'Old name',
        description: 'Old desc',
        points: ['one', 'two'],
      );
      cache.cacheChecklist(original);

      Map<String, Object?>? capturedFields;

      when(
        () => repo.updateChecklist(any(), fields: any(named: 'fields')),
      ).thenAnswer((invocation) async {
        capturedFields =
            invocation.namedArguments[#fields] as Map<String, Object?>;
      });

      final result = await vm.updateChecklistFields(
        'id1',
        name: '  New name  ',
        description: ' ', // becomes null in fields (for Firestore cleanup)
        points: ['  X  ', '', 'Y', '   '],
      );

      expect(result, isTrue);
      expect(vm.error, isNull);
      expect(capturedFields, isNotNull);
      expect(capturedFields!['name'], 'New name');
      expect(capturedFields!['description'], isNull);
      expect(capturedFields!['points'], ['X', 'Y']);

      final updated = cache.getChecklist('id1');
      expect(updated, isNotNull);
      expect(updated!.name, 'New name');
      // We only require points to have updated here; behaviour of description
      // (null vs old value) depends on ChecklistModel.copyWith semantics.
      expect(updated.points, ['X', 'Y']);
    });

    // If the repository throws during update, updateChecklistFields should
    // return false, expose a human-readable error and reset saving.
    test(
      'sets error and returns false when repo.updateChecklist throws',
      () async {
        cache.cacheChecklist(
          const ChecklistModel(id: 'id1', name: 'Old', points: []),
        );

        when(
          () => repo.updateChecklist(any(), fields: any(named: 'fields')),
        ).thenThrow(Exception('failure'));

        final result = await vm.updateChecklistFields('id1', name: 'New');

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke opdatere'));
        expect(vm.saving, isFalse);
      },
    );
  });

  group('cacheUpdated', () {
    // If no checklist with that id exists in the cache, cacheUpdated should
    // just do nothing and definitely not throw.
    test('does nothing when checklist is not present in cache', () {
      vm.cacheUpdated('missing', {});
    });
  });

  group('delete', () {
    // delete should call the repository, remove the checklist from the cache
    // and recompute the filtered list.
    test('deletes checklist via repo and removes from cache', () async {
      cache.cacheChecklist(const ChecklistModel(id: 'id1', name: 'ToDelete'));
      when(() => repo.deleteChecklist(any())).thenAnswer((_) async {});

      await vm.delete('id1');

      verify(() => repo.deleteChecklist('id1')).called(1);
      expect(cache.getChecklist('id1'), isNull);
    });
  });
}
