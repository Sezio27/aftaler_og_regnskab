import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/data/repositories/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/repositories/client_repository.dart';
import 'package:aftaler_og_regnskab/data/repositories/service_repository.dart';
import 'package:aftaler_og_regnskab/data/repositories/checklist_repository.dart';
import 'package:aftaler_og_regnskab/data/services/image_storage.dart';
import 'package:aftaler_og_regnskab/data/services/notification_service.dart';
import 'package:aftaler_og_regnskab/domain/appointment_model.dart';
import 'package:aftaler_og_regnskab/domain/cache/appointment_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/domain/client_model.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:aftaler_og_regnskab/utils/appointment_notifications.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

class MockImageStorage extends Mock implements ImageStorage {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAppointmentNotifications extends Mock
    implements AppointmentNotifications {}

class FakeClientRepository extends Fake implements ClientRepository {
  FakeClientRepository([Map<String, ClientModel?>? seed]) : _store = {...?seed};
  final Map<String, ClientModel?> _store;

  @override
  Future<Map<String, ClientModel?>> getClients(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }
}

class FakeServiceRepository extends Fake implements ServiceRepository {
  FakeServiceRepository([Map<String, ServiceModel?>? seed])
    : _store = {...?seed};
  final Map<String, ServiceModel?> _store;

  @override
  Future<Map<String, ServiceModel?>> getServices(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }
}

class FakeChecklistRepository extends Fake implements ChecklistRepository {
  FakeChecklistRepository([Map<String, ChecklistModel?>? seed])
    : _store = {...?seed};
  final Map<String, ChecklistModel?> _store;

  @override
  Future<Map<String, ChecklistModel?>> getChecklists(Set<String> ids) async {
    return {for (final id in ids) id: _store[id]};
  }
}

// ignore: subtype_of_sealed_class
/// Minimal fake Firestore DocumentReference exposing only `id`.
class FakeDocumentRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeDocumentRef(this._id);
  final String _id;

  @override
  String get id => _id;
}

