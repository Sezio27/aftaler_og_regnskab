import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/domain/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/client_repository.dart';
import 'package:aftaler_og_regnskab/domain/client_model.dart';
import 'package:aftaler_og_regnskab/data/services/image_storage.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockClientRepository extends Mock implements ClientRepository {}

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

/// A tiny fake ClientRepository for ClientCache.fetchClients().
class _FakeFetchRepo extends Fake implements ClientRepository {
  _FakeFetchRepo([Map<String, ClientModel?>? seed]) : _store = {...?seed};
  final Map<String, ClientModel?> _store;

  @override
  Future<Map<String, ClientModel?>> getClients(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }
}

void main() {
  setUpAll(() {
    // Required so we can use any() / captureAny() with these types.
    registerFallbackValue(<String, Object?>{}); // for fields
    registerFallbackValue(<String>{}); // for deletes
    registerFallbackValue(const ClientModel()); // for createClientWithId(...)
    // for ImageStorage.uploadClientImage(...) argument
    registerFallbackValue((
      bytes: Uint8List(0),
      name: '',
      mimeType: null as String?,
    ));
  });

  late MockClientRepository repo;
  late MockImageStorage imageStorage;
  late ClientCache cache;
  late ClientViewModel vm;

  setUp(() {
    repo = MockClientRepository();
    imageStorage = MockImageStorage();
    cache = ClientCache(_FakeFetchRepo());
    vm = ClientViewModel(repo, imageStorage, cache);

    // Default: avoid "Null is not a subtype of Stream<List<ClientModel>>"
    when(
      () => repo.watchClients(),
    ).thenAnswer((_) => const Stream<List<ClientModel>>.empty());
  });

  tearDown(() {
    vm.dispose();
  });

  group('prefetchClient', () {
    test(
      'returns cached client without calling fetch when already in cache',
      () async {
        final client = const ClientModel(id: 'c1', name: 'Cached');
        cache.cacheClient(client);

        final result = await vm.prefetchClient('c1');

        expect(result, same(client));
      },
    );

    test(
      'fetches client via cache when missing, notifies listeners when found',
      () async {
        cache = ClientCache(
          _FakeFetchRepo({'c2': const ClientModel(id: 'c2', name: 'Fetched')}),
        );
        vm = ClientViewModel(repo, imageStorage, cache);

        var notified = false;
        vm.addListener(() {
          notified = true;
        });

        final result = await vm.prefetchClient('c2');

        expect(result, isNotNull);
        expect(result!.id, 'c2');
        expect(notified, isTrue);
      },
    );

    test(
      'returns null and does not crash when fetched client is null',
      () async {
        cache = ClientCache(_FakeFetchRepo({'missing': null}));
        vm = ClientViewModel(repo, imageStorage, cache);

        var notified = false;
        vm.addListener(() {
          notified = true;
        });

        final result = await vm.prefetchClient('missing');

        expect(result, isNull);
        expect(notified, isFalse);
      },
    );
  });

  group('getClient', () {
    test('returns client from cache', () {
      final client = const ClientModel(id: 'c1', name: 'Alice');
      cache.cacheClient(client);

      final res = vm.getClient('c1');

      expect(res, same(client));
    });

    test('returns null when client not in cache', () {
      final res = vm.getClient('unknown');
      expect(res, isNull);
    });
  });

  group('search and filters', () {
    test(
      'initClientFilters subscribes once and uses cache to recompute lists',
      () async {
        final controller = StreamController<List<ClientModel>>();
        when(() => repo.watchClients()).thenAnswer((_) => controller.stream);

        vm.initClientFilters();
        controller.add([
          const ClientModel(id: 'p', name: 'Private', cvr: null),
          const ClientModel(id: 'b', name: 'Business', cvr: '123'),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(vm.allClients.map((c) => c.id), containsAll(['p', 'b']));
        expect(vm.privateClients.map((c) => c.id), ['p']);
        expect(vm.businessClients.map((c) => c.id), ['b']);
        expect(vm.privateCount, 1);
        expect(vm.businessCount, 1);

        await controller.close();
      },
    );

    test(
      'setClientSearch filters by name/email/phone and clearSearch resets',
      () async {
        final clients = [
          const ClientModel(
            id: '1',
            name: 'Alice',
            email: 'alice@example.com',
            phone: '111',
          ),
          const ClientModel(
            id: '2',
            name: 'Bob',
            email: 'bob@example.com',
            phone: '222',
            cvr: 'CVR',
          ),
        ];
        cache.cacheClients(clients);
        // Force initial recompute
        vm.setClientSearch('');

        vm.setClientSearch('bob');
        expect(vm.allClients.map((c) => c.id), ['2']);

        vm.clearSearch();
        expect(vm.allClients.length, 2);

        // Calling with the same trimmed query hits the early-return path.
        vm.setClientSearch('alice');
        vm.setClientSearch('  alice  ');
      },
    );

    test('clearSearch returns early when query already empty', () {
      // _query starts empty; calling clearSearch should just return.
      vm.clearSearch();
    });
  });

  group('initClientFilters and reset', () {
    test('initClientFilters is no-op when called twice until reset', () async {
      final controller = StreamController<List<ClientModel>>.broadcast();
      var listenCount = 0;

      when(() => repo.watchClients()).thenAnswer((_) {
        listenCount++;
        return controller.stream;
      });

      vm.initClientFilters();
      vm.initClientFilters(); // should be ignored because _sub != null
      expect(listenCount, 1);

      vm.reset();
      vm.initClientFilters(); // now allowed again
      expect(listenCount, 2);

      await controller.close();
    });
  });

  group('addClient', () {
    test(
      'returns false and sets error when both name and email are empty',
      () async {
        final notified = <bool>[];
        vm.addListener(() => notified.add(true));

        final result = await vm.addClient(name: null, email: null);

        expect(result, isFalse);
        expect(vm.error, isNotNull);
        expect(vm.saving, isFalse);
        verifyNever(() => repo.newClientRef());
        expect(notified, isNotEmpty);
      },
    );

    test(
      'creates client without image, caches it and resets saving flag',
      () async {
        when(() => repo.newClientRef()).thenReturn(FakeDocumentRef('c1'));
        when(
          () => repo.createClientWithId(any(), any()),
        ).thenAnswer((_) async {});

        final result = await vm.addClient(
          name: ' Alice ',
          phone: ' 123 ',
          email: '',
          address: 'Main St ',
          city: 'City ',
          postal: ' 1000 ',
          cvr: '   ', // should be normalised to null
        );

        expect(result, isTrue);
        expect(vm.saving, isFalse);
        expect(vm.error, isNull);

        final cached = cache.getClient('c1');
        expect(cached, isNotNull);
        expect(cached!.name, 'Alice');
        expect(cached.phone, '123');
        expect(cached.cvr, isNull);
        expect(vm.allClients.map((c) => c.id), contains('c1'));

        verify(() => repo.createClientWithId('c1', any())).called(1);
      },
    );

    test(
      'uploads image when provided and stores resulting URL on client',
      () async {
        when(() => repo.newClientRef()).thenReturn(FakeDocumentRef('c2'));
        when(
          () => repo.createClientWithId(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.uploadClientImage(
            clientId: any(named: 'clientId'),
            image: any(named: 'image'),
          ),
        ).thenAnswer((_) async => 'http://image');

        final img = (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'pic.jpg',
          mimeType: 'image/jpeg',
        );

        final result = await vm.addClient(
          name: 'WithImage',
          email: 'with@img',
          image: img,
        );

        expect(result, isTrue);
        final cached = cache.getClient('c2');
        expect(cached, isNotNull);
        expect(cached!.image, 'http://image');

        verify(
          () => imageStorage.uploadClientImage(
            clientId: 'c2',
            image: any(named: 'image'),
          ),
        ).called(1);
      },
    );

    test(
      'sets error and returns false when repository throws during create',
      () async {
        when(() => repo.newClientRef()).thenReturn(FakeDocumentRef('c3'));
        when(
          () => repo.createClientWithId(any(), any()),
        ).thenThrow(Exception('boom'));

        final result = await vm.addClient(
          name: 'Bob',
          email: 'bob@example.com',
        );

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke tilføje klient'));
        expect(vm.saving, isFalse);
      },
    );
  });

  group('handleUploadImage', () {
    test(
      'returns existing URL when image is null and does not call storage',
      () async {
        final docRef = FakeDocumentRef('x');
        final result = await vm.handleUploadImage(null, 'existing-url', docRef);

        expect(result, 'existing-url');
        verifyNever(
          () => imageStorage.uploadClientImage(
            clientId: any(named: 'clientId'),
            image: any(named: 'image'),
          ),
        );
      },
    );

    test('uploads image and returns new URL when image is provided', () async {
      final docRef = FakeDocumentRef('y');
      when(
        () => imageStorage.uploadClientImage(
          clientId: any(named: 'clientId'),
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
        () => imageStorage.uploadClientImage(
          clientId: 'y',
          image: any(named: 'image'),
        ),
      ).called(1);
    });
  });

  group('updateClientFields & handleUpdateFields', () {
    test(
      'returns true and does not call repo when no changes provided',
      () async {
        final result = await vm.updateClientFields('id1');

        expect(result, isTrue);
        expect(vm.error, isNull);
        verifyNever(
          () => repo.updateClient(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        );
      },
    );

    test(
      'updates fields and deletes others, then caches updated client',
      () async {
        final original = const ClientModel(
          id: 'id1',
          name: 'Old',
          phone: '123',
          email: 'old@mail',
          address: 'A',
          city: 'C',
          postal: '1000',
          cvr: 'CVR',
          image: 'old-image',
        );
        cache.cacheClient(original);

        Map<String, Object?>? capturedFields;
        Set<String>? capturedDeletes;

        when(
          () => repo.updateClient(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((invocation) async {
          capturedFields =
              invocation.namedArguments[#fields] as Map<String, Object?>;
          capturedDeletes = invocation.namedArguments[#deletes] as Set<String>;
        });

        final result = await vm.updateClientFields(
          'id1',
          name: '  New Name  ',
          phone: ' ', // should be deleted
          email: '  new@mail ',
        );

        expect(result, isTrue);
        expect(vm.error, isNull);
        expect(capturedFields, isNotNull);
        expect(capturedDeletes, isNotNull);
        expect(capturedFields!['name'], 'New Name');
        expect(capturedFields!['email'], 'new@mail');
        expect(capturedDeletes, contains('phone'));

        final updated = cache.getClient('id1');
        expect(updated, isNotNull);
        expect(updated!.name, 'New Name');
        expect(updated.email, 'new@mail');
        expect(updated.phone, isNull);
        expect(updated.address, 'A');
        expect(updated.image, 'old-image');
      },
    );

    test(
      'uploads new image and updates cache when newImage is provided',
      () async {
        final original = const ClientModel(
          id: 'id1',
          name: 'HasImage',
          image: 'old',
        );
        cache.cacheClient(original);

        when(
          () => repo.updateClient(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.uploadClientImage(
            clientId: any(named: 'clientId'),
            image: any(named: 'image'),
          ),
        ).thenAnswer((_) async => 'new-image');

        final img = (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'pic.jpg',
          mimeType: 'image/jpeg',
        );

        final result = await vm.updateClientFields('id1', newImage: img);

        expect(result, isTrue);
        final updated = cache.getClient('id1');
        expect(updated, isNotNull);
        expect(updated!.image, 'new-image');
      },
    );

    test(
      'removes image and swallows delete errors when removeImage is true',
      () async {
        final original = const ClientModel(
          id: 'id1',
          name: 'HasImage',
          image: 'old-image',
        );
        cache.cacheClient(original);

        when(
          () => repo.updateClient(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.deleteClientImage(any()),
        ).thenThrow(Exception('missing'));

        final result = await vm.updateClientFields('id1', removeImage: true);

        expect(result, isTrue);
        final updated = cache.getClient('id1');
        expect(updated, isNotNull);
        expect(updated!.image, isNull);

        verify(() => imageStorage.deleteClientImage('id1')).called(1);
      },
    );

    test(
      'sets error and returns false when repo.updateClient throws',
      () async {
        cache.cacheClient(const ClientModel(id: 'id1', name: 'Old'));

        when(
          () => repo.updateClient(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenThrow(Exception('failure'));

        final result = await vm.updateClientFields('id1', name: 'New');

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke opdatere'));
        expect(vm.saving, isFalse);
      },
    );
  });

  group('cacheUpdatedClient', () {
    test('does nothing when client is not present in cache', () {
      // Should not throw
      vm.cacheUpdatedClient('missing', {}, {});
    });
  });

  group('delete', () {
    test(
      'deletes image if possible, swallows errors, removes from cache',
      () async {
        cache.cacheClient(const ClientModel(id: 'id1', name: 'ToDelete'));

        when(
          () => imageStorage.deleteClientImage(any()),
        ).thenThrow(Exception('missing'));
        when(() => repo.deleteClient(any())).thenAnswer((_) async {});

        await vm.delete('id1');

        verify(() => repo.deleteClient('id1')).called(1);
        expect(cache.getClient('id1'), isNull);
      },
    );
  });

  group('reset', () {
    test('resets query and lists and allows re-initialisation', () async {
      cache.cacheClient(const ClientModel(id: 'id1', name: 'Alice'));
      vm.setClientSearch('alice'); // sets _query and recomputes

      expect(vm.allClients, isNotEmpty);

      vm.reset();

      expect(vm.allClients, isEmpty);
      expect(vm.privateClients, isEmpty);
      expect(vm.businessClients, isEmpty);

      // After reset, initClientFilters should be allowed again.
      final controller = StreamController<List<ClientModel>>();
      when(() => repo.watchClients()).thenAnswer((_) => controller.stream);

      vm.initClientFilters();
      controller.add([const ClientModel(id: 'id2', name: 'Bob')]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.allClients.map((c) => c.id), ['id2']);

      await controller.close();
    });
  });
}
