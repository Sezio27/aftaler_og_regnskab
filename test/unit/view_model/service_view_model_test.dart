import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/domain/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/service_repository.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/data/services/image_storage.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
}

void main() {
  setUpAll(() {
    // Required so we can use any() / captureAny() with these types.
    registerFallbackValue(<String, Object?>{}); // for fields
    registerFallbackValue(<String>{}); // for deletes
    registerFallbackValue(const ServiceModel()); // for createServiceWithId(...)
    // for ImageStorage.uploadServiceImage(...) argument
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

  group('prefetchService', () {
    // When a service is already cached, prefetchService should just return
    // the cached instance and not trigger any extra fetch logic.
    test(
      'returns cached service without calling fetch when already in cache',
      () async {
        final service = const ServiceModel(id: 's1', name: 'Cached');
        cache.cacheService(service);

        final result = await vm.prefetchService('s1');

        expect(result, same(service));
      },
    );

    // When a service is not yet in the cache, prefetchService should ask
    // the cache/repository to fetch it and notify listeners when it appears.
    test(
      'fetches service via cache when missing, notifies listeners when found',
      () async {
        cache = ServiceCache(
          _FakeFetchRepo({'s2': const ServiceModel(id: 's2', name: 'Fetched')}),
        );
        vm = ServiceViewModel(repo, imageStorage, cache);

        var notified = false;
        vm.addListener(() {
          notified = true;
        });

        final result = await vm.prefetchService('s2');

        expect(result, isNotNull);
        expect(result!.id, 's2');
        expect(notified, isTrue);
      },
    );

    // If the repository/cache reports null for the requested id, the method
    // should simply return null and avoid notifying listeners.
    test(
      'returns null and does not crash when fetched service is null',
      () async {
        cache = ServiceCache(_FakeFetchRepo({'missing': null}));
        vm = ServiceViewModel(repo, imageStorage, cache);

        var notified = false;
        vm.addListener(() {
          notified = true;
        });

        final result = await vm.prefetchService('missing');

        expect(result, isNull);
        expect(notified, isFalse);
      },
    );
  });

  group('getService', () {
    // getService should simply return whatever is already in the cache.
    test('returns service from cache', () {
      final service = const ServiceModel(id: 's1', name: 'Brows');
      cache.cacheService(service);

      final res = vm.getService('s1');

      expect(res, same(service));
    });

    // If the service is not in the cache, getService should return null.
    test('returns null when service not in cache', () {
      final res = vm.getService('unknown');
      expect(res, isNull);
    });
  });

  group('search and filters', () {
    // initServiceFilters should subscribe to the stream once, fill the cache
    // and recompute the filtered list whenever new items arrive.
    test(
      'initServiceFilters subscribes once and uses cache to recompute lists',
      () async {
        final controller = StreamController<List<ServiceModel>>();
        when(() => repo.watchServices()).thenAnswer((_) => controller.stream);

        vm.initServiceFilters();
        controller.add([
          const ServiceModel(id: 'a', name: 'Bryn'),
          const ServiceModel(id: 'b', name: 'Makeup'),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(vm.allServices.map((s) => s.id), containsAll(['a', 'b']));

        await controller.close();
      },
    );

    // setServiceSearch should filter services by name, and clearSearch should
    // restore the full list again. Reusing the same trimmed query should hit
    // the "no-op" early-return path.
    test('setServiceSearch filters by name and clearSearch resets', () async {
      final services = [
        const ServiceModel(id: '1', name: 'Bryllupsmakeup'),
        const ServiceModel(id: '2', name: 'Bryn og vipper'),
      ];
      cache.cacheServices(services);

      // Force an initial recompute with empty query.
      vm.setServiceSearch('');

      vm.setServiceSearch('bryn');
      expect(vm.allServices.map((s) => s.id), ['2']);

      vm.clearSearch();
      expect(vm.allServices.length, 2);

      // Calling with the same trimmed query hits the early-return path.
      vm.setServiceSearch('makeup');
      vm.setServiceSearch('  makeup  ');
    });

    // When the query is already empty, clearSearch should actually do nothing
    // (and importantly, not throw).
    test('clearSearch returns early when query already empty', () {
      // _query starts empty; calling clearSearch should just return.
      vm.clearSearch();
    });
  });

  group('initServiceFilters and reset', () {
    // initServiceFilters should only subscribe once while _sub is non-null,
    // then after reset() it should be allowed to subscribe again.
    test('initServiceFilters is no-op when called twice until reset', () async {
      final controller = StreamController<List<ServiceModel>>.broadcast();
      var listenCount = 0;

      when(() => repo.watchServices()).thenAnswer((_) {
        listenCount++;
        return controller.stream;
      });

      vm.initServiceFilters();
      vm.initServiceFilters(); // should be ignored because _sub != null
      expect(listenCount, 1);

      vm.reset();
      vm.initServiceFilters(); // now allowed again
      expect(listenCount, 2);

      await controller.close();
    });
  });

  group('addService', () {
    // If the name is empty/blank, addService should fail fast, set an error
    // message, and never talk to the repository.
    test('returns false and sets error when name is empty', () async {
      final notified = <bool>[];
      vm.addListener(() => notified.add(true));

      final result = await vm.addService(name: null);

      expect(result, isFalse);
      expect(vm.error, isNotNull);
      expect(vm.saving, isFalse);
      verifyNever(() => repo.newServiceRef());
      expect(notified, isNotEmpty);
    });

    // When valid input is provided, addService should normalise strings,
    // create a new document via the repo, cache it and clear the saving flag.
    test(
      'creates service without image, caches it and resets saving flag',
      () async {
        when(() => repo.newServiceRef()).thenReturn(FakeDocumentRef('s1'));
        when(
          () => repo.createServiceWithId(any(), any()),
        ).thenAnswer((_) async {});

        final result = await vm.addService(
          name: ' Bryllup ',
          description: '  Heldags  ',
          duration: ' 4 timer ',
          price: 1000,
        );

        expect(result, isTrue);
        expect(vm.saving, isFalse);
        expect(vm.error, isNull);

        final cached = cache.getService('s1');
        expect(cached, isNotNull);
        expect(cached!.name, 'Bryllup');
        expect(cached.description, 'Heldags');
        expect(cached.duration, '4 timer');
        expect(cached.price, 1000);
        expect(vm.allServices.map((s) => s.id), contains('s1'));

        verify(() => repo.createServiceWithId('s1', any())).called(1);
      },
    );

    // If an image is provided, addService should upload it to storage and
    // store the returned URL on the created ServiceModel.
    test(
      'uploads image when provided and stores resulting URL on service',
      () async {
        when(() => repo.newServiceRef()).thenReturn(FakeDocumentRef('s2'));
        when(
          () => repo.createServiceWithId(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.uploadServiceImage(
            serviceId: any(named: 'serviceId'),
            image: any(named: 'image'),
          ),
        ).thenAnswer((_) async => 'http://image');

        final img = (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'pic.jpg',
          mimeType: 'image/jpeg',
        );

        final result = await vm.addService(name: 'WithImage', image: img);

        expect(result, isTrue);
        final cached = cache.getService('s2');
        expect(cached, isNotNull);
        expect(cached!.image, 'http://image');

        verify(
          () => imageStorage.uploadServiceImage(
            serviceId: 's2',
            image: any(named: 'image'),
          ),
        ).called(1);
      },
    );

    // If the repository throws during create, addService should return false,
    // expose a human-readable error and reset the saving flag.
    test(
      'sets error and returns false when repository throws during create',
      () async {
        when(() => repo.newServiceRef()).thenReturn(FakeDocumentRef('s3'));
        when(
          () => repo.createServiceWithId(any(), any()),
        ).thenThrow(Exception('boom'));

        final result = await vm.addService(name: 'Bad');

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke tilføje service'));
        expect(vm.saving, isFalse);
      },
    );
  });

  group('handleUploadImage', () {
    // If no image is given, handleUploadImage should just pass through
    // the existing URL and not touch storage at all.
    test(
      'returns existing URL when image is null and does not call storage',
      () async {
        final docRef = FakeDocumentRef('x');
        final result = await vm.handleUploadImage(null, 'existing-url', docRef);

        expect(result, 'existing-url');
        verifyNever(
          () => imageStorage.uploadServiceImage(
            serviceId: any(named: 'serviceId'),
            image: any(named: 'image'),
          ),
        );
      },
    );

    // If an image is given, handleUploadImage should upload it and return
    // the storage URL, using the document id as the folder key.
    test('uploads image and returns new URL when image is provided', () async {
      final docRef = FakeDocumentRef('y');
      when(
        () => imageStorage.uploadServiceImage(
          serviceId: any(named: 'serviceId'),
          image: any(named: 'image'),
        ),
      ).thenAnswer((_) async => 'new-url');

      final img = (
        bytes: Uint8List.fromList([1, 2, 3]),
        name: 'pic.jpg',
        mimeType: 'image/jpeg',
      );

      final result = await vm.handleUploadImage(img, null, docRef);

      expect(result, 'new-url');
      verify(
        () => imageStorage.uploadServiceImage(
          serviceId: 'y',
          image: any(named: 'image'),
        ),
      ).called(1);
    });
  });

  group('updateServiceFields & handleUpdateFields', () {
    // When no changes are provided, updateServiceFields should succeed,
    // but not call into the repository.
    test(
      'returns true and does not call repo when no changes provided',
      () async {
        final result = await vm.updateServiceFields('id1');

        expect(result, isTrue);
        expect(vm.error, isNull);
        verifyNever(
          () => repo.updateService(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        );
      },
    );

    // Updating some fields and clearing others should result in correct
    // fields/deletes maps and an updated cache entry.
    test(
      'updates fields and deletes others, then caches updated service',
      () async {
        final original = const ServiceModel(
          id: 'id1',
          name: 'Old',
          description: 'Kort',
          duration: '30 min',
          price: 100,
          image: 'old-image',
        );
        cache.cacheService(original);

        Map<String, Object?>? capturedFields;
        Set<String>? capturedDeletes;

        when(
          () => repo.updateService(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((invocation) async {
          capturedFields =
              invocation.namedArguments[#fields] as Map<String, Object?>;
          capturedDeletes = invocation.namedArguments[#deletes] as Set<String>;
        });

        final result = await vm.updateServiceFields(
          'id1',
          name: '  New Name  ',
          description: ' ', // should be deleted
          duration: ' 45 min ',
          price: 200,
        );

        expect(result, isTrue);
        expect(vm.error, isNull);
        expect(capturedFields, isNotNull);
        expect(capturedDeletes, isNotNull);
        expect(capturedFields!['name'], 'New Name');
        expect(capturedFields!['duration'], '45 min');
        expect(capturedFields!['price'], 200);
        expect(capturedDeletes, contains('description'));

        final updated = cache.getService('id1');
        expect(updated, isNotNull);
        expect(updated!.name, 'New Name');
        expect(updated.description, isNull);
        expect(updated.duration, '45 min');
        expect(updated.price, 200);
        expect(updated.image, 'old-image');
      },
    );

    // When a new image is provided, updateServiceFields should upload it and
    // update the cached model with the new image URL.
    test(
      'uploads new image and updates cache when newImage is provided',
      () async {
        final original = const ServiceModel(
          id: 'id1',
          name: 'HasImage',
          image: 'old',
        );
        cache.cacheService(original);

        when(
          () => repo.updateService(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.uploadServiceImage(
            serviceId: any(named: 'serviceId'),
            image: any(named: 'image'),
          ),
        ).thenAnswer((_) async => 'new-image');

        final img = (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'pic.jpg',
          mimeType: 'image/jpeg',
        );

        final result = await vm.updateServiceFields('id1', newImage: img);

        expect(result, isTrue);
        final updated = cache.getService('id1');
        expect(updated, isNotNull);
        expect(updated!.image, 'new-image');
      },
    );

    // When removeImage is true, the image field should be deleted both in
    // Firestore (via deletes) and from the local cache, even if delete fails.
    test(
      'removes image and swallows delete errors when removeImage is true',
      () async {
        final original = const ServiceModel(
          id: 'id1',
          name: 'HasImage',
          image: 'old-image',
        );
        cache.cacheService(original);

        when(
          () => repo.updateService(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.deleteServiceImage(any()),
        ).thenThrow(Exception('missing'));

        final result = await vm.updateServiceFields('id1', removeImage: true);

        expect(result, isTrue);
        final updated = cache.getService('id1');
        expect(updated, isNotNull);
        expect(updated!.image, isNull);

        verify(() => imageStorage.deleteServiceImage('id1')).called(1);
      },
    );

    // If the repository throws during update, the view model should expose a
    // readable error, reset saving and return false.
    test(
      'sets error and returns false when repo.updateService throws',
      () async {
        cache.cacheService(const ServiceModel(id: 'id1', name: 'Old'));

        when(
          () => repo.updateService(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenThrow(Exception('failure'));

        final result = await vm.updateServiceFields('id1', name: 'New');

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke opdatere'));
        expect(vm.saving, isFalse);
      },
    );
  });

  group('cacheUpdatedService', () {
    // If the service is not present in the cache, cacheUpdatedService should
    // simply do nothing and definitely not throw.
    test('does nothing when service is not present in cache', () {
      // Should not throw
      vm.cacheUpdatedService('missing', {}, {});
    });
  });

  group('priceFor', () {
    // If the id is null or empty, priceFor should just return null.
    test('returns null when id is null or empty', () {
      expect(vm.priceFor(null), isNull);
      expect(vm.priceFor(''), isNull);
    });

    // When a matching service exists in the cache, priceFor should return
    // its price.
    test('returns price when service exists', () {
      cache.cacheService(const ServiceModel(id: 's1', price: 250));
      expect(vm.priceFor('s1'), 250);
    });

    // If the service is missing in the cache, priceFor should return null.
    test('returns null when service does not exist', () {
      expect(vm.priceFor('unknown'), isNull);
    });
  });

  group('delete & cacheDelete', () {
    // delete should try to remove the image in storage (and swallow errors),
    // then delete the document in Firestore and evict the service from cache.
    test(
      'deletes image if possible, swallows errors, removes from cache',
      () async {
        cache.cacheService(const ServiceModel(id: 'id1', name: 'ToDelete'));

        when(
          () => imageStorage.deleteServiceImage(any()),
        ).thenThrow(Exception('missing'));
        when(() => repo.deleteService(any())).thenAnswer((_) async {});

        await vm.delete('id1');

        verify(() => repo.deleteService('id1')).called(1);
        expect(cache.getService('id1'), isNull);
      },
    );

    // cacheDelete only touches the local cache and recomputes filters; it
    // should be safe to call even if the id is not present.
    test('cacheDelete removes service from cache and recomputes', () {
      cache.cacheService(const ServiceModel(id: 'id1', name: 'Keep'));
      cache.cacheService(const ServiceModel(id: 'id2', name: 'Remove'));

      // Force list to be filled.
      vm.setServiceSearch('');

      vm.cacheDelete('id2');

      final ids = vm.allServices.map((s) => s.id).toList();
      expect(ids, contains('id1'));
      expect(ids, isNot(contains('id2')));
    });
  });

  group('reset', () {
    // reset should clear the query and filtered list, and allow a new
    // subscription via initServiceFilters. It deliberately does not clear
    // the underlying cache.
    test('resets query and list and allows re-initialisation', () async {
      cache.cacheService(const ServiceModel(id: 's1', name: 'Existing'));
      vm.setServiceSearch('existing'); // sets _query and recomputes

      expect(vm.allServices, isNotEmpty);

      vm.reset();

      expect(vm.allServices, isEmpty);

      // After reset, initServiceFilters should be allowed again.
      final controller = StreamController<List<ServiceModel>>();
      when(() => repo.watchServices()).thenAnswer((_) => controller.stream);

      vm.initServiceFilters();
      controller.add([const ServiceModel(id: 's2', name: 'New')]);
      await Future<void>.delayed(Duration.zero);

      final ids = vm.allServices.map((s) => s.id).toList();
      // At minimum, the newly streamed service must be present.
      expect(ids, contains('s2'));

      await controller.close();
    });
  });
}
