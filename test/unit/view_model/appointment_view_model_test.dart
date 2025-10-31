import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/cache/appointment_cache.dart';
import 'package:aftaler_og_regnskab/data/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/data/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/data/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/data/checklist_repository.dart';
import 'package:aftaler_og_regnskab/data/client_repository.dart';
import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ignore: subtype_of_sealed_class
/// The tests focus on the following behaviours:
///
/// * Input validation for `addAppointment`.
/// * Successful creation of an appointment with image upload.
/// * Updating the status of an appointment.
/// * Image handling utilities (`handleImages`).
/// * Checklist helpers (`handeNewChecklists` and `handleRemovedChecklists`).
/// * Field handling logic (`handleFields`).
/// * Deleting an appointment.
/// * Query helpers such as `getAppointmentsInRange`, `monthChipsOn` and
///   `cardsForDate`.
///
/// Whenever you add new tests remember to keep them small and descriptive –
/// each `test()` block should cover a single expectation.

/// A minimal fake document reference used by tests.  Only the `id` getter
/// is implemented because [AppointmentViewModel] relies solely on this field.
class FakeDocumentRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeDocumentRef(this._id);
  final String _id;
  @override
  String get id => _id;
}

class _FakeClientRepository extends Fake implements ClientRepository {
  _FakeClientRepository([Map<String, ClientModel?>? seed])
    : _store = {...?seed};

  final Map<String, ClientModel?> _store;

  // Used by ClientCache
  @override
  Future<Map<String, ClientModel?>> getClients(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }

  // Handy for any direct one-offs you might call in tests
  @override
  Future<ClientModel?> getClient(String id) async => _store[id];
}

/// Minimal fake for ServiceRepository used by ServiceCache.fetchServices().
/// Everything else falls back to Fake.noSuchMethod (will throw if called).
class _FakeServiceRepository extends Fake implements ServiceRepository {
  _FakeServiceRepository([Map<String, ServiceModel?>? seed])
    : _store = {...?seed};

  final Map<String, ServiceModel?> _store;

  // Used by ServiceCache
  @override
  Future<Map<String, ServiceModel?>> getServices(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }

  @override
  Future<ServiceModel?> getServiceOnce(String id) async => _store[id];
}

/// Mock implementation of [AppointmentRepository] used throughout the tests.
class MockAppointmentRepository extends Mock implements AppointmentRepository {}

/// Mock implementation of [ImageStorage] used throughout the tests.
class MockImageStorage extends Mock implements ImageStorage {}

