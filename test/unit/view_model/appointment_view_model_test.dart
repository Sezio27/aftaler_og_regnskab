import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/utils/appointment_notifications.dart';
import 'package:aftaler_og_regnskab/data/repositories/appointment_repository.dart';
import 'package:aftaler_og_regnskab/domain/cache/appointment_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/checklist_repository.dart';
import 'package:aftaler_og_regnskab/data/repositories/client_repository.dart';
import 'package:aftaler_og_regnskab/data/repositories/service_repository.dart';
import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/domain/appointment_model.dart';
import 'package:aftaler_og_regnskab/domain/client_model.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/data/services/image_storage.dart';
import 'package:aftaler_og_regnskab/data/services/notification_service.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fakes / Mocks
// ─────────────────────────────────────────────────────────────────────────────

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
  @override
  Future<Map<String, ClientModel?>> getClients(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }

  @override
  Future<ClientModel?> getClient(String id) async => _store[id];
}

class _FakeServiceRepository extends Fake implements ServiceRepository {
  _FakeServiceRepository([Map<String, ServiceModel?>? seed])
    : _store = {...?seed};
  final Map<String, ServiceModel?> _store;
  @override
  Future<Map<String, ServiceModel?>> getServices(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }

  @override
  Future<ServiceModel?> getServiceOnce(String id) async => _store[id];
}

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockFinanceViewModel extends Mock implements FinanceViewModel {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockAppointmentNotifications extends Mock
    implements AppointmentNotifications {}

class MockNotificationService extends Mock implements NotificationService {}

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
  late MockAppointmentNotifications notifications;
  late AppointmentViewModel viewModel;

  setUp(() {
    repo = MockAppointmentRepository();
    imageStorage = MockImageStorage();
    financeVM = MockFinanceViewModel();
    mockChecklistRepo = MockChecklistRepository();
    notifications = MockAppointmentNotifications();

    // Default stubs for notifications to avoid missing stub errors
    when(
      () => notifications.onAppointmentChanged(any()),
    ).thenAnswer((_) async {});
    when(() => notifications.cancelFor(any())).thenAnswer((_) async {});
    when(
      () => notifications.syncToday(appointments: any(named: 'appointments')),
    ).thenAnswer((_) async {});

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
      notifications: notifications,
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
      verifyNever(() => repo.newAppointmentRef());
      verifyNever(
        () => financeVM.onAddAppointment(
          status: any(named: 'status'),
          price: any(named: 'price'),
          dateTime: any(named: 'dateTime'),
        ),
      );
      // No notification because creation failed
      verifyNever(() => notifications.onAppointmentChanged(any()));
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
      verifyNever(() => notifications.onAppointmentChanged(any()));
    });
  });

  group('addAppointment success', () {
    test(
      'creates appointment, uploads images, schedules notification',
      () async {
        final now = DateTime.now();
        final fakeId = 'doc123';
        final fakeDoc = FakeDocumentRef(fakeId);

        when(() => repo.newAppointmentRef()).thenReturn(fakeDoc);
        when(
          () => imageStorage.uploadAppointmentImages(
            appointmentId: fakeId,
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async => ['u1.jpg', 'u2.jpg']);
        when(
          () => repo.createAppointmentWithId(fakeId, any()),
        ).thenAnswer((_) async {});
        when(
          () => financeVM.onAddAppointment(
            status: any(named: 'status'),
            price: any(named: 'price'),
            dateTime: any(named: 'dateTime'),
          ),
        ).thenAnswer((_) async {});

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

        expect(result, isTrue);
        expect(viewModel.error, isNull);
        expect(viewModel.saving, isFalse);

        final cached = apptCache.getAppointment(fakeId)!;
        expect(cached.clientId, 'client1');

        verify(() => repo.newAppointmentRef()).called(1);
        verify(() => repo.createAppointmentWithId(fakeId, any())).called(1);
        verify(
          () => financeVM.onAddAppointment(
            status: PaymentStatusX.fromString('ufaktureret'),
            price: 100.0,
            dateTime: now,
          ),
        ).called(1);

        // 🔔 Notification scheduled for the created item
        verify(
          () => notifications.onAppointmentChanged(
            any(
              that: isA<AppointmentModel>().having((a) => a.id, 'id', fakeId),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('updateAppointmentFields', () {
    test('happy path: updates, notifies, finance', () async {
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

      when(
        () => imageStorage.uploadAppointmentImages(
          appointmentId: old.id!,
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async => ['new1.png']);
      when(
        () => imageStorage.deleteAppointmentImagesByUrls(any()),
      ).thenAnswer((_) async {});
      when(
        () => repo.updateAppointment(
          old.id!,
          fields: any(named: 'fields'),
          deletes: any(named: 'deletes'),
        ),
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

      final newDate = DateTime(2024, 1, 12, 9);
      final newPay = DateTime(2024, 1, 15, 10);

      final ok = await viewModel.updateAppointmentFields(
        old,
        clientId: 'c_new',
        serviceId: 's_new',
        checklistIds: const ['A', 'C'],
        dateTime: newDate,
        payDate: newPay,
        location: ' New L ',
        note: 'New N',
        price: 150.0,
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

      // 🔔 Notification scheduled for the updated item
      verify(
        () => notifications.onAppointmentChanged(
          any(
            that: isA<AppointmentModel>()
                .having((a) => a.id, 'id', 'u1')
                .having((a) => a.status, 'status', 'Betalt'),
          ),
        ),
      ).called(1);
    });

    test('images-only path still notifies', () async {
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

      when(
        () => repo.updateAppointment(
          old.id!,
          fields: any(named: 'fields'),
          deletes: any(named: 'deletes'),
        ),
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
        currentImageUrls: old.imageUrls,
        removedImageUrls: const [],
        newImages: const [],
      );

      expect(ok, isTrue);

      // 🔔 Notification for updated (images unchanged, still fires)
      verify(
        () => notifications.onAppointmentChanged(
          any(that: isA<AppointmentModel>().having((a) => a.id, 'id', 'u3')),
        ),
      ).called(1);
    });
  });

  group('updateStatus', () {
    test(
      'updates cache, notifies finance (no notification change here)',
      () async {
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
        await viewModel.updateStatus(
          'id1',
          'ufaktureret',
          50.0,
          newStatus,
          now,
        );

        verify(() => repo.updateStatus('id1', newStatus.trim())).called(1);
        verify(
          () => financeVM.onUpdateStatus(
            oldStatus: PaymentStatus.uninvoiced,
            newStatus: PaymentStatus.paid,
            price: 50.0,
            date: now,
          ),
        ).called(1);
        final updated = apptCache.getAppointment('id1');
        expect(updated!.status, equals(newStatus));
      },
    );
  });

  group('delete', () {
    test(
      'removes appointment, cancels notifications, notifies finance',
      () async {
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
        ).thenAnswer((_) async {});
        when(() => repo.deleteAppointment('del1')).thenAnswer((_) async {});
        when(
          () => financeVM.onDeleteAppointment(
            status: any(named: 'status'),
            price: any(named: 'price'),
            date: any(named: 'date'),
          ),
        ).thenReturn(null);

        final now = DateTime.now();
        await viewModel.delete('del1', 'ufaktureret', 80.0, now);

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
        // 🔔 Notification cancellation
        verify(() => notifications.cancelFor('del1')).called(1);
      },
    );
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

  test('cardsForRange maps only in-range & valid items to cards', () async {
    clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Alice'));
    serviceCache.cacheService(
      const ServiceModel(id: 's1', name: 'Massage', duration: '30'),
    );

    apptCache.cacheAppointments([
      AppointmentModel(
        id: 'r1',
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime(2025, 1, 5, 9),
        status: 'Afventer',
        price: 250,
      ),
      AppointmentModel(
        id: null,
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime(2025, 1, 6, 14),
      ),
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
  });

  group('checklist progress', () {
    test(
      'checklistProgressStream delegates to repo.watchChecklistProgress',
      () async {
        final ctrl = StreamController<Map<String, Set<int>>>();
        when(
          () => repo.watchChecklistProgress('a1'),
        ).thenAnswer((_) => ctrl.stream);

        final future = expectLater(
          viewModel.checklistProgressStream('a1'),
          emitsInOrder([
            {
              'X': {1, 2},
              'Y': {0},
            },
          ]),
        );

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
      clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Alice'));
      final chips = viewModel.monthChipsOn(date);
      expect(chips.length, 1);
      final chip = chips.first;
      expect(chip.title, 'Alice');
      expect(chip.status, 'Betalt');
      expect(chip.time, date);
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
      expect(cards.length, 1);
      final card = cards.first;
      expect(card.id, 'card1');
      expect(card.clientName, 'Bob');
      expect(card.serviceName, 'Massage');
      expect(card.time, date);
      expect(card.price, 200.0);
      expect(card.duration, '60');
      expect(card.status, 'Afventer');
    });
  });

  group('listCards (paged mode)', () {
    test(
      'returns cards mapped from cached items inside beginListRange',
      () async {
        clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Kunde A'));
        serviceCache.cacheService(
          const ServiceModel(id: 's1', name: 'Behandling', duration: '45'),
        );

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
        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async => (items: <AppointmentModel>[], lastDoc: null));

        clientCache.cacheClient(
          const ClientModel(id: 'c1', name: 'Kunde A', phone: '123'),
        );
        serviceCache.cacheService(
          const ServiceModel(id: 's1', name: 'Behandling', duration: '45'),
        );

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

  group('loadNextListPage: short page branch', () {
    test(
      'caches items, sets hasMore=false when page shorter than pageSize',
      () async {
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

        final cards = viewModel.listCards;
        expect(
          cards.map((c) => c.id).toList()..sort(),
          equals(['p1-a', 'p1-b']),
        );

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
      'triggers extra non-awaited load when <5 in list but hasMore true',
      () async {
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
            dateTime: DateTime(2025, 2, 1, 12).add(Duration(minutes: i)),
          );
        });

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
        await Future<void>.delayed(const Duration(milliseconds: 20));

        verify(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).called(4);

        final cards = viewModel.listCards;
        expect(cards.map((c) => c.id).toList(), equals(['seed']));
      },
    );
  });

  group('paging early returns', () {
    test('loadNextListPage returns early when list bounds unset', () async {
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

      expect(viewModel.isReady, isTrue);
      final allThisMonth = viewModel.getAppointmentsInRange(
        DateTime.now().subtract(const Duration(days: 15)),
        DateTime.now().add(const Duration(days: 45)),
      );
      expect(allThisMonth.any((a) => a.id == 'm1'), isTrue);

      verify(() => repo.watchAppointmentsBetween(any(), any())).called(1);
    });

    test(
      'setActiveWindow opens extra month subs when outside initial',
      () async {
        when(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).thenAnswer((_) => const Stream<List<AppointmentModel>>.empty());

        await viewModel.setInitialRange();
        final farDate = DateTime.now().add(const Duration(days: 90));
        viewModel.setActiveWindow(farDate);

        verify(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).called(greaterThanOrEqualTo(2));
      },
    );
  });

  group('subscribeToAppointment / unsubscribeFromAppointment', () {
    test('subscribes once and caches incoming doc', () async {
      final ctrl = StreamController<AppointmentModel?>();
      when(() => repo.watchAppointment('S1')).thenAnswer((_) => ctrl.stream);

      await viewModel.subscribeToAppointment('S1');

      final doc = AppointmentModel(
        id: 'S1',
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime(2025, 1, 10, 10),
      );
      ctrl.add(doc);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final cached = viewModel.getAppointment('S1');
      expect(cached, isNotNull);

      await viewModel.subscribeToAppointment('S1');
      verify(() => repo.watchAppointment('S1')).called(1);

      viewModel.unsubscribeFromAppointment('S1');
      await ctrl.close();
    });

    test('skips subscription when already covered and cached', () async {
      when(
        () => repo.watchAppointmentsBetween(any(), any()),
      ).thenAnswer((_) => const Stream<List<AppointmentModel>>.empty());
      await viewModel.setInitialRange();

      final covered = AppointmentModel(
        id: 'S2',
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime.now(),
      );
      apptCache.cacheAppointment(covered);

      await viewModel.subscribeToAppointment('S2');
      verifyNever(() => repo.watchAppointment('S2'));
    });
  });

  group('resetOnAuthChange', () {
    test('clears cache and resets public flags', () async {
      apptCache.cacheAppointment(
        AppointmentModel(
          id: 'x1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(2025, 1, 5, 10),
        ),
      );
      viewModel.isReady = true;

      viewModel.resetOnAuthChange();

      final after = viewModel.getAppointmentsInRange(
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 31),
      );
      expect(after, isEmpty);

      expect(viewModel.isReady, isFalse);
      expect(viewModel.saving, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.listCards, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Notifications: rescheduleTodayAndFuture
  // ───────────────────────────────────────────────────────────────────────────
  group('rescheduleTodayAndFuture', () {
    test(
      'cancels all, syncs today, and schedules for paged future items',
      () async {
        final ns = MockNotificationService();
        when(() => ns.cancelAll()).thenAnswer((_) async {});
        when(
          () =>
              notifications.syncToday(appointments: any(named: 'appointments')),
        ).thenAnswer((_) async {});
        when(
          () => notifications.onAppointmentChanged(any()),
        ).thenAnswer((_) async {});

        // Seed 2 appointments for "today" so syncToday has something
        final now = DateTime.now();
        final today1 = AppointmentModel(
          id: 'tod1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime(now.year, now.month, now.day, 9),
        );
        final today2 = AppointmentModel(
          id: 'tod2',
          clientId: 'c2',
          serviceId: 's2',
          dateTime: DateTime(now.year, now.month, now.day, 15),
        );
        apptCache.cacheAppointments([today1, today2]);

        // Paged future appointments (short page -> single iteration)
        final future1 = AppointmentModel(
          id: 'f1',
          clientId: 'c3',
          serviceId: 's3',
          dateTime: now.add(const Duration(days: 1)),
        );
        final future2 = AppointmentModel(
          id: 'f2',
          clientId: 'c4',
          serviceId: 's4',
          dateTime: now.add(const Duration(days: 2)),
        );
        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async => (items: [future1, future2], lastDoc: null));

        await viewModel.rescheduleTodayAndFuture(ns);

        // Cancel all existing notifications first
        verify(() => ns.cancelAll()).called(1);

        // Sync today with today's appts
        final capturedToday =
            verify(
                  () => notifications.syncToday(
                    appointments: captureAny(named: 'appointments'),
                  ),
                ).captured.single
                as List<AppointmentModel>;
        expect(capturedToday.map((a) => a.id).toSet(), {'tod1', 'tod2'});

        // Scheduled notifications for paged items
        verify(
          () => notifications.onAppointmentChanged(
            any(that: isA<AppointmentModel>().having((a) => a.id, 'id', 'f1')),
          ),
        ).called(1);
        verify(
          () => notifications.onAppointmentChanged(
            any(that: isA<AppointmentModel>().having((a) => a.id, 'id', 'f2')),
          ),
        ).called(1);
      },
    );
  });
}