void main() {
  setUpAll(() {
    // Fallbacks for mocktail so any() / captureAny() works with these types.
    registerFallbackValue(<String, Object?>{}); // for fields
    registerFallbackValue(<String>{}); // for deletes
    registerFallbackValue(const AppointmentModel()); // for any AppointmentModel
    // For checklist progress maps if needed.
    registerFallbackValue(<String, Set<int>>{});
  });

  late MockAppointmentRepository repo;
  late MockImageStorage imageStorage;
  late MockAppointmentNotifications notifications;
  late ClientCache clientCache;
  late ServiceCache serviceCache;
  late ChecklistCache checklistCache;
  late AppointmentCache apptCache;
  late AppointmentViewModel vm;

  setUp(() {
    repo = MockAppointmentRepository();
    imageStorage = MockImageStorage();
    notifications = MockAppointmentNotifications();

    clientCache = ClientCache(FakeClientRepository());
    serviceCache = ServiceCache(FakeServiceRepository());
    checklistCache = ChecklistCache(FakeChecklistRepository());
    apptCache = AppointmentCache();

    vm = AppointmentViewModel(
      repo,
      imageStorage,
      clientCache: clientCache,
      serviceCache: serviceCache,
      checklistCache: checklistCache,
      apptCache: apptCache,
      notifications: notifications,
    );

    // Default stubs so we don't hit null streams.
    when(
      () => repo.watchAppointmentsBetween(any(), any()),
    ).thenAnswer((_) => const Stream<List<AppointmentModel>>.empty());
    when(
      () => repo.watchChecklistProgress(any()),
    ).thenAnswer((_) => const Stream<Map<String, Set<int>>>.empty());
    when(
      () => notifications.onAppointmentChanged(any()),
    ).thenAnswer((_) async {});
    when(
      () => notifications.syncToday(appointments: any(named: 'appointments')),
    ).thenAnswer((_) async {});
    when(() => notifications.cancelFor(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    vm.dispose();
  });

  group('addAppointment', () {
    // If clientId is missing/blank, addAppointment should fail fast,
    // set an error message, and not touch the repository.
    test('returns false and sets error when clientId is empty', () async {
      var notified = false;
      vm.addListener(() => notified = true);

      final result = await vm.addAppointment(
        clientId: '',
        serviceId: null,
        dateTime: DateTime.now(),
        checklistIds: const [],
      );

      expect(result, isFalse);
      expect(vm.error, 'Vælg klient');
      expect(vm.saving, isFalse);
      verifyNever(() => repo.newAppointmentRef());
      expect(notified, isTrue);
    });

    // If dateTime is null, addAppointment should fail fast in the same way.
    test('returns false and sets error when dateTime is null', () async {
      var notified = false;
      vm.addListener(() => notified = true);

      final result = await vm.addAppointment(
        clientId: 'c1',
        serviceId: 's1',
        dateTime: null,
        checklistIds: const [],
      );

      expect(result, isFalse);
      expect(vm.error, 'Vælg dato og tid');
      expect(vm.saving, isFalse);
      verifyNever(() => repo.newAppointmentRef());
      expect(notified, isTrue);
    });

    // When inputs are valid and no images are provided, addAppointment should:
    // - create a doc ref
    // - call createAppointmentWithId
    // - cache the created appointment
    // - not upload any images
    // - trigger notifications.onAppointmentChanged
    test(
      'creates appointment without images, caches it and triggers notification',
      () async {
        when(() => repo.newAppointmentRef()).thenReturn(FakeDocumentRef('a1'));
        when(
          () => repo.createAppointmentWithId(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => notifications.onAppointmentChanged(any()),
        ).thenAnswer((_) async {});

        final now = DateTime.now();

        final result = await vm.addAppointment(
          clientId: '  c1  ',
          serviceId: 's1',
          dateTime: now,
          checklistIds: const [' id1 ', '', 'id2'],
          price: 500,
          note: ' note ',
        );

        expect(result, isTrue);
        expect(vm.saving, isFalse);
        expect(vm.error, isNull);

        final appt = apptCache.getAppointment('a1');
        expect(appt, isNotNull);
        expect(appt!.clientId, '  c1  '); // not trimmed here
        expect(appt.serviceId, 's1');
        expect(appt.dateTime, now);
        expect(appt.checklistIds, ['id1', 'id2']);
        expect(appt.price, 500);
        expect(appt.note, ' note ');
        expect(appt.imageUrls, isEmpty);

        verifyNever(
          () => imageStorage.uploadAppointmentImages(
            appointmentId: any(named: 'appointmentId'),
            images: any(named: 'images'),
          ),
        );
        verify(() => repo.createAppointmentWithId('a1', any())).called(1);
        verify(() => notifications.onAppointmentChanged(any())).called(1);
      },
    );

    // When images are provided, addAppointment should upload them and store
    // the returned URLs on the created appointment.
    test(
      'uploads images when provided and stores URLs on appointment',
      () async {
        when(() => repo.newAppointmentRef()).thenReturn(FakeDocumentRef('a2'));
        when(
          () => repo.createAppointmentWithId(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.uploadAppointmentImages(
            appointmentId: any(named: 'appointmentId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async => ['u1', 'u2']);

        final img = (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'pic.jpg',
          mimeType: 'image/jpeg',
        );

        final result = await vm.addAppointment(
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime.now(),
          checklistIds: const [],
          images: [img],
        );

        expect(result, isTrue);

        final appt = apptCache.getAppointment('a2');
        expect(appt, isNotNull);
        expect(appt!.imageUrls, ['u1', 'u2']);

        verify(
          () => imageStorage.uploadAppointmentImages(
            appointmentId: 'a2',
            images: any(named: 'images'),
          ),
        ).called(1);
      },
    );

    // If the repository throws during create, addAppointment should return false,
    // set a readable error message and reset saving.
    test(
      'sets error and returns false when repository throws during create',
      () async {
        when(() => repo.newAppointmentRef()).thenReturn(FakeDocumentRef('a3'));
        when(
          () => repo.createAppointmentWithId(any(), any()),
        ).thenThrow(Exception('boom'));

        final result = await vm.addAppointment(
          clientId: 'c1',
          serviceId: 's1',
          dateTime: DateTime.now(),
          checklistIds: const [],
        );

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke oprette aftale'));
        expect(vm.saving, isFalse);
      },
    );
  });

  group('updateStatus', () {
    // updateStatus should trim the status, call repo.updateStatus and, if the
    // appointment is in the cache, update its status locally as well.
    test('updates repository and local cache, trimming status', () async {
      apptCache.cacheAppointment(
        const AppointmentModel(id: 'id1', status: 'old'),
      );
      when(() => repo.updateStatus(any(), any())).thenAnswer((_) async {});

      await vm.updateStatus('id1', '  new  ');

      verify(() => repo.updateStatus('id1', 'new')).called(1);
      final updated = apptCache.getAppointment('id1');
      expect(updated, isNotNull);
      expect(updated!.status, 'new');
    });

    // If the appointment is not cached, updateStatus should still call the
    // repository and not crash.
    test('updates repository even when appointment is not cached', () async {
      when(() => repo.updateStatus(any(), any())).thenAnswer((_) async {});

      await vm.updateStatus('missing', 'paid');

      verify(() => repo.updateStatus('missing', 'paid')).called(1);
    });
  });

  group('handleImages', () {
    // When new images are present, handleImages should:
    // - upload them
    // - drop removed URLs from the current list
    // - return the union as a set (no duplicates)
    test(
      'merges kept current URLs with uploaded ones and removes duplicates',
      () async {
        when(
          () => imageStorage.uploadAppointmentImages(
            appointmentId: any(named: 'appointmentId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async => ['u3', 'u4']);

        final result = await vm.handleImages(
          [
            (
              bytes: Uint8List.fromList([1]),
              name: 'img.png',
              mimeType: 'image/png',
            ),
          ],
          const ['u2'],
          const ['u1', 'u2', 'u3'],
          'a1',
        );

        expect(result.length, 3);
        expect(result, containsAll(['u1', 'u3', 'u4']));
      },
    );

    // When newImages is empty, handleImages should:
    // - not call storage
    // - simply return the current URLs minus any removed ones.
    test('returns current URLs minus removed when no new images', () async {
      final result = await vm.handleImages(
        const [],
        const ['u2'],
        const ['u1', 'u2'],
        'a1',
      );

      expect(result, ['u1']);
      verifyNever(
        () => imageStorage.uploadAppointmentImages(
          appointmentId: any(named: 'appointmentId'),
          images: any(named: 'images'),
        ),
      );
    });
  });

  group(
    'checklist helpers (handeNewChecklists, handleRemovedChecklists, handleFields)',
    () {
      // handeNewChecklists should return null when given null.
      test('handeNewChecklists returns null when input is null', () {
        final res = vm.handeNewChecklists(null);
        expect(res, isNull);
      });

      // handeNewChecklists should trim ids, drop empties and deduplicate.
      test('handeNewChecklists trims, filters empties and deduplicates', () {
        final res = vm.handeNewChecklists(const [' a ', 'b', ' ', 'a']);
        expect(res, isNotNull);
        expect(res, containsAll({'a', 'b'}));
        expect(res!.length, 2);
      });

      // handleRemovedChecklists should return old minus new when new is provided.
      test(
        'handleRemovedChecklists returns difference when newChecklists provided',
        () {
          final old = ['a', 'b', 'c'];
          final newSet = {'b', 'c', 'd'};
          final res = vm.handleRemovedChecklists(newSet, old);

          expect(res, {'a'});
        },
      );

      // handleRemovedChecklists should return empty set if new is null.
      test(
        'handleRemovedChecklists returns empty set when newChecklists is null',
        () {
          final old = ['a', 'b'];
          final res = vm.handleRemovedChecklists(null, old);
          expect(res, isEmpty);
        },
      );

      // handleFields should:
      // - always set imageUrls
      // - set fields for non-empty strings
      // - add deletes for empty strings
      // - convert DateTime to Timestamp
      // - set price, checklistIds and progress deletes
      test(
        'handleFields populates fields and deletes for strings, timestamps, price and checklists',
        () {
          final fields = <String, Object?>{};
          final deletes = <String>{};
          final dt = DateTime(2024, 1, 1, 12, 0);
          final finalImages = ['img1'];

          vm.handleUpdateFields(
            fields,
            finalImages,
            deletes,
            ' c1 ',
            ' ', // serviceId → delete
            ' Loc ',
            null, // note ignored
            '', // status → delete
            dt,
            null,
            123.5,
            {'chk1', 'chk2'},
            {'old1', 'old2'},
          );

          expect(fields['imageUrls'], finalImages);
          expect(fields['clientId'], 'c1');
          expect(fields['location'], 'Loc');
          expect(
            fields['status'],
            isNull,
          ); // status goes via deletes, not fields
          expect(fields['dateTime'], isA<Timestamp>());
          final ts = fields['dateTime'] as Timestamp;
          expect(ts.toDate(), dt);
          expect(fields['price'], 123.5);
          expect(fields['checklistIds'], isA<List<String>>());
          final ids = (fields['checklistIds'] as List).cast<String>();
          expect(ids, containsAll(['chk1', 'chk2']));
          expect(
            deletes,
            containsAll([
              'serviceId',
              'status',
              'progress.old1',
              'progress.old2',
            ]),
          );
        },
      );
    },
  );

  group('handleDeleteImage', () {
    // handleDeleteImage should call storage delete when given URLs.
    test('calls storage to delete appointment images', () async {
      when(
        () => imageStorage.deleteAppointmentImagesByUrls(any()),
      ).thenAnswer((_) async {});

      await vm.handleDeleteImage(const ['u1', 'u2']);

      verify(
        () => imageStorage.deleteAppointmentImagesByUrls(['u1', 'u2']),
      ).called(1);
    });

    // If storage delete throws, handleDeleteImage should swallow and not rethrow.
    test('swallows errors from image deletion', () async {
      when(
        () => imageStorage.deleteAppointmentImagesByUrls(any()),
      ).thenThrow(Exception('fail'));

      await vm.handleDeleteImage(const ['u1']); // should not throw
    });
  });

  group('handleUpdate & updateAppointmentFields', () {
    // Updating multiple fields including changing the date should:
    // - call repo.updateAppointment with correct fields/deletes
    // - update the cached appointment
    // - call notifications when the date changes
    // - delete removed images
    test(
      'updateAppointmentFields updates repo, cache and notifications, and deletes images',
      () async {
        final oldDate = DateTime.now();
        final newDate = oldDate.add(const Duration(days: 1));

        final old = AppointmentModel(
          id: 'a1',
          clientId: 'old-c',
          serviceId: 'old-s',
          checklistIds: const ['chk1', 'chk2'],
          dateTime: oldDate,
          payDate: oldDate,
          price: 100,
          location: 'OldLoc',
          note: 'OldNote',
          status: 'oldStatus',
          imageUrls: const ['img-old1', 'img-old2'],
        );
        apptCache.cacheAppointment(old);

        when(
          () => repo.updateAppointment(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.uploadAppointmentImages(
            appointmentId: any(named: 'appointmentId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async => ['img-new']);
        when(
          () => imageStorage.deleteAppointmentImagesByUrls(any()),
        ).thenAnswer((_) async {});
        when(
          () => notifications.onAppointmentChanged(any()),
        ).thenAnswer((_) async {});

        final img = (
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'pic.jpg',
          mimeType: 'image/jpeg',
        );

        final result = await vm.updateAppointmentFields(
          old,
          clientId: ' c-new ',
          serviceId: 's-new',
          checklistIds: const ['chk2', 'chk3', ' '],
          dateTime: newDate,
          payDate: newDate,
          location: ' ', // should be deleted
          note: 'new note',
          price: 200,
          status: null,
          currentImageUrls: const ['img-old1', 'img-old2'],
          removedImageUrls: const ['img-old1'],
          newImages: [img],
        );

        expect(result, isTrue);
        expect(vm.error, isNull);
        expect(vm.saving, isFalse);

        verify(
          () => repo.updateAppointment(
            'a1',
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).called(1);
        verify(
          () => imageStorage.deleteAppointmentImagesByUrls(['img-old1']),
        ).called(1);
        verify(() => notifications.onAppointmentChanged(any())).called(1);

        final updated = apptCache.getAppointment('a1');
        expect(updated, isNotNull);
        expect(updated!.clientId, ' c-new ');
        expect(updated.serviceId, 's-new');
        expect(updated.dateTime, newDate);
        expect(updated.payDate, newDate);
        expect(updated.note, 'new note');
        expect(updated.location, isNull); // deleted
        expect(updated.status, 'oldStatus'); // unchanged
        expect(updated.price, 200);
        expect(updated.checklistIds, containsAll(['chk2', 'chk3']));
        expect(updated.imageUrls, containsAll(['img-old2', 'img-new']));
      },
    );

    // If the dateTime parameter equals the old date, notifications should
    // not be called even though other fields are updated.
    test('does not call notifications when dateTime stays the same', () async {
      final dt = DateTime.now();

      final old = AppointmentModel(
        id: 'a1',
        clientId: 'old-c',
        serviceId: 'old-s',
        checklistIds: const [],
        dateTime: dt,
        imageUrls: const [],
      );
      apptCache.cacheAppointment(old);

      when(
        () => repo.updateAppointment(
          any(),
          fields: any(named: 'fields'),
          deletes: any(named: 'deletes'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => imageStorage.deleteAppointmentImagesByUrls(any()),
      ).thenAnswer((_) async {});
      when(
        () => notifications.onAppointmentChanged(any()),
      ).thenAnswer((_) async {});

      final result = await vm.updateAppointmentFields(
        old,
        dateTime: dt, // same as old
        location: 'NewLoc',
        currentImageUrls: const [],
      );

      expect(result, isTrue);
      verifyNever(() => notifications.onAppointmentChanged(any()));
    });

    // If the repository throws during update, updateAppointmentFields should:
    // - catch the error
    // - set a readable error message
    // - return false and reset saving
    test(
      'returns false and sets error when repo.updateAppointment throws',
      () async {
        final old = AppointmentModel(
          id: 'a1',
          dateTime: DateTime.now(),
          imageUrls: const [],
        );

        when(
          () => repo.updateAppointment(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenThrow(Exception('failure'));

        final result = await vm.updateAppointmentFields(
          old,
          currentImageUrls: const [],
        );

        expect(result, isFalse);
        expect(vm.error, contains('Kunne ikke opdatere'));
        expect(vm.saving, isFalse);
      },
    );

    // When image deletion fails, updateAppointmentFields should still return
    // true and not propagate the error.
    test(
      'swallows errors from image deletion in updateAppointmentFields',
      () async {
        final old = AppointmentModel(
          id: 'a1',
          dateTime: DateTime.now(),
          imageUrls: const ['u1'],
        );

        when(
          () => repo.updateAppointment(
            any(),
            fields: any(named: 'fields'),
            deletes: any(named: 'deletes'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => imageStorage.deleteAppointmentImagesByUrls(any()),
        ).thenThrow(Exception('fail'));

        final result = await vm.updateAppointmentFields(
          old,
          currentImageUrls: const ['u1'],
          removedImageUrls: const ['u1'],
        );

        expect(result, isTrue);
        expect(vm.error, isNull);
      },
    );
  });

  group('ranges and cards', () {
    // getAppointmentsInRange should forward to the cache and respect the
    // inclusive day boundaries.
    test(
      'getAppointmentsInRange returns appointments between start and end',
      () {
        final start = DateTime(2024, 1, 1);
        final mid = DateTime(2024, 1, 10, 12);
        final end = DateTime(2024, 1, 31, 23, 0);
        final outside = DateTime(2024, 2, 1);

        apptCache.cacheAppointment(AppointmentModel(id: 'a1', dateTime: start));
        apptCache.cacheAppointment(AppointmentModel(id: 'a2', dateTime: mid));
        apptCache.cacheAppointment(
          AppointmentModel(id: 'a3', dateTime: outside),
        );

        final res = vm.getAppointmentsInRange(start, end);

        expect(res.map((a) => a.id), ['a1', 'a2']);
      },
    );

    // cardsForRange should map appointments in range to AppointmentCardModel,
    // skipping those without id or dateTime, and using client/service caches.
    test(
      'cardsForRange builds cards from cached appointments and client/service caches',
      () {
        clientCache.cacheClient(
          const ClientModel(
            id: 'c1',
            name: 'Alice',
            phone: '123',
            email: 'a@mail',
            cvr: '1234', // business client
            image: 'img-client',
          ),
        );
        serviceCache.cacheService(
          const ServiceModel(id: 's1', name: 'Makeup', duration: '2 timer'),
        );

        final dt = DateTime(2024, 1, 10, 14);
        apptCache.cacheAppointment(
          AppointmentModel(
            id: 'a1',
            clientId: 'c1',
            serviceId: 's1',
            dateTime: dt,
            price: 500,
            status: 'Betalt',
            imageUrls: const [],
          ),
        );

        // Also cache an appointment missing id to exercise the filter.
        apptCache.cacheAppointment(
          const AppointmentModel(id: null, dateTime: null),
        );

        final start = DateTime(2024, 1, 1);
        final end = DateTime(2024, 1, 31);

        final cards = vm.cardsForRange(start, end);

        expect(cards.length, 1);
        final card = cards.first;
        expect(card.id, 'a1');
        expect(card.clientName, 'Alice');
        expect(card.serviceName, 'Makeup');
        expect(card.phone, '123');
        expect(card.email, 'a@mail');
        expect(card.time, dt);
        expect(card.price, 500);
        expect(card.duration, '2 timer');
        expect(card.status, 'Betalt');
        expect(card.imageUrl, 'img-client');
        expect(card.isBusiness, isTrue);
      },
    );
  });

  group('day-based helpers: monthChipsOn, hasEventsOn, cardsForDate', () {
    // monthChipsOn should:
    // - collect appointments on that day
    // - look up client names
    // - default status to "ufaktureret" when null
    test('monthChipsOn builds chips with client name, status and time', () {
      final day = DateTime(2024, 1, 10);
      final dt1 = DateTime(2024, 1, 10, 9);
      final dt2 = DateTime(2024, 1, 10, 12);

      clientCache.cacheClient(const ClientModel(id: 'c1', name: 'Alice'));
      clientCache.cacheClient(const ClientModel(id: 'c2', name: 'Bob'));

      apptCache.cacheAppointment(
        AppointmentModel(
          id: 'a1',
          clientId: 'c1',
          dateTime: dt1,
          status: 'Betalt',
        ),
      );
      apptCache.cacheAppointment(
        AppointmentModel(
          id: 'a2',
          clientId: 'c2',
          dateTime: dt2,
          status: null, // should default
        ),
      );

      final chips = vm.monthChipsOn(day);

      expect(chips.length, 2);
      final first = chips[0];
      final second = chips[1];
      expect(first.title, 'Alice');
      expect(first.status, 'Betalt');
      expect(first.time, dt1);

      expect(second.title, 'Bob');
      expect(second.status, 'ufaktureret');
      expect(second.time, dt2);
    });

    // hasEventsOn should report true when any appointment exists on the day,
    // and false otherwise.
    test('hasEventsOn reports correctly based on cached appointments', () {
      final day = DateTime(2024, 2, 1);
      final dt = DateTime(2024, 2, 1, 10);

      apptCache.cacheAppointment(AppointmentModel(id: 'a1', dateTime: dt));

      expect(vm.hasEventsOn(day), isTrue);
      expect(vm.hasEventsOn(DateTime(2024, 2, 2)), isFalse);
    });

    // cardsForDate should:
    // - build cards for all appointments on that date
    // - prefetch missing clients/services via the caches
    // - use the fetched data in the cards.
    test(
      'cardsForDate builds cards and prefetches missing client and service data',
      () async {
        final day = DateTime(2024, 3, 5);
        final dt1 = DateTime(2024, 3, 5, 9);
        final dt2 = DateTime(2024, 3, 5, 11);

        // Set up caches with repos that know about c2/s2.
        clientCache = ClientCache(
          FakeClientRepository({
            'c2': const ClientModel(id: 'c2', name: 'Fetched Client'),
          }),
        );
        serviceCache = ServiceCache(
          FakeServiceRepository({
            's2': const ServiceModel(id: 's2', name: 'Fetched Service'),
          }),
        );
        checklistCache = ChecklistCache(FakeChecklistRepository());
        apptCache = AppointmentCache();

        vm = AppointmentViewModel(
          repo,
          imageStorage,
          clientCache: clientCache,
          serviceCache: serviceCache,
          checklistCache: checklistCache,
          apptCache: apptCache,
          notifications: notifications,
        );

        // Appointment where client/service already cached.
        clientCache.cacheClient(
          const ClientModel(id: 'c1', name: 'Cached Client'),
        );
        serviceCache.cacheService(
          const ServiceModel(id: 's1', name: 'Cached Service'),
        );

        apptCache.cacheAppointment(
          AppointmentModel(
            id: 'a1',
            clientId: 'c1',
            serviceId: 's1',
            dateTime: dt1,
          ),
        );

        // Appointment where client/service must be fetched.
        apptCache.cacheAppointment(
          AppointmentModel(
            id: 'a2',
            clientId: 'c2',
            serviceId: 's2',
            dateTime: dt2,
          ),
        );

        final cards = await vm.cardsForDate(day);

        expect(cards.length, 2);
        final names = cards.map((c) => c.clientName).toList();
        expect(names, containsAll(['Cached Client', 'Fetched Client']));
        final serviceNames = cards.map((c) => c.serviceName).toList();
        expect(
          serviceNames,
          containsAll(['Cached Service', 'Fetched Service']),
        );
      },
    );
  });

  group('initial loading and ensureMonthLoaded', () {
    // setInitialRange should:
    // - subscribe once
    // - set hasLoadedInitialWindow when a non-empty snapshot arrives
    test(
      'setInitialRange subscribes once and marks initial window as loaded on non-empty snapshot',
      () async {
        final controller = StreamController<List<AppointmentModel>>();
        when(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).thenAnswer((_) => controller.stream);

        vm.setInitialRange();

        final now = DateTime.now();
        controller.add([AppointmentModel(id: 'a1', dateTime: now)]);
        await Future<void>.delayed(Duration.zero);

        expect(vm.hasLoadedInitialWindow, isTrue);
        final appts = vm.getAppointmentsInRange(
          startOfMonth(now),
          endOfMonthInclusive(startOfMonth(now)),
        );
        expect(appts.map((a) => a.id), contains('a1'));

        await controller.close();
      },
    );

    // When the first snapshot is empty, setInitialRange should still mark
    // the initial window as loaded.
    test(
      'setInitialRange marks initial window as loaded even on empty snapshot',
      () async {
        final controller = StreamController<List<AppointmentModel>>();
        when(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).thenAnswer((_) => controller.stream);

        vm.setInitialRange();
        controller.add(const []);
        await Future<void>.delayed(Duration.zero);

        expect(vm.hasLoadedInitialWindow, isTrue);

        await controller.close();
      },
    );

    // ensureMonthLoaded should do nothing when the month is inside the
    // initial window and not call getAppointmentsBetween.
    test(
      'ensureMonthLoaded does nothing for month inside initial window',
      () async {
        when(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).thenAnswer((_) => const Stream<List<AppointmentModel>>.empty());

        vm.setInitialRange();

        final visible = DateTime.now();
        await vm.ensureMonthLoaded(visible);

        verifyNever(() => repo.getAppointmentsBetween(any(), any()));
      },
    );

    // For a month outside the initial window, ensureMonthLoaded should fetch
    // from the repository, cache the appointments and remember that month
    // as loaded.
    test(
      'ensureMonthLoaded fetches and caches appointments for month outside initial window',
      () async {
        // Stub the initial watch so setInitialRange() can subscribe.
        when(
          () => repo.watchAppointmentsBetween(any(), any()),
        ).thenAnswer((_) => const Stream<List<AppointmentModel>>.empty());

        vm.setInitialRange();

        final futureMonth = DateTime.now().add(const Duration(days: 62));
        final monthStart = startOfMonth(futureMonth);
        final monthEnd = endOfMonthInclusive(monthStart);

        // Stub the one-off fetch for the future month.
        when(() => repo.getAppointmentsBetween(any(), any())).thenAnswer(
          (_) async => [AppointmentModel(id: 'f1', dateTime: monthStart)],
        );

        await vm.ensureMonthLoaded(futureMonth);

        // 1) Exactly one subscription for the initial window…
        verify(() => repo.watchAppointmentsBetween(any(), any())).called(1);

        // 2) …and exactly one fetch for this outside month with the right bounds.
        verify(
          () => repo.getAppointmentsBetween(monthStart, monthEnd),
        ).called(1);

        // 3) No other repository calls are allowed.
        verifyNoMoreInteractions(repo);

        final cached = apptCache.getAppointmentsBetween(monthStart, monthEnd);
        expect(cached.map((a) => a.id), ['f1']);
      },
    );
  });

  group('rescheduleTodayAndFuture', () {
    // rescheduleTodayAndFuture should:
    // - cancel all existing notifications via NotificationService
    // - call notifications.syncToday with today's appointments
    // - iterate pages and call notifications.onAppointmentChanged for each
    //   future appointment, then stop when items.length < pageSize.
    test(
      'reschedules today and future pages and stops when last page smaller than pageSize',
      () async {
        final ns = MockNotificationService();
        when(() => ns.cancelAll()).thenAnswer((_) async {});
        when(() => ns.enabled).thenReturn(true);

        final now = DateTime.now();
        final todayAppt = AppointmentModel(
          id: 't1',
          dateTime: now.add(const Duration(hours: 1)),
        );
        apptCache.cacheAppointment(todayAppt);

        final futureAppt = AppointmentModel(
          id: 'f1',
          dateTime: now.add(const Duration(days: 1)),
        );

        var callCount = 0;
        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async {
          if (callCount++ == 0) {
            return (items: [futureAppt], lastDoc: null);
          } else {
            return (items: <AppointmentModel>[], lastDoc: null);
          }
        });

        await vm.rescheduleTodayAndFuture(ns);

        verify(() => ns.cancelAll()).called(1);
        verify(
          () =>
              notifications.syncToday(appointments: any(named: 'appointments')),
        ).called(1);
        verify(() => notifications.onAppointmentChanged(futureAppt)).called(1);
      },
    );

    // If the first page is empty, rescheduleTodayAndFuture should stop
    // immediately and not call onAppointmentChanged.
    test('stops when first page is empty', () async {
      final ns = MockNotificationService();
      when(() => ns.cancelAll()).thenAnswer((_) async {});
      when(() => ns.enabled).thenReturn(true);

      when(
        () => repo.getAppointmentsPaged(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
          pageSize: any(named: 'pageSize'),
          startAfterDoc: any(named: 'startAfterDoc'),
          descending: any(named: 'descending'),
        ),
      ).thenAnswer((_) async => (items: <AppointmentModel>[], lastDoc: null));

      await vm.rescheduleTodayAndFuture(ns);

      verifyNever(() => notifications.onAppointmentChanged(any()));
    });
  });

  group('checklist progress forwarding', () {
    // checklistProgressStream should simply return the stream from the repo.
    test('checklistProgressStream delegates to repository', () async {
      final stream = Stream.value(<String, Set<int>>{
        'cl1': {1, 2},
      });
      when(() => repo.watchChecklistProgress('a1')).thenAnswer((_) => stream);

      await expectLater(
        vm.checklistProgressStream('a1'),
        emits(<String, Set<int>>{
          'cl1': {1, 2},
        }),
      );
    });

    // saveChecklistProgress should call setAllChecklistProgress with the
    // given appointmentId and progress map.
    test('saveChecklistProgress delegates to repository', () async {
      when(
        () => repo.setAllChecklistProgress(any(), any()),
      ).thenAnswer((_) async {});

      final progress = <String, Set<int>>{
        'cl1': {0, 2},
      };

      await vm.saveChecklistProgress(appointmentId: 'a1', progress: progress);

      verify(() => repo.setAllChecklistProgress('a1', progress)).called(1);
    });
  });

  group(
    'listing & pagination: beginListRange, loadNextListPage, listCards',
    () {
      // loadNextListPage should immediately return (no repo call) if list
      // range has not been initialized.
      test(
        'loadNextListPage returns early when list range not started',
        () async {
          await vm.loadNextListPage();
          verifyNever(
            () => repo.getAppointmentsPaged(
              startInclusive: any(named: 'startInclusive'),
              endInclusive: any(named: 'endInclusive'),
              pageSize: any(named: 'pageSize'),
              startAfterDoc: any(named: 'startAfterDoc'),
              descending: any(named: 'descending'),
            ),
          );
        },
      );

      // When beginListRange is called and the repository returns some items
      // smaller than the internal page size, it should:
      // - load at least one page
      // - cache them
      // - set listHasMore to false
      // - expose cards via listCards
      test('beginListRange loads first page and exposes listCards', () async {
        final start = DateTime(2024, 1, 1);
        final end = DateTime(2024, 1, 31);

        final appts = List.generate(
          5,
          (i) => AppointmentModel(
            id: 'p$i',
            dateTime: DateTime(2024, 1, i + 1, 10),
          ),
        );

        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async => (items: appts, lastDoc: null));

        await vm.beginListRange(start, end);

        expect(vm.listLoading, isFalse);
        expect(vm.listHasMore, isFalse);
        expect(vm.listCards.length, 5);
        expect(
          vm.listCards.map((c) => c.id),
          containsAll(['p0', 'p1', 'p2', 'p3', 'p4']),
        );
      });

      // If the repository returns an empty page, beginListRange should stop
      // and listCards should remain empty while listHasMore becomes false.
      test('beginListRange stops when repository returns empty page', () async {
        final start = DateTime(2024, 2, 1);
        final end = DateTime(2024, 2, 28);

        when(
          () => repo.getAppointmentsPaged(
            startInclusive: any(named: 'startInclusive'),
            endInclusive: any(named: 'endInclusive'),
            pageSize: any(named: 'pageSize'),
            startAfterDoc: any(named: 'startAfterDoc'),
            descending: any(named: 'descending'),
          ),
        ).thenAnswer((_) async => (items: <AppointmentModel>[], lastDoc: null));

        await vm.beginListRange(start, end);

        expect(vm.listCards, isEmpty);
        expect(vm.listHasMore, isFalse);
      });
    },
  );

  group('delete & resetOnAuthChange', () {
    // delete should:
    // - try to delete appointment images (swallowing errors)
    // - cancel notifications for the appointment
    // - delete the appointment via the repo
    // - remove it from the cache and notify listeners
    test(
      'delete removes appointment from cache and calls repo and notifications',
      () async {
        apptCache.cacheAppointment(
          AppointmentModel(id: 'id1', dateTime: DateTime.now()),
        );

        when(
          () => imageStorage.deleteAppointmentImages(any()),
        ).thenThrow(Exception('missing'));
        when(() => repo.deleteAppointment(any())).thenAnswer((_) async {});
        when(() => notifications.cancelFor(any())).thenAnswer((_) async {});

        await vm.delete('id1', 'status', 100, DateTime.now());

        verify(() => repo.deleteAppointment('id1')).called(1);
        verify(() => notifications.cancelFor('id1')).called(1);
        expect(apptCache.getAppointment('id1'), isNull);
      },
    );

    // resetOnAuthChange should clear all view model state and cache, so that:
    // - hasLoadedInitialWindow is reset
    // - paging flags are reset
    // - listCards is empty
    // - saving/error are reset
    // - cached appointments are cleared
    test('resetOnAuthChange clears state and cache', () async {
      apptCache.cacheAppointment(
        AppointmentModel(id: 'id1', dateTime: DateTime.now()),
      );

      // Make sure beginListRange can complete without hanging by returning
      // an empty page from getAppointmentsPaged.
      when(
        () => repo.getAppointmentsPaged(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
          pageSize: any(named: 'pageSize'),
          startAfterDoc: any(named: 'startAfterDoc'),
          descending: any(named: 'descending'),
        ),
      ).thenAnswer((_) async => (items: <AppointmentModel>[], lastDoc: null));

      vm.setInitialRange();
      await vm.beginListRange(DateTime(2024, 1, 1), DateTime(2024, 1, 31));

      vm.resetOnAuthChange();

      expect(vm.hasLoadedInitialWindow, isFalse);
      expect(vm.listHasMore, isFalse);
      expect(vm.listLoading, isFalse);
      expect(vm.listCards, isEmpty);
      expect(vm.saving, isFalse);
      expect(vm.error, isNull);

      final allAppts = apptCache.getAppointmentsBetween(
        DateTime(2000),
        DateTime(2100),
      );
      expect(allAppts, isEmpty);
    });
  });

  group('getAppointment', () {
    // getAppointment should simply return the cached appointment.
    test('returns appointment from cache when present', () {
      apptCache.cacheAppointment(const AppointmentModel(id: 'a1'));

      final a = vm.getAppointment('a1');
      expect(a, isNotNull);
      expect(a!.id, 'a1');
    });

    // If the id is not cached, it should return null.
    test('returns null when appointment not in cache', () {
      final a = vm.getAppointment('missing');
      expect(a, isNull);
    });
  });
}