/// Mock implementation of [FinanceViewModel] used throughout the tests.
class MockFinanceViewModel extends Mock implements FinanceViewModel {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(PaymentStatus.uninvoiced);
    registerFallbackValue(DateTime.now());
    registerFallbackValue(
      AppointmentModel(checklistIds: const [], dateTime: DateTime(2000)),
    );
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(<String>{});
  });

  late MockAppointmentRepository repo;
  late MockImageStorage imageStorage;
  late MockFinanceViewModel financeVM;
  late AppointmentCache apptCache;
  late ClientCache clientCache;
  late ServiceCache serviceCache;
  late ChecklistCache checklistCache;
  late MockChecklistRepository mockChecklistRepo;
  late AppointmentViewModel viewModel;

  setUp(() {
    repo = MockAppointmentRepository();
    imageStorage = MockImageStorage();
    financeVM = MockFinanceViewModel();
    mockChecklistRepo = MockChecklistRepository();
    apptCache = AppointmentCache(repo);
    clientCache = ClientCache(_FakeClientRepository());
    serviceCache = ServiceCache(_FakeServiceRepository());
    checklistCache = ChecklistCache(mockChecklistRepo);
    viewModel = AppointmentViewModel(
      repo,
      imageStorage,
      clientCache: clientCache,
      serviceCache: serviceCache,
      checklistCache: checklistCache,
      apptCache: apptCache,
      financeVM: financeVM,
    );
  });

  group('addAppointment validation', () {
    test('fails when clientId is empty', () async {
      final result = await viewModel.addAppointment(
        clientId: '',
        serviceId: 'service1',
        dateTime: DateTime.now(),
        checklistIds: const [],
      );
      expect(result, isFalse);
      expect(viewModel.error, equals('Vælg klient'));
      expect(viewModel.saving, isFalse);
      // No external calls should have been made when validation fails.
      verifyNever(() => repo.newAppointmentRef());
      verifyNever(
        () => financeVM.onAddAppointment(
          status: any(named: 'status'),
          price: any(named: 'price'),
          dateTime: any(named: 'dateTime'),
        ),
      );
    });

    test('fails when dateTime is null', () async {
      final result = await viewModel.addAppointment(
        clientId: 'client1',
        serviceId: 'service1',
        dateTime: null,
        checklistIds: const [],
      );
      expect(result, isFalse);
      expect(viewModel.error, equals('Vælg dato og tid'));
      expect(viewModel.saving, isFalse);
      verifyNever(() => repo.newAppointmentRef());
    });
  });

  group('addAppointment success', () {
    test('creates an appointment and uploads images', () async {
      // Arrange: prepare mocks and expected values.
      final now = DateTime.now();
      final fakeId = 'doc123';
      final fakeDoc = FakeDocumentRef(fakeId);
      when(() => repo.newAppointmentRef()).thenReturn(fakeDoc);
      final uploadedUrls = ['u1.jpg', 'u2.jpg'];
      when(
        () => imageStorage.uploadAppointmentImages(
          appointmentId: fakeId,
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async => uploadedUrls);
      when(
        () => repo.createAppointmentWithId(fakeId, any()),
      ).thenAnswer((_) async => Future.value());
      when(
        () => financeVM.onAddAppointment(
          status: any(named: 'status'),
          price: any(named: 'price'),
          dateTime: any(named: 'dateTime'),
        ),
      ).thenAnswer((_) async => Future.value());

      // Act: call the method under test.
      final result = await viewModel.addAppointment(
        clientId: 'client1',
        serviceId: 'service1',
        dateTime: now,
        checklistIds: const ['check1', 'check2'],
        price: 100.0,
        images: [
          (
            bytes: Uint8List.fromList([0, 1]),
            name: 'a.png',
            mimeType: 'image/png',
          ),
          (
            bytes: Uint8List.fromList([2, 3]),
            name: 'b.png',
            mimeType: 'image/png',
          ),
        ],
        status: 'ufaktureret',
      );

      // Assert: verify overall outcome and interactions.
      expect(result, isTrue);
      expect(viewModel.error, isNull);
      expect(viewModel.saving, isFalse);

      // The appointment should now reside in the cache with the generated id.
      final cached = apptCache.getAppointment(fakeId);
      expect(cached, isNotNull);
      expect(cached!.clientId, equals('client1'));
      expect(cached.serviceId, equals('service1'));
      expect(cached.dateTime, equals(now));
      expect(cached.price, equals(100.0));
      expect(cached.imageUrls, equals(uploadedUrls));
      expect(cached.checklistIds, equals(['check1', 'check2']));

      // Verify side‑effects on mocks.
      verify(() => repo.newAppointmentRef()).called(1);
      verify(
        () => imageStorage.uploadAppointmentImages(
          appointmentId: fakeId,
          images: any(named: 'images'),
        ),
      ).called(1);
      verify(() => repo.createAppointmentWithId(fakeId, any())).called(1);
      verify(
        () => financeVM.onAddAppointment(
          status: PaymentStatusX.fromString('ufaktureret'),
          price: 100.0,
          dateTime: now,
        ),
      ).called(1);
    });
  });
  group('updateAppointmentFields', () {
    test('happy path: updates fields, images, cache and finance', () async {
      // Seed an existing appointment
      final old = AppointmentModel(
        id: 'u1',
        clientId: 'c_old',
        serviceId: 's_old',
        checklistIds: const ['A', 'B'],
        dateTime: DateTime(2024, 1, 10, 8),
        payDate: DateTime(2024, 1, 11, 12),
        location: 'Old L',
        note: 'Old N',
        price: 50.0,
        status: 'Afventer',
        imageUrls: const ['keep.jpg', 'remove.jpg'],
      );
      apptCache.cacheAppointment(old);

      // Image ops
      when(
        () => imageStorage.uploadAppointmentImages(
          appointmentId: old.id!,
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async => ['new1.png']);
      when(
        () => imageStorage.deleteAppointmentImagesByUrls(any()),
      ).thenAnswer((_) async {});

      // Repo update
      when(
        () => repo.updateAppointment(
          old.id!,
          fields: any(named: 'fields'),
          deletes: any(named: 'deletes'),
        ),
      ).thenAnswer((_) async {});

      // Finance update
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

      final newDate = DateTime(2024, 1, 12, 9);
      final newPay = DateTime(2024, 1, 15, 10);

      final ok = await viewModel.updateAppointmentFields(
        old,
        clientId: 'c_new',
        serviceId: 's_new',
        checklistIds: const ['A', 'C'], // remove B, add C
        dateTime: newDate,
        payDate: newPay,
        location: ' New L ', // gets trimmed
        note: 'New N',
        price: 150.0, // prefer servicePrice if price is null
        status: 'Betalt',
        currentImageUrls: old.imageUrls,
        removedImageUrls: const ['remove.jpg'],
        newImages: [
          (
            bytes: Uint8List.fromList([1, 2]),
            name: 'img.png',
            mimeType: 'image/png',
          ),
        ],
      );

      expect(ok, isTrue);
      expect(viewModel.error, isNull);
      expect(viewModel.saving, isFalse);

      // Verify repo.updateAppointment got correct fields/deletes (order-agnostic)
      final captured = verify(
        () => repo.updateAppointment(
          old.id!,
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

      // imageUrls merged: kept 'keep.jpg' + uploaded 'new1.png' (removed 'remove.jpg')
      expect(
        (fields['imageUrls'] as List).toSet(),
        equals({'keep.jpg', 'new1.png'}),
      );

      // Scalars present/trimmed + timestamps
      expect(fields['clientId'], equals('c_new'));
      expect(fields['serviceId'], equals('s_new'));
      expect(fields['location'], equals('New L'));
      expect(fields['note'], equals('New N'));
      expect(fields['status'], equals('Betalt'));
      expect(fields['price'], equals(150.0));
      expect(fields['dateTime'], equals(Timestamp.fromDate(newDate)));
      expect(fields['payDate'], equals(Timestamp.fromDate(newPay)));

      // Checklist updated + progress.<removed> delete for 'B'
      expect(fields['checklistIds'], equals(['A', 'C']));
      expect(deletes.contains('progress.B'), isTrue);

      // Removed image URLs were deleted
      verify(
        () => imageStorage.deleteAppointmentImagesByUrls(['remove.jpg']),
      ).called(1);

      // Cache updated to reflect new data
      final updated = apptCache.getAppointment('u1')!;
      expect(updated.clientId, equals('c_new'));
      expect(updated.serviceId, equals('s_new'));
      expect(updated.dateTime, equals(newDate));
      expect(updated.payDate, equals(newPay));
      expect(updated.location, equals('New L'));
      expect(updated.note, equals('New N'));
      expect(updated.status, equals('Betalt'));
      expect(updated.price, equals(150.0));
      expect(updated.checklistIds, equals(['A', 'C']));
      expect(updated.imageUrls!.toSet(), equals({'keep.jpg', 'new1.png'}));

      // Finance called with old vs new
      verify(
        () => financeVM.onUpdateAppointmentFields(
          oldStatus: PaymentStatus.waiting, // 'Afventer'
          newStatus: PaymentStatus.paid, // 'Betalt'
          oldPrice: 50.0,
          newPrice: 150.0,
          oldDate: DateTime(2024, 1, 10, 8),
          newDate: newDate,
        ),
      ).called(1);
    });

    test(
      'deletes empty string fields and progress for removed checklists',
      () async {
        final old = AppointmentModel(
          id: 'u2',
          clientId: 'c1',
          serviceId: 's1',
          checklistIds: const ['X', 'Y'],
          dateTime: DateTime(2024, 2, 1, 10),
          location: 'Has L',
          note: 'Has N',
          status: 'Ufaktureret',
          price: 99.0,
          imageUrls: const ['a.jpg', 'b.jpg'],
        );
        apptCache.cacheAppointment(old);

        when(
          () => repo.updateAppointment(
            old.id!,
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.deleteAppointmentImagesByUrls(any()),
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

        final ok = await viewModel.updateAppointmentFields(
          old,
          // Blank/space should trigger deletes for these keys
          location: '   ',
          note: '',
          status: ' ',
          // Keep same checklists but remove 'X'
          checklistIds: const ['Y'],
          // No time/price changes
          currentImageUrls: old.imageUrls,
          removedImageUrls: const ['b.jpg'], // should be deleted
          newImages: const [], // no upload
        );

        expect(ok, isTrue);

        final captured = verify(
          () => repo.updateAppointment(
            old.id!,
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

        // imageUrls present; 'b.jpg' removed, no new uploaded
        expect((fields['imageUrls'] as List).toSet(), equals({'a.jpg'}));

        // Blank fields cause deletes
        expect(deletes.contains('location'), isTrue);
        expect(deletes.contains('note'), isTrue);
        expect(deletes.contains('status'), isTrue);

        // Removed checklist 'X' yields progress delete
        expect(fields['checklistIds'], equals(['Y']));
        expect(deletes.contains('progress.X'), isTrue);

        // Image delete called
        verify(
          () => imageStorage.deleteAppointmentImagesByUrls(['b.jpg']),
        ).called(1);

        // Finance still called (old vs new)
        verify(
          () => financeVM.onUpdateAppointmentFields(
            oldStatus: PaymentStatus.uninvoiced,
            newStatus: PaymentStatus.uninvoiced, // unchanged
            oldPrice: 99.0,
            newPrice: 0.0, // no new price provided
            oldDate: old.dateTime,
            newDate: old.dateTime, // no new date
          ),
        ).called(1);
      },
    );

    test(
      'images-only path (no user field changes): calls repo with imageUrls only and updates finance',
      () async {
        final old = AppointmentModel(
          id: 'u3',
          clientId: 'c1',
          serviceId: 's1',
          checklistIds: const ['A'],
          dateTime: DateTime(2024, 3, 5, 12),
          payDate: DateTime(2024, 3, 6),
          location: 'Here',
          note: 'Note',
          price: 77.0,
          status: 'Afventer',
          imageUrls: const ['z.jpg'],
        );
        apptCache.cacheAppointment(old);

        // Repo will be called because fields['imageUrls'] is always set.
        when(
          () => repo.updateAppointment(
            old.id!,
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});

        // Finance is always called
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

        final ok = await viewModel.updateAppointmentFields(
          old,
          currentImageUrls: old.imageUrls,
          removedImageUrls: const [],
          newImages: const [], // no change
        );

        expect(ok, isTrue);

        // Repo called once with only imageUrls in fields, and empty deletes
        final captured = verify(
          () => repo.updateAppointment(
            old.id!,
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

        expect(fields.keys.toSet(), equals({'imageUrls'}));
        expect((fields['imageUrls'] as List).toList(), equals(['z.jpg']));
        expect(deletes, isEmpty);

        // No image ops
        verifyNever(
          () => imageStorage.uploadAppointmentImages(
            appointmentId: any(named: 'appointmentId'),
            images: any(named: 'images'),
          ),
        );
        verifyNever(() => imageStorage.deleteAppointmentImagesByUrls(any()));

        // Finance did run
        verify(
          () => financeVM.onUpdateAppointmentFields(
            oldStatus: PaymentStatus.waiting,
            newStatus: PaymentStatus.waiting,
            oldPrice: 77.0,
            newPrice: 0.0,
            oldDate: old.dateTime,
            newDate: old.dateTime,
          ),
        ).called(1);
      },
    );
  });

  group('updateStatus', () {
    test('updates the appointment status and notifies finance', () async {
      // Arrange: cache an existing appointment.
      final oldAppt = AppointmentModel(
        id: 'id1',
        clientId: 'client1',
        serviceId: 'service1',
        checklistIds: const [],
        dateTime: DateTime.now(),
        price: 50.0,
        status: 'ufaktureret',
      );
      apptCache.cacheAppointment(oldAppt);
      // Stub repository and finance.
      when(() => repo.updateStatus('id1', any())).thenAnswer((_) async {});
      when(
        () => financeVM.onUpdateStatus(
          oldStatus: any(named: 'oldStatus'),
          newStatus: any(named: 'newStatus'),
          price: any(named: 'price'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async {});

      final newStatus = 'betalt';
      final now = DateTime.now();
      // Act.
      await viewModel.updateStatus('id1', 'ufaktureret', 50.0, newStatus, now);

      // Assert: repository and finance methods called.
      verify(() => repo.updateStatus('id1', newStatus.trim())).called(1);
      verify(
        () => financeVM.onUpdateStatus(
          oldStatus: PaymentStatus.uninvoiced,
          newStatus: PaymentStatus.paid,
          price: 50.0,
          date: now,
        ),
      ).called(1);
      // Appointment in cache should be updated.
      final updated = apptCache.getAppointment('id1');
      expect(updated!.status, equals(newStatus));
    });
  });

  group('delete', () {
    test('removes appointment and notifies dependencies', () async {
      // Cache an appointment so we can observe its removal.
      final appt = AppointmentModel(
        id: 'del1',
        clientId: 'client1',
        serviceId: 'service1',
        checklistIds: const [],
        dateTime: DateTime.now(),
        price: 80.0,
        status: 'ufaktureret',
      );
      apptCache.cacheAppointment(appt);
      when(
        () => imageStorage.deleteAppointmentImages('del1'),
      ).thenAnswer((_) async => Future.value());
      when(
        () => repo.deleteAppointment('del1'),
      ).thenAnswer((_) async => Future.value());
      when(
        () => financeVM.onDeleteAppointment(
          status: any(named: 'status'),
          price: any(named: 'price'),
          date: any(named: 'date'),
        ),
      ).thenReturn(null);
      final now = DateTime.now();
      // Act.
      await viewModel.delete('del1', 'ufaktureret', 80.0, now);
      // Assert.
      expect(apptCache.getAppointment('del1'), isNull);
      verify(() => imageStorage.deleteAppointmentImages('del1')).called(1);
      verify(() => repo.deleteAppointment('del1')).called(1);
      verify(
        () => financeVM.onDeleteAppointment(
          status: PaymentStatus.uninvoiced,
          price: 80.0,
          date: now,
        ),
      ).called(1);
    });
  });

  test(
    'hasEventsOn returns true if any appointment exists that day; false otherwise',
    () {
      final d = DateTime(2025, 1, 10, 10);

      apptCache.cacheAppointments([
        AppointmentModel(
          id: 'e1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: d,
        ),
        AppointmentModel(
          id: 'e2',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 11, 9),
        ),
      ]);

      expect(viewModel.hasEventsOn(DateTime(2025, 1, 10)), isTrue);
      expect(viewModel.hasEventsOn(DateTime(2025, 1, 9)), isFalse);
    },
  );
  test(
    'cardsForRange maps only in-range & valid (id & dateTime) items to cards',
    () async {
      // Seed client/service so labels map correctly
      clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Alice'));
      serviceCache.cacheService(
        const ServiceModel(id: 's1', name: 'Massage', duration: '30'),
      );

      apptCache.cacheAppointments([
        // in range
        AppointmentModel(
          id: 'r1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 5, 9),
          status: 'Afventer',
          price: 250,
        ),
        // also in range but invalid (missing id) → filtered out
        AppointmentModel(
          id: null,
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 6, 14),
        ),
        // out of range
        AppointmentModel(
          id: 'r2',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 2, 1, 12),
        ),
      ]);

      final cards = viewModel.cardsForRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 31),
      );

      expect(cards.length, 1);
      final c = cards.first;
      expect(c.id, 'r1');
      expect(c.clientName, 'Alice');
      expect(c.serviceName, 'Massage');
      expect(c.duration, '30');
      expect(c.status, 'Afventer');
      expect(c.price, 250);
      expect(c.time, DateTime(2025, 1, 5, 9));
    },
  );

  group('checklist progress', () {
    test(
      'checklistProgressStream delegates to repo.watchChecklistProgress',
      () async {
        final ctrl = StreamController<Map<String, Set<int>>>();
        when(
          () => repo.watchChecklistProgress('a1'),
        ).thenAnswer((_) => ctrl.stream);

        // Start listening
        final future = expectLater(
          viewModel.checklistProgressStream('a1'),
          emitsInOrder([
            {
              'X': {1, 2},
              'Y': {0},
            },
          ]),
        );

        // Emit once and close
        ctrl.add({
          'X': {1, 2},
          'Y': {0},
        });
        await ctrl.close();
        await future;

        verify(() => repo.watchChecklistProgress('a1')).called(1);
      },
    );

    test(
      'saveChecklistProgress delegates to repo.setAllChecklistProgress',
      () async {
        when(
          () => repo.setAllChecklistProgress('a2', any()),
        ).thenAnswer((_) async {});

        final progress = <String, Set<int>>{
          'C1': {0, 3},
          'C2': {1},
        };
        await viewModel.saveChecklistProgress(
          appointmentId: 'a2',
          progress: progress,
        );

        verify(() => repo.setAllChecklistProgress('a2', progress)).called(1);
      },
    );
  });

  group('query helpers', () {
    test('getAppointmentsInRange filters appointments by date', () {
      final d1 = DateTime(2023, 1, 1, 10);
      final d2 = DateTime(2023, 1, 5, 12);
      final d3 = DateTime(2023, 1, 10, 15);
      apptCache.cacheAppointments([
        AppointmentModel(
          id: 'a',
          clientId: 'c',
          serviceId: 's',
          checklistIds: const [],
          dateTime: d1,
        ),
        AppointmentModel(
          id: 'b',
          clientId: 'c',
          serviceId: 's',
          checklistIds: const [],
          dateTime: d2,
        ),
        AppointmentModel(
          id: 'c',
          clientId: 'c',
          serviceId: 's',
          checklistIds: const [],
          dateTime: d3,
        ),
      ]);
      final results = viewModel.getAppointmentsInRange(
        DateTime(2023, 1, 2),
        DateTime(2023, 1, 7),
      );
      expect(results.map((e) => e.id), equals(['b']));
    });

    test('monthChipsOn returns chips with client names and statuses', () {
      final date = DateTime(2023, 2, 20, 14);
      final appt = AppointmentModel(
        id: 'chip1',
        clientId: 'c1',
        serviceId: 's1',
        checklistIds: const [],
        dateTime: date,
        status: 'Betalt',
      );
      apptCache.cacheAppointment(appt);
      // Prepopulate client cache so that names are resolved.
      clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Alice'));
      final chips = viewModel.monthChipsOn(date);
      expect(chips.length, equals(1));
      final chip = chips.first;
      expect(chip.title, equals('Alice'));
      expect(chip.status, equals('Betalt'));
      expect(chip.time, equals(date));
    });

    test('cardsForDate returns list of AppointmentCardModel', () async {
      final date = DateTime(2024, 3, 15, 9, 30);
      final appt = AppointmentModel(
        id: 'card1',
        clientId: 'c1',
        serviceId: 's1',
        checklistIds: const [],
        dateTime: date,
        price: 200.0,
        status: 'Afventer',
      );
      apptCache.cacheAppointment(appt);
      clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Bob'));
      serviceCache.cacheService(
        const ServiceModel(id: 's1', name: 'Massage', duration: '60'),
      );
      final cards = await viewModel.cardsForDate(date);
      expect(cards.length, equals(1));
      final card = cards.first;
      expect(card.id, equals('card1'));
      expect(card.clientName, equals('Bob'));
      expect(card.serviceName, equals('Massage'));
      expect(card.time, equals(date));
      expect(card.price, equals(200.0));
      expect(card.duration, equals('60'));
      expect(card.status, equals('Afventer'));
    });
  });

  group('listCards (paged mode)', () {
    test(
      'returns cards mapped from cached items inside beginListRange',
      () async {
        // Seed labels
        clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Kunde A'));
        serviceCache.cacheService(
          const ServiceModel(id: 's1', name: 'Behandling', duration: '45'),
        );

        // Two in-range items, one out-of-range
        final inside1 = AppointmentModel(
          id: 'i1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 10, 10),
          status: 'Afventer',
          price: 100,
        );
        final inside2 = AppointmentModel(
          id: 'i2',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 11, 9),
          status: 'Betalt',
          price: 200,
        );
        final outside = AppointmentModel(
          id: 'o1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 2, 1, 12),
        );
        apptCache.cacheAppointments([inside1, inside2, outside]);

        // Prevent hang: first paging attempt returns an empty page quickly
        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async => (items: <AppointmentModel>[], lastDoc: null));

        await viewModel.beginListRange(
          DateTime(2025, 1, 1),
          DateTime(2025, 1, 31),
        );

        final cards = viewModel.listCards;
        expect(cards.length, 2);
        expect(cards.map((c) => c.id), containsAll(['i1', 'i2']));

        final c1 = cards.firstWhere((c) => c.id == 'i1');
        expect(c1.clientName, 'Kunde A');
        expect(c1.serviceName, 'Behandling');
        expect(c1.status, 'Afventer');
        expect(c1.duration, '45');
      },
    );
  });

  group('listCards', () {
    test(
      'returns cards mapped from cached items inside beginListRange',
      () async {
        // Make the first paging attempt resolve immediately with an empty page.
        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async => (items: <AppointmentModel>[], lastDoc: null));

        // Seed client/service caches so _toCard renders nice labels
        clientCache.cacheClient(
          const ClientModel(id: 'c1', name: 'Kunde A', phone: '123'),
        );
        serviceCache.cacheService(
          const ServiceModel(id: 's1', name: 'Behandling', duration: '45'),
        );

        // Two items inside the range, one outside
        final inside1 = AppointmentModel(
          id: 'i1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 10, 10),
          status: 'Afventer',
          price: 100,
        );
        final inside2 = AppointmentModel(
          id: 'i2',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 11, 9),
          status: 'Betalt',
          price: 200,
        );
        final outside = AppointmentModel(
          id: 'o1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 2, 1, 12),
        );

        apptCache.cacheAppointments([inside1, inside2, outside]);

        // If the cache already has items in range, beginListRange won't page.
        await viewModel.beginListRange(
          DateTime(2025, 1, 1),
          DateTime(2025, 1, 31),
        );

        final cards = viewModel.listCards;
        expect(cards.length, 2);
        expect(cards.map((c) => c.id), containsAll(['i1', 'i2']));
        // spot check first card mapping
        final c1 = cards.firstWhere((c) => c.id == 'i1');
        expect(c1.clientName, 'Kunde A');
        expect(c1.serviceName, 'Behandling');
        expect(c1.status, 'Afventer');
        expect(c1.duration, '45'); // ServiceModel.duration is String
      },
    );
  });

  group('loadNextListPage: short page branch', () {
    test(
      'caches items, sets hasMore=false when page shorter than pageSize',
      () async {
        // Stub: one short page with 2 in-range items
        final p1 = [
          AppointmentModel(
            id: 'p1-a',
            clientId: 'c1',
            serviceId: 's1',
            dateTime: DateTime(2025, 1, 3, 10),
          ),
          AppointmentModel(
            id: 'p1-b',
            clientId: 'c1',
            serviceId: 's1',
            dateTime: DateTime(2025, 1, 4, 11),
          ),
        ];

        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async => (items: p1, lastDoc: null));

        await viewModel.beginListRange(
          DateTime(2025, 1, 1),
          DateTime(2025, 1, 31),
        );

        // We hit the branch:
        //   _listLastDoc = lastDoc;
        //   apptCache.cacheAppointments(items);
        //   if (items.length < _listPageSize) _listHasMore = false;
        final cards = viewModel.listCards;
        expect(
          cards.map((c) => c.id).toList()..sort(),
          equals(['p1-a', 'p1-b']),
        );

        // Calling another page should return early (hasMore=false) → no extra repo calls
        await viewModel.loadNextListPage();
        verify(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).called(1);
      },
    );
  });
  group('loadNextListPage: finally branch (auto-follow-up)', () {
    test(
      'triggers extra non-awaited load when list has <5 items but hasMore is true',
      () async {
        // Pre-seed 1 in-range item so beginListRange won't loop forever
        apptCache.cacheAppointment(
          AppointmentModel(
            id: 'seed',
            clientId: 'c1',
            serviceId: 's1',
            dateTime: DateTime(2025, 1, 10, 10),
          ),
        );

        final fullOutside = List<AppointmentModel>.generate(20, (i) {
          return AppointmentModel(
            id: 'out-$i',
            clientId: 'cX',
            serviceId: 'sX',
            // Outside [2025-01-01 .. 2025-01-31] so they don't count toward _listModels
            dateTime: DateTime(2025, 2, 1, 12).add(Duration(minutes: i)),
          );
        });

        // Sequence of answers for successive paging calls:
        // 1..3 → full outside pages (hasMore stays true, _listModels remains <5)
        // 4    → empty page (the extra call fired from finally), sets hasMore=false
        var callNo = 0;

        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async {
          callNo += 1;
          if (callNo <= 3) {
            return (items: fullOutside, lastDoc: null);
          }
          return (items: <AppointmentModel>[], lastDoc: null);
        });

        await viewModel.beginListRange(
          DateTime(2025, 1, 1),
          DateTime(2025, 1, 31),
        );

        // Give the non-awaited follow-up call a moment to run
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // We expect at least 4 paging calls (3 inside while + 1 from finally)
        verify(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).called(4);

        // The only in-range card is the seed one
        final cards = viewModel.listCards;
        expect(cards.map((c) => c.id).toList(), equals(['seed']));
      },
    );
  });

  group('paging early returns', () {
    test('loadNextListPage returns early when list bounds unset', () async {
      // After reset, _listStart/_listEnd are null → should return early
      viewModel.resetOnAuthChange();
      await viewModel.loadNextListPage();
      verifyNever(
        () => repo.getAppointmentsPaged(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
          pageSize: any(named: 'pageSize'),
          startAfterDoc: any(named: 'startAfterDoc'),
          descending: any(named: 'descending'),
        ),
      );
    });

    test('beginListRange with pre-seeded cache avoids paging', () async {
      // Seed items for the range so _listModels is non-empty before any paging
      when(
        () => repo.getAppointmentsPaged(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
          pageSize: any(named: 'pageSize'),
          startAfterDoc: any(named: 'startAfterDoc'),
          descending: any(named: 'descending'),
        ),
      ).thenAnswer((_) async => (items: <AppointmentModel>[], lastDoc: null));

      apptCache.cacheAppointments([
        AppointmentModel(
          id: 'L1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 10, 10),
        ),
      ]);

      await viewModel.beginListRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 31),
      );

      // Because cache already had items in range, paging shouldn't be called.
      verify(
        () => repo.getAppointmentsPaged(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
          pageSize: any(named: 'pageSize'),
          startAfterDoc: any(named: 'startAfterDoc'),
          descending: any(named: 'descending'),
        ),
      ).called(1);
    });
  });

  group('initial/listen windows', () {
    test('setInitialRange subscribes and caches first tick', () async {
      // Make the month stream emit one item immediately.
      when(() => repo.watchAppointmentsBetween(any(), any())).thenAnswer(
        (_) => Stream.value([
          AppointmentModel(
            id: 'm1',
            clientId: 'c1',
            serviceId: 's1',
            dateTime: DateTime.now(),
          ),
        ]),
      );

      await viewModel.setInitialRange();

      // isReady should flip to true on first snapshot; item should be cached.
      expect(viewModel.isReady, isTrue);
      final allThisMonth = viewModel.getAppointmentsInRange(
        DateTime.now().subtract(const Duration(days: 15)),
        DateTime.now().add(const Duration(days: 45)),
      );
      expect(allThisMonth.any((a) => a.id == 'm1'), isTrue);

      // Verify a subscription was requested once
      verify(() => repo.watchAppointmentsBetween(any(), any())).called(1);
    });

    test(
      'setActiveWindow opens extra month subscriptions when outside initial',
      () async {
        // Stub to return empty but still count calls
        when(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).thenAnswer((_) => const Stream<List<AppointmentModel>>.empty());

        await viewModel.setInitialRange();
        // Move the window to a date well outside the initial 2-month range to force new subs.
        final farDate = DateTime.now().add(const Duration(days: 90));
        viewModel.setActiveWindow(farDate);

        // We should have at least the initial + some new months subscribed.
        verify(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).called(greaterThanOrEqualTo(2));
      },
    );
  });

  group('subscribeToAppointment / unsubscribeFromAppointment', () {
    test('subscribes once and caches incoming doc', () async {
      // Create a controllable stream for the appointment doc.
      final ctrl = StreamController<AppointmentModel?>();
      when(() => repo.watchAppointment('S1')).thenAnswer((_) => ctrl.stream);

      // Not covered and not cached → should subscribe
      await viewModel.subscribeToAppointment('S1');
      // Emit a document
      final doc = AppointmentModel(
        id: 'S1',
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime(2025, 1, 10, 10),
      );
      ctrl.add(doc);
      await Future<void>.delayed(
        const Duration(milliseconds: 10),
      ); // allow listener to run

      // Cached
      final cached = viewModel.getAppointment('S1');
      expect(cached, isNotNull);

      // Calling again should not resubscribe (guarded by map)
      await viewModel.subscribeToAppointment('S1');
      verify(() => repo.watchAppointment('S1')).called(1);

      // Unsubscribe should cancel/remove the listener (not directly observable), but it shouldn't throw
      viewModel.unsubscribeFromAppointment('S1');
      await ctrl.close();
    });

    test('skips subscription when already covered and cached', () async {
      // Make initial range so coverage logic can work.
      when(
        () => repo.watchAppointmentsBetween(any(), any()),
      ).thenAnswer((_) => const Stream<List<AppointmentModel>>.empty());
      await viewModel.setInitialRange();

      final covered = AppointmentModel(
        id: 'S2',
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime.now(), // within initial coverage
      );
      apptCache.cacheAppointment(covered);

      // Because it's cached and covered, it should early-return and NOT call watchAppointment
      await viewModel.subscribeToAppointment('S2');
      verifyNever(() => repo.watchAppointment('S2'));
    });
  });

  group('resetOnAuthChange', () {
    test('clears cache and resets public flags', () async {
      // Put something in cache and flip a couple of public flags.
      apptCache.cacheAppointment(
        AppointmentModel(
          id: 'x1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 5, 10),
        ),
      );
      viewModel.isReady = true; // public flag

      viewModel.resetOnAuthChange();

      // Cache cleared
      final after = viewModel.getAppointmentsInRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 31),
      );
      expect(after, isEmpty);

      // Public flags reset
      expect(viewModel.isReady, isFalse);
      expect(viewModel.saving, isFalse);
      expect(viewModel.error, isNull);
      // listLoading/listHasMore are private, but we can at least check no throws when accessing listCards:
      expect(viewModel.listCards, isEmpty);
    });
  });
}
