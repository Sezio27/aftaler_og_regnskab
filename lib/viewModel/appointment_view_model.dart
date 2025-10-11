import 'dart:async';
import 'dart:developer' as dev;
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef UploadAppointmentImages =
    Future<List<String>> Function({
      required String appointmentId,
      required List<XFile> files,
    });
typedef DeleteAppointmentImages = Future<void> Function(String appointmentId);

typedef FetchClient = Future<ClientModel?> Function(String clientId);
typedef FetchService = Future<ServiceModel?> Function(String serviceId);

/// Lightweight data for month grid chips
typedef MonthChip = ({String title, String status, DateTime time});

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo, {
    required this.fetchClient,
    required this.fetchService,
    this.uploadImages,
    this.deleteImages,
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Dependencies
  // ────────────────────────────────────────────────────────────────────────────
  final AppointmentRepository _repo;
  final FetchClient fetchClient;
  final FetchService fetchService;
  final UploadAppointmentImages? uploadImages;
  final DeleteAppointmentImages? deleteImages;

  // ────────────────────────────────────────────────────────────────────────────
  // Range-driven stream + current data
  // ────────────────────────────────────────────────────────────────────────────
  StreamSubscription<List<AppointmentModel>>? _rangeSubscription;

  DateTime? _activeRangeStart; // inclusive (00:00 of day)
  DateTime? _activeRangeEnd; // inclusive (00:00 of day)

  /// Appointments inside the current active range
  List<AppointmentModel> _rangeAppointments = const [];
  List<AppointmentModel> get all => _rangeAppointments;

  /// Quick lookup sets and maps for calendar queries
  final Set<DateTime> _daysWithAppointments = <DateTime>{}; // date-only
  final Map<DateTime, List<AppointmentModel>> _appointmentsByDay = {};

  // ────────────────────────────────────────────────────────────────────────────
  // Simple UI state flags
  // ────────────────────────────────────────────────────────────────────────────
  bool _isSaving = false;
  String? _lastErrorMessage;
  AppointmentModel? _lastCreatedAppointment;

  bool get saving => _isSaving;
  String? get error => _lastErrorMessage;
  AppointmentModel? get lastAdded => _lastCreatedAppointment;

  // ────────────────────────────────────────────────────────────────────────────
  // Caches for related documents (client/service) to avoid refetching
  // ────────────────────────────────────────────────────────────────────────────
  final Map<String, ClientModel?> _clientCache = {};
  final Map<String, Future<ClientModel?>> _clientInFlight = {};
  final Map<String, ServiceModel?> _serviceCache = {};
  final Map<String, Future<ServiceModel?>> _serviceInFlight = {};

  @override
  void dispose() {
    _rangeSubscription?.cancel();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Range subscription control
  // ────────────────────────────────────────────────────────────────────────────
  /// Call this whenever month/week visible range changes.
  /// Subscribes only to appointments within [start]..[end] (by `dateTime`).
  void setActiveRange(
    DateTime start,
    DateTime end, {
    String label = 'VM:setActiveRange',
  }) {
    final rangeStart = _asDateOnly(start);
    final rangeEnd = _asDateOnly(end);
    if (_activeRangeStart != null && _activeRangeEnd != null) {
      final newIsWithinCurrent =
          !rangeStart.isBefore(_activeRangeStart!) &&
          !rangeEnd.isAfter(_activeRangeEnd!);
      if (newIsWithinCurrent) {
        // No-op: keep the big stream; prevents re-attaching and losing Year.
        return;
      }
    }
    final rangeIsSame =
        _activeRangeStart == rangeStart && _activeRangeEnd == rangeEnd;
    if (rangeIsSame) return;

    _activeRangeStart = rangeStart;
    _activeRangeEnd = rangeEnd;

    _rangeSubscription?.cancel();

    final inclusiveEnd = rangeEnd
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    final startedAt = DateTime.now();
    final task = dev.TimelineTask()
      ..start('$label attach $rangeStart..$rangeEnd');

    _rangeSubscription = _repo
        .watchAppointmentsBetween(rangeStart, inclusiveEnd)
        .listen((fetched) async {
          _rangeAppointments = fetched;
          _rebuildDailyIndexes(fetched);

          // Resolve client/service display data used in month/week UIs.
          await _prefetchNamesForActiveRange();

          final dur = DateTime.now().difference(startedAt);
          task.finish();
          debugPrint('$label ready=${dur.inMilliseconds}ms');

          notifyListeners();
        });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CRUD
  // ────────────────────────────────────────────────────────────────────────────
  Future<bool> addAppointment({
    required String? clientId,
    required String? serviceId,
    required DateTime? dateTime,
    required List<String> checklistIds,
    String? location,
    String? note,
    String? customPriceText,
    List<XFile>? images,
    String status = 'not_invoiced',
  }) async {
    if ((clientId ?? '').isEmpty) {
      _lastErrorMessage = 'Vælg klient';
      notifyListeners();
      return false;
    }
    if (dateTime == null) {
      _lastErrorMessage = 'Vælg dato og tid';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      // Determine price: prefer custom, else service.price
      String? chosenPrice = _trimOrNull(customPriceText);
      if ((chosenPrice == null || chosenPrice.isEmpty) &&
          (serviceId ?? '').isNotEmpty) {
        final svc = await _fetchServiceCached(serviceId!);
        chosenPrice = _trimOrNull(svc?.price);
      }

      final created = await _repo.addAppointment(
        AppointmentModel(
          clientId: clientId,
          serviceId: serviceId,
          checklistIds: checklistIds,
          dateTime: dateTime,
          price: chosenPrice,
          location: _trimOrNull(location),
          note: _trimOrNull(note),
          imageUrls: const [],
          status: status,
        ),
      );

      // Optional image upload
      if (uploadImages != null &&
          (images?.isNotEmpty ?? false) &&
          (created.id ?? '').isNotEmpty) {
        final uploadedUrls = await uploadImages!(
          appointmentId: created.id!,
          files: images!,
        );
        if (uploadedUrls.isNotEmpty) {
          await _repo.updateAppointment(
            created.id!,
            fields: {'imageUrls': uploadedUrls},
          );
          _lastCreatedAppointment = created.copyWith(imageUrls: uploadedUrls);
        } else {
          _lastCreatedAppointment = created;
        }
      } else {
        _lastCreatedAppointment = created;
      }

      return true;
    } catch (e) {
      _lastErrorMessage = 'Kunne ikke oprette aftale: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateAppointmentFields(
    String id, {
    String? clientId,
    String? serviceId,
    List<String>? checklistIds,
    DateTime? dateTime,
    String? location,
    String? note,
    String? customPrice,
    String? servicePrice,
    String? status,
    List<String>? imageUrls,
  }) async {
    _isSaving = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final fields = <String, Object?>{};
      void put(String key, Object? value) {
        if (value != null) fields[key] = value;
      }

      put('clientId', _trimOrNull(clientId));
      put('serviceId', _trimOrNull(serviceId));

      if (checklistIds != null) {
        put(
          'checklistIds',
          checklistIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        );
      }

      if (dateTime != null) {
        put('dateTime', Timestamp.fromDate(dateTime));
      }

      put('location', _trimOrNull(location));
      put('note', _trimOrNull(note));
      put('status', _trimOrNull(status));

      if (imageUrls != null) {
        put(
          'imageUrls',
          imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        );
      }

      // Price: prefer customPrice over servicePrice if provided
      final chosenPrice = _firstNonEmpty([
        _trimOrNull(customPrice),
        _trimOrNull(servicePrice),
      ]);
      if (chosenPrice != null) {
        put('price', chosenPrice);
      }

      if (fields.isNotEmpty) {
        await _repo.updateAppointment(id, fields: fields);
      }

      return true;
    } catch (e) {
      _lastErrorMessage = 'Kunne ikke opdatere: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  List<AppointmentModel> getAppointmentsInRange(DateTime start, DateTime end) {
    final from = _asDateOnly(start);
    final to = _asDateOnly(end);
    if (to.isBefore(from)) return const [];

    final hits = _rangeAppointments.where((a) {
      final dt = a.dateTime;
      return dt != null && !dt.isBefore(from) && !dt.isAfter(to);
    }).toList();

    final appointmentsInRange = <AppointmentModel>[];

    var currentDay = from;
    while (!currentDay.isAfter(to)) {
      final appointmentsOnDay = _appointmentsByDay[currentDay];
      if (appointmentsOnDay != null && appointmentsOnDay.isNotEmpty) {
        appointmentsInRange.addAll(appointmentsOnDay);
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }

    hits.sort((a, b) {
      final at = a.dateTime, bt = b.dateTime;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });

    return hits;
  }

  int countAppointmentsInRange(DateTime start, DateTime end) {
    return getAppointmentsInRange(start, end).length;
  }

  // 3) Sum prices for appointments in the range where status == "betalt".
  double sumPaidInRangeDKK(DateTime start, DateTime end) {
    final items = getAppointmentsInRange(start, end);
    double total = 0;
    for (final a in items) {
      final status = (a.status ?? '').toLowerCase();
      if (status == 'betalt') {
        total += _parsePrice(a.price);
      }
    }
    return total;
  }

  // --- super simple price parser: "1200", "1.200", "1.200,50", "1200 kr", "DKK 1 200"
  double _parsePrice(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    var s = raw.toLowerCase();
    // remove currency words and spaces
    s = s.replaceAll(RegExp(r'(dkk|kr|\s)'), '');
    // make comma decimal and remove thousands dots
    s = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  Future<void> delete(String id, {bool deleteStorage = true}) async {
    if (deleteStorage && deleteImages != null) {
      await deleteImages!(id);
    }
    await _repo.deleteAppointment(id);
  }

  // Detail helpers
  Stream<AppointmentModel?> watchAppointmentById(String id) =>
      _repo.watchAppointmentById(id);

  Future<AppointmentModel?> getAppointment(String id) =>
      _repo.getAppointmentOnce(id);

  // ────────────────────────────────────────────────────────────────────────────
  // Calendar adapters (used by month/week UIs)
  // ────────────────────────────────────────────────────────────────────────────
  /// Month grid chips (synchronous, cheap)
  List<MonthChip> monthChipsOn(DateTime day) {
    final dateOnly = _asDateOnly(day);
    final items = _appointmentsByDay[dateOnly] ?? const <AppointmentModel>[];

    final chips = <MonthChip>[];
    for (final appt in items) {
      final clientName = _clientCache[appt.clientId ?? '']?.name ?? '';
      final time = appt.dateTime!;
      final status = appt.status ?? 'not_invoiced';
      chips.add((title: clientName, status: status, time: time));
    }
    chips.sort((a, b) => a.time.compareTo(b.time));
    return chips;
  }

  bool hasEventsOn(DateTime day) =>
      _daysWithAppointments.contains(_asDateOnly(day));

  /// Build UI-ready cards for a specific date (prefetches client/service first).
  Future<List<AppointmentCardModel>> cardsForDate(DateTime day) async {
    final dateOnly = _asDateOnly(day);
    final todays = List<AppointmentModel>.from(
      _appointmentsByDay[dateOnly] ?? const <AppointmentModel>[],
    )..sort((a, b) => a.dateTime!.compareTo(b.dateTime!));

    final uniqueClientIds = {
      for (final a in todays)
        if ((a.clientId ?? '').isNotEmpty) a.clientId!,
    };
    final uniqueServiceIds = {
      for (final a in todays)
        if ((a.serviceId ?? '').isNotEmpty) a.serviceId!,
    };

    await Future.wait([
      for (final id in uniqueClientIds) _fetchClientCached(id),
      for (final id in uniqueServiceIds) _fetchServiceCached(id),
    ]);

    return todays.map((appt) {
      final client = _clientCache[appt.clientId ?? ''];
      final service = _serviceCache[appt.serviceId ?? ''];

      final chosenPrice = _firstNonEmpty([
        _trimOrNull(appt.price),
        _trimOrNull(service?.price),
      ]);

      return AppointmentCardModel(
        clientName: client?.name ?? '',
        serviceName: service?.name ?? '',
        phone: client?.phone,
        email: client?.email,
        time: appt.dateTime!,
        price: chosenPrice,
        duration: service?.duration,
        status: appt.status ?? 'ufaktureret',
        imageUrl: client?.image,
      );
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal: indexing
  // ────────────────────────────────────────────────────────────────────────────
  void _rebuildDailyIndexes(List<AppointmentModel> items) {
    _appointmentsByDay.clear();
    _daysWithAppointments.clear();

    for (final appt in items) {
      final dt = appt.dateTime;
      if (dt == null) continue;

      final day = _asDateOnly(dt);
      (_appointmentsByDay[day] ??= <AppointmentModel>[]).add(appt);
      _daysWithAppointments.add(day);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal: prefetch display names for current range
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _prefetchNamesForActiveRange() async {
    if (_activeRangeStart == null || _activeRangeEnd == null) return;

    final clientIdsToFetch = <String>{};
    final serviceIdsToFetch = <String>{};

    for (final entry in _appointmentsByDay.entries) {
      final day = entry.key;
      if (day.isBefore(_activeRangeStart!) || day.isAfter(_activeRangeEnd!)) {
        continue;
      }
      for (final appt in entry.value) {
        final c = (appt.clientId ?? '').trim();
        if (c.isNotEmpty && !_clientCache.containsKey(c)) {
          clientIdsToFetch.add(c);
        }
        final s = (appt.serviceId ?? '').trim();
        if (s.isNotEmpty && !_serviceCache.containsKey(s)) {
          serviceIdsToFetch.add(s);
        }
      }
    }

    if (clientIdsToFetch.isEmpty && serviceIdsToFetch.isEmpty) return;

    await Future.wait([
      for (final id in clientIdsToFetch) _fetchClientCached(id),
      for (final id in serviceIdsToFetch) _fetchServiceCached(id),
    ]);

    // Names resolved → allow UI to show real titles in chips immediately.
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal: caching helpers
  // ────────────────────────────────────────────────────────────────────────────
  Future<ClientModel?> _fetchClientCached(String id) async {
    if (_clientCache.containsKey(id)) return _clientCache[id];
    final inFlight = _clientInFlight[id];
    if (inFlight != null) return inFlight;

    final future = fetchClient(id).then((value) {
      _clientCache[id] = value;
      _clientInFlight.remove(id);
      return value;
    });
    _clientInFlight[id] = future;
    return future;
  }

  Future<ServiceModel?> _fetchServiceCached(String id) async {
    if (_serviceCache.containsKey(id)) return _serviceCache[id];
    final inFlight = _serviceInFlight[id];
    if (inFlight != null) return inFlight;

    final future = fetchService(id).then((value) {
      _serviceCache[id] = value;
      _serviceInFlight.remove(id);
      return value;
    });
    _serviceInFlight[id] = future;
    return future;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Utilities
  // ────────────────────────────────────────────────────────────────────────────
  DateTime _asDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String? _trimOrNull(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }
}
