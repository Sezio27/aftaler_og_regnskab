import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/data/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test doubles
// ─────────────────────────────────────────────────────────────────────────────

class MockServiceRepository extends Mock implements ServiceRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

// ignore: subtype_of_sealed_class
/// Minimal fake Firestore DocumentReference exposing only `id`.
class FakeDocumentRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeDocumentRef(this._id);
  final String _id;
  @override
  String get id => _id;
}

/// A tiny fake ServiceRepository for ServiceCache.fetchServices().
class _FakeFetchRepo extends Fake implements ServiceRepository {
  _FakeFetchRepo([Map<String, ServiceModel?>? seed]) : _store = {...?seed};
  final Map<String, ServiceModel?> _store;

  @override
  Future<Map<String, ServiceModel?>> getServices(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }

  @override
  Future<ServiceModel?> getServiceOnce(String id) async => _store[id];
}

void main() {
  setUpAll(() {
    // Required so we can use any() / captureAny() with these types.
    registerFallbackValue(<String, Object?>{}); // for fields
    registerFallbackValue(<String>{}); // for deletes
    registerFallbackValue(const ServiceModel()); // for createServiceWithId(...)
    // for ImageStorage.uploadServiceImage(...) record argument
    registerFallbackValue((
      bytes: Uint8List(0),
      name: '',
      mimeType: null as String?,
    ));
  });

  late MockServiceRepository repo;
  late MockImageStorage imageStorage;
  late ServiceCache cache;
  late ServiceViewModel vm;

  setUp(() {
    repo = MockServiceRepository();
    imageStorage = MockImageStorage();
    cache = ServiceCache(_FakeFetchRepo());
    vm = ServiceViewModel(repo, imageStorage, cache);

    // Default: avoid "Null is not a subtype of Stream<List<ServiceModel>>"
    when(
      () => repo.watchServices(),
    ).thenAnswer((_) => const Stream<List<ServiceModel>>.empty());
  });

  tearDown(() {
    vm.dispose();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // init / filtering
  // ───────────────────────────────────────────────────────────────────────────
  group('initServiceFilters & filtering', () {
    test(
      'subscribes once, caches, and filters by query; clearSearch resets',
      () async {
        final items = <ServiceModel>[
          const ServiceModel(
            id: 's1',
            name: 'Makeup',
            duration: '30',
            price: 250,
          ),
          const ServiceModel(
            id: 's2',
            name: 'Hair',
            duration: '45',
            price: 300,
          ),
          const ServiceModel(
            id: 's3',
            name: 'Nails',
            duration: '20',
            price: 150,
          ),
        ];
        when(() => repo.watchServices()).thenAnswer((_) => Stream.value(items));

        vm.initServiceFilters(initialQuery: 'ha');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(vm.allServices.map((e) => e.id), equals(['s2']));

        vm.setServiceSearch('make');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allServices.map((e) => e.id), equals(['s1']));

        vm.clearSearch();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allServices.length, 3);

        // Calling init again is a no-op
        vm.initServiceFilters();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allServices.length, 3);

        verify(() => repo.watchServices()).called(1);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // subscribe / unsubscribe single service
  // ───────────────────────────────────────────────────────────────────────────
  group('subscribeToService / unsubscribeFromService', () {
    test('subscribes once, caches incoming docs and removes on null', () async {
      final ctrl = StreamController<ServiceModel?>();
      when(() => repo.watchService('svc1')).thenAnswer((_) => ctrl.stream);

      vm.subscribeToService('svc1');

      ctrl.add(const ServiceModel(id: 'svc1', name: 'Brow Lift', price: 900));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cache.getService('svc1')?.name, 'Brow Lift');

      ctrl.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cache.getService('svc1'), isNull);

      vm.subscribeToService('svc1');
      verify(() => repo.watchService('svc1')).called(1);

      vm.unsubscribeFromService('svc1');
      await ctrl.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // getById / getService / priceFor
  // ───────────────────────────────────────────────────────────────────────────
  group('getters', () {
    test(
      'getById returns null for null/empty and returns from cache otherwise',
      () {
        expect(vm.getById(null), isNull);
        expect(vm.getById(''), isNull);

        cache.cacheService(
          const ServiceModel(id: 'x', name: 'Lash Lift', price: 500),
        );
        expect(vm.getById('x')!.name, 'Lash Lift');
      },
    );

    test('getService finds from cache or from in-memory all list', () async {
      when(() => repo.watchServices()).thenAnswer(
        (_) => Stream.value([
          const ServiceModel(id: 'a', name: 'Makeup'),
          const ServiceModel(id: 'b', name: 'Hair'),
        ]),
      );
      vm.initServiceFilters();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(vm.getService('b')?.name, 'Hair');

      cache.cacheService(const ServiceModel(id: 'c', name: 'Nails'));
      expect(vm.getService('c')?.name, 'Nails');
    });

    test('priceFor returns price for id or null otherwise', () {
      expect(vm.priceFor(null), isNull);
      expect(vm.priceFor(''), isNull);

      cache.cacheService(
        const ServiceModel(id: 'p', name: 'Test', price: 123.0),
      );
      expect(vm.priceFor('p'), 123.0);
      expect(vm.priceFor('missing'), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // prefetchService
  // ───────────────────────────────────────────────────────────────────────────
  group('prefetchService', () {
    test('returns cached immediately without calling fetch', () async {
      final fetchRepo = MockServiceRepository();
      final fetchCache = ServiceCache(fetchRepo);
      final theVm = ServiceViewModel(repo, imageStorage, fetchCache);

      fetchCache.cacheService(const ServiceModel(id: 'id1', name: 'Precached'));
      final notifierTicks = <int>[];
      theVm.addListener(() => notifierTicks.add(1));

      final result = await theVm.prefetchService('id1');
      expect(result!.name, 'Precached');
      verifyNever(() => fetchRepo.getServices(any()));
      expect(notifierTicks, isEmpty);
      theVm.dispose();
    });

    test('fetches via cache when missing, updates and notifies', () async {
      final seed = {'id2': const ServiceModel(id: 'id2', name: 'Fetched One')};
      final theVm = ServiceViewModel(
        repo,
        imageStorage,
        ServiceCache(_FakeFetchRepo(seed)),
      );

      var notified = 0;
      theVm.addListener(() => notified++);

      final before = theVm.getService('id2');
      expect(before, isNull);

      final got = await theVm.prefetchService('id2');
      expect(got!.name, 'Fetched One');
      expect(theVm.getService('id2')!.name, 'Fetched One');
      expect(notified, greaterThanOrEqualTo(1));
      theVm.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // addService
  // ───────────────────────────────────────────────────────────────────────────
  group('addService', () {
    test('validation: fails when name is empty', () async {
      final ok = await vm.addService(
        name: '',
        description: 'desc',
        duration: '30',
        price: 100,
      );
      expect(ok, isFalse);
      expect(vm.error, 'Angiv navn på servicen');
      verifyNever(() => repo.newServiceRef());
      verifyNever(() => repo.createServiceWithId(any(), any()));
    });

    test('creates service, uploads image, caches and filters', () async {
      final fake = FakeDocumentRef('svc123');
      when(() => repo.newServiceRef()).thenReturn(fake);
      when(
        () => imageStorage.uploadServiceImage(
          serviceId: 'svc123',
          image: any(named: 'image'),
        ),
      ).thenAnswer((_) async => 'https://img');
      when(
        () => repo.createServiceWithId('svc123', any()),
      ).thenAnswer((_) async {});

      // Keep default empty stream (initServiceFilters won't populate _all)
      vm.initServiceFilters(initialQuery: 'make');

      final ok = await vm.addService(
        name: '  Makeup Basic  ',
        description: '  Nice  ',
        duration: ' 45 ',
        price: 350.0,
        image: (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'a.png',
          mimeType: 'image/png',
        ),
      );

      expect(ok, isTrue);
      expect(vm.error, isNull);

      final cached = cache.getService('svc123');
      expect(cached, isNotNull);
      expect(cached!.name, 'Makeup Basic');
      expect(cached.duration, '45');
      expect(cached.price, 350.0);
      expect(cached.image, 'https://img');

      verify(() => repo.newServiceRef()).called(1);
      verify(
        () => imageStorage.uploadServiceImage(
          serviceId: 'svc123',
          image: any(named: 'image'),
        ),
      ).called(1);
      verify(() => repo.createServiceWithId('svc123', any())).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // updateServiceFields
  // ───────────────────────────────────────────────────────────────────────────
  group('updateServiceFields', () {
    setUp(() {
      cache.cacheService(
        const ServiceModel(
          id: 'u1',
          name: 'Old',
          description: 'Old D',
          duration: '30',
          price: 100,
          image: 'old.png',
        ),
      );
      when(
        () => repo.updateService(
          any(),
          fields: any(named: 'fields'),
          deletes: any(named: 'deletes'),
        ),
      ).thenAnswer((_) async {});
    });

    test('updates scalar fields; cache reflects changes', () async {
      final ok = await vm.updateServiceFields(
        'u1',
        name: '  New Name ',
        description: ' New Desc ',
        duration: ' 60 ',
        price: 250.0,
      );
      expect(ok, isTrue);

      final captured = verify(
        () => repo.updateService(
          'u1',
          fields: captureAny(named: 'fields'),
          deletes: captureAny(named: 'deletes'),
        ),
      ).captured;

      late Map<String, Object?> fields;
      late Set<String> deletes;
      if (captured.first is Map<String, Object?>) {
        fields = captured.first as Map<String, Object?>;
        deletes = captured.last as Set<String>;
      } else {
        fields = captured.last as Map<String, Object?>;
        deletes = captured.first as Set<String>;
      }

      expect(fields['name'], 'New Name');
      expect(fields['description'], 'New Desc');
      expect(fields['duration'], '60');
      expect(fields['price'], 250.0);
      expect(deletes, isEmpty);

      final updated = cache.getService('u1')!;
      expect(updated.name, 'New Name');
      expect(updated.description, 'New Desc');
      expect(updated.duration, '60');
      expect(updated.price, 250.0);
      expect(updated.image, 'old.png');
    });

    test('newImage uploads and sets image field', () async {
      when(
        () => imageStorage.uploadServiceImage(
          serviceId: 'u1',
          image: any(named: 'image'),
        ),
      ).thenAnswer((_) async => 'https://new');

      await vm.updateServiceFields(
        'u1',
        newImage: (
          bytes: Uint8List.fromList([0, 1]),
          name: 'x.png',
          mimeType: 'image/png',
        ),
      );

      final captured = verify(
        () => repo.updateService(
          'u1',
          fields: captureAny(named: 'fields'),
          deletes: captureAny(named: 'deletes'),
        ),
      ).captured;

      final fields = (captured.first is Map<String, Object?>)
          ? captured.first as Map<String, Object?>
          : captured.last as Map<String, Object?>;

      expect(fields['image'], 'https://new');

      final updated = cache.getService('u1')!;
      expect(updated.image, 'https://new');

      verify(
        () => imageStorage.uploadServiceImage(
          serviceId: 'u1',
          image: any(named: 'image'),
        ),
      ).called(1);
    });

    test('deletes image and calls storage delete', () async {
      when(
        () => imageStorage.deleteServiceImage('u1'),
      ).thenAnswer((_) async {});

      await vm.updateServiceFields('u1', removeImage: true);

      final captured = verify(
        () => repo.updateService(
          'u1',
          fields: captureAny(named: 'fields'),
          deletes: captureAny(named: 'deletes'),
        ),
      ).captured;

      late Map<String, Object?> fields;
      late Set<String> deletes;
      if (captured.first is Map<String, Object?>) {
        fields = captured.first as Map<String, Object?>;
        deletes = captured.last as Set<String>;
      } else {
        fields = captured.last as Map<String, Object?>;
        deletes = captured.first as Set<String>;
      }

      expect(fields.containsKey('image'), isFalse);
      expect(deletes.contains('image'), isTrue);

      verify(() => imageStorage.deleteServiceImage('u1')).called(1);
    });

    test(
      'no-op: nothing to update → skips repo call and returns true',
      () async {
        final before = cache.getService('u1');

        final ok = await vm.updateServiceFields('u1');
        expect(ok, isTrue);

        verifyNever(
          () => repo.updateService(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        );

        final after = cache.getService('u1');
        expect(after, same(before));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // delete
  // ───────────────────────────────────────────────────────────────────────────
  group('delete', () {
    test(
      'deletes storage image, repo doc, and clears from cache and lists',
      () async {
        final items = [
          const ServiceModel(id: 'd1', name: 'Will Delete'),
          const ServiceModel(id: 'keep', name: 'Keep'),
        ];
        when(() => repo.watchServices()).thenAnswer((_) => Stream.value(items));
        vm.initServiceFilters();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        when(
          () => imageStorage.deleteServiceImage('d1'),
        ).thenAnswer((_) async {});
        when(() => repo.deleteService('d1')).thenAnswer((_) async {});

        await vm.delete('d1');

        expect(cache.getService('d1'), isNull);
        expect(vm.allServices.map((e) => e.id), equals(['keep']));

        verify(() => imageStorage.deleteServiceImage('d1')).called(1);
        verify(() => repo.deleteService('d1')).called(1);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // reset
  // ───────────────────────────────────────────────────────────────────────────
  group('reset', () {
    test('clears in-memory state and notifies', () async {
      when(() => repo.watchServices()).thenAnswer(
        (_) => Stream.value([const ServiceModel(id: 'r1', name: 'Any')]),
      );
      vm.initServiceFilters();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.allServices, isNotEmpty);

      var ticks = 0;
      vm.addListener(() => ticks++);

      vm.reset();
      expect(vm.allServices, isEmpty);
      expect(ticks, greaterThanOrEqualTo(1));
    });
  });
}
