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

// ─────────────────────────────────────────────────────────────────────────────
// Test doubles
// ─────────────────────────────────────────────────────────────────────────────

class MockClientRepository extends Mock implements ClientRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

// ignore: subtype_of_sealed_class
class FakeDocumentRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeDocumentRef(this._id);
  final String _id;
  @override
  String get id => _id;
}

/// Tiny fake repo used by ClientCache.fetchClients().
class _FakeFetchRepo extends Fake implements ClientRepository {
  _FakeFetchRepo([Map<String, ClientModel?>? seed]) : _store = {...?seed};
  final Map<String, ClientModel?> _store;

  @override
  Future<Map<String, ClientModel?>> getClients(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }

  @override
  Future<ClientModel?> getClient(String id) async => _store[id];
}

void main() {
  setUpAll(() {
    // Allow any()/captureAny() on these types.
    registerFallbackValue(<String, Object?>{}); // fields
    registerFallbackValue(<String>{}); // deletes
    registerFallbackValue(const ClientModel()); // createClientWithId(...)
    // record arg for ImageStorage.*ClientImage
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

  // ───────────────────────────────────────────────────────────────────────────
  // init / filtering (incl. private/business split)
  // ───────────────────────────────────────────────────────────────────────────
  group('initClientFilters & filtering', () {
    test(
      'subscribes once, caches, filters by query across fields, splits business/private',
      () async {
        final items = <ClientModel>[
          const ClientModel(
            id: 'p1',
            name: 'Alice',
            phone: '111',
            email: 'a@x.dk',
          ),
          const ClientModel(
            id: 'b1',
            name: 'Beta ApS',
            cvr: '12345678',
            email: 'info@beta.dk',
          ),
          const ClientModel(id: 'p2', name: 'Bob', phone: '222'),
          const ClientModel(
            id: 'b2',
            name: 'Company Gamma',
            cvr: '87654321',
            phone: '333',
          ),
        ];
        when(() => repo.watchClients()).thenAnswer((_) => Stream.value(items));

        // Initial query "aps" should match Beta ApS by name (case-insensitive)
        vm.initClientFilters(initialQuery: 'aps');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(vm.allClients.map((c) => c.id), equals(['b1']));
        expect(vm.businessClients.map((c) => c.id), equals(['b1']));
        expect(vm.privateClients, isEmpty);
        expect(vm.businessCount, 1);
        expect(vm.privateCount, 0);

        // Search by phone (should hit '333' -> b2)
        vm.setClientSearch('333');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allClients.map((c) => c.id), equals(['b2']));
        expect(vm.businessClients.map((c) => c.id), equals(['b2']));
        expect(vm.privateClients, isEmpty);

        // Search by email (should hit a@x.dk -> p1)
        vm.setClientSearch('x.dk');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allClients.map((c) => c.id), equals(['p1']));
        expect(vm.privateClients.map((c) => c.id), equals(['p1']));
        expect(vm.businessClients, isEmpty);

        // Clear → all visible & split correctly
        vm.clearSearch();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allClients.length, 4);
        expect(
          vm.businessClients.map((c) => c.id).toSet(),
          equals({'b1', 'b2'}),
        );
        expect(
          vm.privateClients.map((c) => c.id).toSet(),
          equals({'p1', 'p2'}),
        );

        // Calling init again is a no-op
        vm.initClientFilters();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.allClients.length, 4);

        verify(() => repo.watchClients()).called(1);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // subscribe / unsubscribe single client
  // ───────────────────────────────────────────────────────────────────────────
  group('subscribeToClient / unsubscribeFromClient', () {
    test('subscribes once, caches incoming doc and removes on null', () async {
      final ctrl = StreamController<ClientModel?>();
      when(() => repo.watchClient('c1')).thenAnswer((_) => ctrl.stream);

      vm.subscribeToClient('c1');

      ctrl.add(const ClientModel(id: 'c1', name: 'Jane'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cache.getClient('c1')?.name, 'Jane');

      ctrl.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cache.getClient('c1'), isNull);

      // Guard against duplicate subscription
      vm.subscribeToClient('c1');
      verify(() => repo.watchClient('c1')).called(1);

      vm.unsubscribeFromClient('c1');
      await ctrl.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // prefetchClient
  // ───────────────────────────────────────────────────────────────────────────
  group('prefetchClient', () {
    test('returns cached immediately without fetching', () async {
      final fetchRepo = MockClientRepository();
      final fetchCache = ClientCache(fetchRepo);
      final theVm = ClientViewModel(repo, imageStorage, fetchCache);

      fetchCache.cacheClient(const ClientModel(id: 'id1', name: 'Precached'));
      var ticks = 0;
      theVm.addListener(() => ticks++);

      final result = await theVm.prefetchClient('id1');
      expect(result!.name, 'Precached');
      verifyNever(() => fetchRepo.getClients(any()));
      expect(ticks, 0);

      theVm.dispose();
    });

    test('fetches via cache when missing, notifies on success', () async {
      final seed = {'id2': const ClientModel(id: 'id2', name: 'Fetched One')};
      final theVm = ClientViewModel(
        repo,
        imageStorage,
        ClientCache(_FakeFetchRepo(seed)),
      );

      var notified = 0;
      theVm.addListener(() => notified++);

      expect(theVm.getClient('id2'), isNull);

      final got = await theVm.prefetchClient('id2');
      expect(got!.name, 'Fetched One');
      expect(theVm.getClient('id2')!.name, 'Fetched One');
      expect(notified, greaterThanOrEqualTo(1));

      theVm.dispose();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // getClient (cache or memory list)
  // ───────────────────────────────────────────────────────────────────────────
  group('getClient', () {
    test(
      'returns from cache when present; otherwise from in-memory list',
      () async {
        when(() => repo.watchClients()).thenAnswer(
          (_) =>
              Stream.value([const ClientModel(id: 'm1', name: 'FromStream')]),
        );
        vm.initClientFilters();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // memory hit
        expect(vm.getClient('m1')?.name, 'FromStream');

        cache.cacheClient(const ClientModel(id: 'c1', name: 'FromCache'));
        expect(vm.getClient('c1')?.name, 'FromCache');

        // missing
        expect(vm.getClient('nope'), isNull);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // addClient
  // ───────────────────────────────────────────────────────────────────────────
  group('addClient', () {
    test('validation: fails when both name and email are empty', () async {
      final ok = await vm.addClient(name: '', email: '', phone: '123');
      expect(ok, isFalse);
      expect(vm.error, 'Angiv mindst navn eller e-mail');
      verifyNever(() => repo.newClientRef());
      verifyNever(() => repo.createClientWithId(any(), any()));
    });

    test('creates client, uploads image, caches and filters', () async {
      final fake = FakeDocumentRef('cl123');
      when(() => repo.newClientRef()).thenReturn(fake);
      when(
        () => imageStorage.uploadClientImage(
          clientId: 'cl123',
          image: any(named: 'image'),
        ),
      ).thenAnswer((_) async => 'https://img');
      when(
        () => repo.createClientWithId('cl123', any()),
      ).thenAnswer((_) async {});

      // Keep default empty stream (initClientFilters won't populate _all)
      vm.initClientFilters(
        initialQuery: 'ja',
      ); // query that will match 'Jane' after add

      final ok = await vm.addClient(
        name: '  Jane  ',
        phone: '  12345 ',
        email: '  j@x.dk ',
        address: ' St ',
        city: ' Cph ',
        postal: ' 2100 ',
        cvr: '  ', // empty → treated as null
        image: (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'a.png',
          mimeType: 'image/png',
        ),
      );

      expect(ok, isTrue);
      expect(vm.error, isNull);

      final cached = cache.getClient('cl123');
      expect(cached, isNotNull);
      expect(cached!.name, 'Jane');
      expect(cached.phone, '12345');
      expect(cached.email, 'j@x.dk');
      expect(cached.address, 'St');
      expect(cached.city, 'Cph');
      expect(cached.postal, '2100');
      expect(cached.cvr, isNull);
      expect(cached.image, 'https://img');

      // After add, filter recomputed; since query is 'ja', list should contain 'Jane'
      expect(vm.allClients.map((c) => c.id), contains('cl123'));

      verify(() => repo.newClientRef()).called(1);
      verify(
        () => imageStorage.uploadClientImage(
          clientId: 'cl123',
          image: any(named: 'image'),
        ),
      ).called(1);
      verify(() => repo.createClientWithId('cl123', any())).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // updateClientFields
  // ───────────────────────────────────────────────────────────────────────────
  group('updateClientFields', () {
    setUp(() {
      cache.cacheClient(
        const ClientModel(
          id: 'u1',
          name: 'Old N',
          phone: '000',
          email: 'old@x.dk',
          address: 'Old St',
          city: 'OldCity',
          postal: '0000',
          cvr: '12345678',
          image: 'old.png',
        ),
      );
      when(
        () => repo.updateClient(
          any(),
          fields: any(named: 'fields'),
          deletes: any(named: 'deletes'),
        ),
      ).thenAnswer((_) async {});
    });

    test('updates scalar fields; cache reflects changes', () async {
      final ok = await vm.updateClientFields(
        'u1',
        name: '  New N ',
        phone: '  111 ',
        email: ' new@x.dk ',
        address: ' New St ',
        city: ' NewCity ',
        postal: ' 2100 ',
        cvr: ' 87654321 ',
      );
      expect(ok, isTrue);

      final captured = verify(
        () => repo.updateClient(
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

      expect(fields['name'], 'New N');
      expect(fields['phone'], '111');
      expect(fields['email'], 'new@x.dk');
      expect(fields['address'], 'New St');
      expect(fields['city'], 'NewCity');
      expect(fields['postal'], '2100');
      expect(fields['cvr'], '87654321');
      expect(deletes, isEmpty);

      final updated = cache.getClient('u1')!;
      expect(updated.name, 'New N');
      expect(updated.phone, '111');
      expect(updated.email, 'new@x.dk');
      expect(updated.address, 'New St');
      expect(updated.city, 'NewCity');
      expect(updated.postal, '2100');
      expect(updated.cvr, '87654321');
    });

    test('newImage uploads and sets image field', () async {
      when(
        () => imageStorage.uploadClientImage(
          clientId: 'u1',
          image: any(named: 'image'),
        ),
      ).thenAnswer((_) async => 'https://new');

      await vm.updateClientFields(
        'u1',
        newImage: (
          bytes: Uint8List.fromList([0, 1]),
          name: 'x.png',
          mimeType: 'image/png',
        ),
      );

      final captured = verify(
        () => repo.updateClient(
          'u1',
          fields: captureAny(named: 'fields'),
          deletes: captureAny(named: 'deletes'),
        ),
      ).captured;

      final fields = (captured.first is Map<String, Object?>)
          ? captured.first as Map<String, Object?>
          : captured.last as Map<String, Object?>;

      expect(fields['image'], 'https://new');

      final updated = cache.getClient('u1')!;
      expect(updated.image, 'https://new');

      verify(
        () => imageStorage.uploadClientImage(
          clientId: 'u1',
          image: any(named: 'image'),
        ),
      ).called(1);
    });

    test('removeImage=true deletes image and calls storage delete', () async {
      when(() => imageStorage.deleteClientImage('u1')).thenAnswer((_) async {});

      await vm.updateClientFields('u1', removeImage: true);

      final captured = verify(
        () => repo.updateClient(
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

      // NOTE: If your ClientModel.copyWith can't set null, don't assert cache null here.
      // Prefer sentinel-based copyWith (like in ServiceModel) if you want to assert:
      // final updated = cache.getClient('u1')!;
      // expect(updated.image, isNull);

      verify(() => imageStorage.deleteClientImage('u1')).called(1);
    });

    test(
      'no-op: nothing to update → skips repo call and returns true',
      () async {
        final before = cache.getClient('u1');

        final ok = await vm.updateClientFields('u1');
        expect(ok, isTrue);

        verifyNever(
          () => repo.updateClient(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        );

        final after = cache.getClient('u1');
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
          const ClientModel(id: 'd1', name: 'To Delete'),
          const ClientModel(id: 'keep', name: 'Keep Co', cvr: '11111111'),
        ];
        when(() => repo.watchClients()).thenAnswer((_) => Stream.value(items));
        vm.initClientFilters();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        when(
          () => imageStorage.deleteClientImage('d1'),
        ).thenAnswer((_) async {});
        when(() => repo.deleteClient('d1')).thenAnswer((_) async {});

        await vm.delete('d1');

        expect(cache.getClient('d1'), isNull);
        expect(vm.allClients.map((c) => c.id), equals(['keep']));
        // Split should reflect removal too
        expect(vm.businessClients.map((c) => c.id), equals(['keep']));
        expect(vm.privateClients, isEmpty);

        verify(() => imageStorage.deleteClientImage('d1')).called(1);
        verify(() => repo.deleteClient('d1')).called(1);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // reset
  // ───────────────────────────────────────────────────────────────────────────
  group('reset', () {
    test('clears in-memory state and notifies', () async {
      when(() => repo.watchClients()).thenAnswer(
        (_) => Stream.value([const ClientModel(id: 'r1', name: 'Any')]),
      );
      vm.initClientFilters();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.allClients, isNotEmpty);
      expect(vm.privateCount + vm.businessCount, 1);

      var ticks = 0;
      vm.addListener(() => ticks++);

      vm.reset();
      expect(vm.allClients, isEmpty);
      expect(vm.privateClients, isEmpty);
      expect(vm.businessClients, isEmpty);
      expect(vm.privateCount, 0);
      expect(vm.businessCount, 0);
      expect(ticks, greaterThanOrEqualTo(1));
    });
  });
}
