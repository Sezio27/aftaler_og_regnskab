/* // test/unit/view_model/appointment_view_model_more_test.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────
class _MockRepo extends Mock implements AppointmentRepository {}

class _MockStorage extends Mock implements ImageStorage {}

class _AppointmentModelFake extends Fake implements AppointmentModel {}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2025));
    registerFallbackValue(_AppointmentModelFake());
  });

  late _MockRepo repo;
  late _MockStorage storage;

  // Default “do nothing” fetchers (we override in some tests)
  Future<ClientModel?> _fetchClient(String _) async => null;
  Future<ServiceModel?> _fetchService(String _) async => null;

  AppointmentViewModel _newVm({
    Future<ClientModel?> Function(String)? fetchClient,
    Future<ServiceModel?> Function(String)? fetchService,
  }) {
    return AppointmentViewModel(
      repo,
      storage,
      fetchClient: fetchClient ?? _fetchClient,
      fetchService: fetchService ?? _fetchService,
    );
  }

  // Handy helper to build a real DocumentReference id for newAppointmentRef()
  DocumentReference<Map<String, dynamic>> _fakeDocRef([String id = 'doc1']) {
    final fake = FakeFirebaseFirestore();
    return fake.collection('users/u1/appointments').doc(id);
  }

  setUp(() {
    repo = _MockRepo();
    storage = _MockStorage();
    vmTestResetFinance();
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 1) Validation paths in addAppointment (fast wins)
  // ────────────────────────────────────────────────────────────────────────────
  test('addAppointment fails when clientId is empty and sets error', () async {
    final vm = _newVm();
    final ok = await vm.addAppointment(
      clientId: '',
      serviceId: 's1',
      dateTime: DateTime.now(),
      checklistIds: const [],
      price: 100,
      status: 'Betalt',
    );
    expect(ok, isFalse);
    expect(vm.error, isNotNull);
    verifyNever(() => repo.createAppointmentWithId(any(), any()));
  });

  test('addAppointment fails when dateTime is null and sets error', () async {
    final vm = _newVm();
    final ok = await vm.addAppointment(
      clientId: 'c1',
      serviceId: 's1',
      dateTime: null,
      checklistIds: const [],
      price: 100,
      status: 'Betalt',
    );
    expect(ok, isFalse);
    expect(vm.error, isNotNull);
    verifyNever(() => repo.createAppointmentWithId(any(), any()));
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 2) Image upload path + monthly summary increment (paid)
  // ────────────────────────────────────────────────────────────────────────────
  test(
    'addAppointment uploads images and updates month summary when paid',
    () async {
      final vm = _newVm();

      // Seed Home (month summary starts at 0)
      when(
        () => repo.countAppointments(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => repo.sumPaidInRange(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 0.0);
      await vm.ensureFinanceForHomeSeeded();

      // Stub newAppointmentRef + create
      when(() => repo.newAppointmentRef()).thenReturn(_fakeDocRef('abc'));
      when(
        () => repo.createAppointmentWithId(any(), any()),
      ).thenAnswer((_) async {});

      // Stub image upload
      when(
        () => storage.uploadAppointmentImages(
          appointmentId: any(named: 'appointmentId'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async => ['https://img/1.jpg', 'https://img/2.jpg']);

      final ok = await vm.addAppointment(
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime.now(),
        checklistIds: const [],
        price: 450,
        images: [
          (
            bytes: Uint8List.fromList([1, 2, 3]),
            name: 'a.jpg',
            mimeType: 'image/jpeg',
          ),
        ],
        status: 'Betalt',
      );

      expect(ok, isTrue);

      // Summary should be +1 / +450
      final s = vm.summaryNow(Segment.month);
      expect(s.count, 1);
      expect(s.income, 450);

      // Verify storage used
      verify(
        () => storage.uploadAppointmentImages(
          appointmentId: 'abc',
          images: any(named: 'images'),
        ),
      ).called(1);

      // We also created via repo
      verify(() => repo.createAppointmentWithId('abc', any())).called(1);
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // 3) updateStatus transitions affect paidSum & status buckets when finance seeded
  // ────────────────────────────────────────────────────────────────────────────
  test(
    'updateStatus waiting -> paid updates sums & buckets for month/year/total',
    () async {
      final vm = _newVm();

      // Seed ALL segments with 0s and status counts; afterwards _financeInitialised = true
      // Month (skipSummary is false here, then Year/Total)
      when(
        () => repo.countAppointments(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 0);

      when(
        () => repo.sumPaidInRange(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 0.0);

      when(
        () => repo.countAppointments(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((inv) async {
        final s = inv.namedArguments[#status] as String?;
        if (s == 'Afventer') return 1; // seed waiting=1
        // Betalt, Forfalden, Ufaktureret -> 0
        return 0;
      });

      when(() => repo.updateStatus(any(), any())).thenAnswer((_) async {});

      await vm.ensureFinanceTotalsSeeded();

      // Update a current-month appt from 'Afventer' to 'Betalt' price 200
      await vm.updateStatus('id1', 'Afventer', 200, 'Betalt', DateTime.now());

      // Sums: +200 in month (and year/total too)
      expect(vm.summaryNow(Segment.month).income, 200);
      expect(vm.summaryNow(Segment.year).income, 200);
      expect(vm.summaryNow(Segment.total).income, 200);

      // Buckets: waiting--, paid++
      final m = vm.statusNow(Segment.month);
      expect(m.paid, 1);
      expect(m.waiting, 0);
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // 4) updateAppointmentFields: deletes empty strings, uploads new images,
  //    merges image lists and updates finance when staying in same month
  // ────────────────────────────────────────────────────────────────────────────
  test(
    'updateAppointmentFields merges/deletes correctly and adjusts paidSum deltas',
    () async {
      final vm = _newVm();

      // Seed month summary: 1 appt paid 100
      when(
        () => repo.countAppointments(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 1);
      when(
        () => repo.sumPaidInRange(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 100.0);
      await vm.ensureFinanceForHomeSeeded();

      final old = AppointmentModel(
        id: 'A1',
        clientId: 'c1',
        serviceId: 's1',
        dateTime: DateTime.now(),
        price: 100.0,
        status: 'Betalt',
        imageUrls: const ['u1', 'u2'],
        note: 'hello',
        location: 'Cph',
      );

      // Repo returns existing (for image base if currentImageUrls null)
      when(() => repo.getAppointmentOnce('A1')).thenAnswer((_) async => old);

      // Image upload adds one new
      when(
        () => storage.uploadAppointmentImages(
          appointmentId: any(named: 'appointmentId'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async => ['u3']);

      // Deleting removed images is best-effort (succeeds)
      when(
        () => storage.deleteAppointmentImagesByUrls(any()),
      ).thenAnswer((_) async {});

      // Capture the fields/deletes we send to repo
      Map<String, Object?>? sentFields;
      Set<String>? sentDeletes;

      when(
        () => repo.updateAppointment(
          any(),
          fields: any(named: 'fields'),
          deletes: any(named: 'deletes'),
        ),
      ).thenAnswer((inv) async {
        sentFields = inv.namedArguments[#fields] as Map<String, Object?>?;
        sentDeletes = inv.namedArguments[#deletes] as Set<String>?;
      });

      final ok = await vm.updateAppointmentFields(
        old,
        // make some strings empty to trigger deletes
        note: '',
        location: '',
        // change price from 100 to 150 (still paid, same month)
        price: 150.0,
        // remove one existing and add new image
        removedImageUrls: const ['u2'],
        newImages: [
          (
            bytes: Uint8List.fromList([1, 2, 3]),
            name: 'n.jpg',
            mimeType: 'image/jpeg',
          ),
        ],
      );

      expect(ok, isTrue);
      expect(sentFields, isNotNull);
      expect(sentDeletes, isNotNull);

      // Fields must include merged images u1 (kept) + u3 (uploaded)
      final imgs = (sentFields!['imageUrls'] as List).cast<String>();
      expect(imgs, containsAll(<String>['u1', 'u3']));
      expect(imgs, isNot(contains('u2')));

      // Deletes must contain note & location because we passed empty strings
      expect(sentDeletes, containsAll(<String>{'note', 'location'}));

      // Paid sum delta: +50 (150 - 100) in month
      expect(vm.summaryNow(Segment.month).income, 150.0);
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // 5) Streams/range: setInitialRange indexes days, cardsForDate prefetches names
  // ────────────────────────────────────────────────────────────────────────────
  test(
    'setInitialRange builds day indexes; cardsForDate returns enriched cards',
    () async {
      // Create VM with real fetchers returning names
      Future<ClientModel?> fc(String id) async =>
          ClientModel(id: id, name: 'Ada', phone: '123', email: 'a@b.c');
      Future<ServiceModel?> fs(String id) async =>
          ServiceModel(id: id, name: 'Hair', duration: '45');

      final vm = _newVm(fetchClient: fc, fetchService: fs);

      final today = DateTime(2025, 1, 10, 9);
      final appts = <AppointmentModel>[
        AppointmentModel(
          id: 'x1',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: today,
          status: 'Ufaktureret',
        ),
        AppointmentModel(
          id: 'x2',
          clientId: 'c1',
          serviceId: 's1',
          dateTime: today.add(const Duration(hours: 1)),
          status: 'Betalt',
        ),
      ];

      // Stream with one snapshot for initial two-month window
      when(
        () => repo.watchAppointmentsBetween(any(), any()),
      ).thenAnswer((_) => Stream<List<AppointmentModel>>.value(appts));

      await vm.setInitialRange();
      // Let the stream listener run + prefetch
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(vm.hasEventsOn(today), isTrue);

      final cards = await vm.cardsForDate(today);
      expect(cards.length, 2);
      expect(cards.first.clientName, 'Ada');
      expect(cards.first.serviceName, 'Hair');

      // Chips are built from same day index
      final chips = vm.monthChipsOn(today);
      expect(chips.length, 2);
      expect(chips.first.title, 'Ada');
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // 6) List mode: beginListRange + loadNextListMonth pulls from repo and exposes listCards
  // ────────────────────────────────────────────────────────────────────────────
  test(
    'beginListRange loads months via getAppointmentsBetween and populates listCards',
    () async {
      final vm = _newVm();

      // No initial live months -> getAppointmentsBetween must be used
      when(() => repo.getAppointmentsBetween(any(), any())).thenAnswer((
        inv,
      ) async {
        final start = inv.positionalArguments[0] as DateTime;
        // Return 1 item per month
        return <AppointmentModel>[
          AppointmentModel(
            id: 'm-${start.year}-${start.month}',
            dateTime: start.add(const Duration(days: 3, hours: 10)),
            clientId: null,
            serviceId: null,
            status: 'Ufaktureret',
          ),
        ];
      });

      // Range spanning 2 months
      final start = DateTime(2025, 2, 1);
      final end = DateTime(2025, 3, 28);

      await vm.beginListRange(start, end);
      // allow internal auto-load + possible follow-up prefetch
      await Future<void>.delayed(Duration(milliseconds: 10));

      final cards = vm.listCards;
      expect(cards.isNotEmpty, isTrue);
      // Should not crash even without client/service cache
      expect(cards.first.clientName, isEmpty);
      expect(
        vm.listHasMore,
        anyOf(isTrue, isFalse),
      ); // just ensure flag present

      // Ensure repo got called at least once
      verify(
        () => repo.getAppointmentsBetween(any(), any()),
      ).called(greaterThan(0));
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // 7) delete: removes images, deletes appt and decrements finance
  // ────────────────────────────────────────────────────────────────────────────
  test(
    'delete calls storage+repo and decrements month summary for paid appt',
    () async {
      final vm = _newVm();

      // Seed month summary with 1 paid @ 450
      when(
        () => repo.countAppointments(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 1);
      when(
        () => repo.sumPaidInRange(
          startInclusive: any(named: 'startInclusive'),
          endInclusive: any(named: 'endInclusive'),
        ),
      ).thenAnswer((_) async => 450.0);
      await vm.ensureFinanceForHomeSeeded();

      // Now delete that paid one → count 0, income 0
      when(
        () => storage.deleteAppointmentImages(any()),
      ).thenAnswer((_) async {});
      when(() => repo.deleteAppointment(any())).thenAnswer((_) async {});

      await vm.delete('id-del', 'Betalt', 450.0, DateTime.now());

      final s = vm.summaryNow(Segment.month);
      expect(s.count, 0);
      expect(s.income, 0.0);

      verify(() => storage.deleteAppointmentImages('id-del')).called(1);
      verify(() => repo.deleteAppointment('id-del')).called(1);
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // 8) statusCount aggregates 4 repo calls
  // ────────────────────────────────────────────────────────────────────────────
  test('statusCount aggregates counts for all statuses', () async {
    final vm = _newVm();
    // Return different numbers per invocation (paid, waiting, missing, uninvoiced)
    when(
      () => repo.countAppointments(
        startInclusive: any(named: 'startInclusive'),
        endInclusive: any(named: 'endInclusive'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((i) async {
      final status = i.namedArguments[#status] as String?;
      switch (status) {
        case 'Betalt':
          return 3;
        case 'Afventer':
          return 2;
        case 'Forfalden':
          return 1;
        case 'Ufaktureret':
          return 4;
      }
      return 0;
    });

    final r = await vm.statusCount(DateTime(2025, 1, 1), DateTime(2025, 1, 31));
    expect(r.paid, 3);
    expect(r.waiting, 2);
    expect(r.missing, 1);
    expect(r.uninvoiced, 4);
  });
}
 */
