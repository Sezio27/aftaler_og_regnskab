import 'dart:async';
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
typedef MonthChip = ({String title, String status, DateTime time});

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo, {
    required this.fetchClient,
    required this.fetchService,
    this.uploadImages,
    this.deleteImages,
  });

  final AppointmentRepository _repo;
  final FetchClient fetchClient;
  final FetchService fetchService;
  final UploadAppointmentImages? uploadImages;
  final DeleteAppointmentImages? deleteImages;

  StreamSubscription<List<AppointmentModel>>? _sub;

  /// All appointments from the current subscription.
  List<AppointmentModel> _all = const [];
  List<AppointmentModel> get all => _all;

  /// Fast, sync lookup: which (local) dates have events?
  final Set<DateTime> _daysWithEvents = {};

  /// Per-day index to avoid scanning all on each query.
  final Map<DateTime, List<AppointmentModel>> _byDay = {};

  /// Caches to avoid refetching the same client/service repeatedly.
  final Map<String, ClientModel?> _clientCache = {};
  final Map<String, Future<ClientModel?>> _clientPending = {};
  final Map<String, ServiceModel?> _serviceCache = {};
  final Map<String, Future<ServiceModel?>> _servicePending = {};

  bool _saving = false;
  String? _error;
  AppointmentModel? _lastAdded;

  bool get saving => _saving;
  String? get error => _error;
  AppointmentModel? get lastAdded => _lastAdded;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Start listening. Keep as a single source of truth.
  void init() {
    if (_sub != null) return;
    _sub = _repo.watchAppointments().listen((items) {
      _all = items;
      _rebuildIndexes(items);
      notifyListeners();
    });
  }

  // ---- Minimal pass-throughs (avoid redundant methods) ----
  Stream<List<AppointmentModel>> watchAppointments() =>
      _repo.watchAppointments();

  Stream<AppointmentModel?> watchAppointmentById(String id) =>
      _repo.watchAppointmentById(id);

  Future<AppointmentModel?> getAppointment(String id) =>
      _repo.getAppointmentOnce(id);

  // -------------------- Create --------------------
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
      _error = 'Vælg klient';
      notifyListeners();
      return false;
    }
    if (dateTime == null) {
      _error = 'Vælg dato og tid';
      notifyListeners();
      return false;
    }

    _saving = true;
    _error = null;
    notifyListeners();
    try {
      // Prefer custom price; else fall back to service.price
      String? price = _clean(customPriceText);
      if ((price == null || price.isEmpty) && (serviceId ?? '').isNotEmpty) {
        final svc = await _getService(serviceId!);
        price = _clean(svc?.price);
      }

      final created = await _repo.addAppointment(
        AppointmentModel(
          clientId: clientId,
          serviceId: serviceId,
          checklistIds: checklistIds,
          dateTime: dateTime,
          price: price,
          location: _clean(location),
          note: _clean(note),
          imageUrls: const [],
          status: status,
        ),
      );

      if (uploadImages != null &&
          (images?.isNotEmpty ?? false) &&
          (created.id ?? '').isNotEmpty) {
        final urls = await uploadImages!(
          appointmentId: created.id!,
          files: images!,
        );
        if (urls.isNotEmpty) {
          await _repo.updateAppointment(
            created.id!,
            fields: {'imageUrls': urls},
          );
          _lastAdded = created.copyWith(imageUrls: urls);
        } else {
          _lastAdded = created;
        }
      } else {
        _lastAdded = created;
      }

      return true;
    } catch (e) {
      _error = 'Kunne ikke oprette aftale: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // -------------------- Update (patch fields) --------------------
  Future<bool> updateAppointmentFields(
    String id, {
    String? clientId,
    String? serviceId,
    List<String>? checklistIds,
    DateTime? dateTime,
    String? location,
    String? note,
    String? customPrice,
    String? servicePrice, // optional direct override
    String? status,
    List<String>? imageUrls,
  }) async {
    try {
      _saving = true;
      _error = null;
      notifyListeners();

      final fields = <String, Object?>{};
      void put(String k, Object? v) {
        if (v != null) fields[k] = v;
      }

      put('clientId', _clean(clientId));
      put('serviceId', _clean(serviceId));
      if (checklistIds != null) {
        put(
          'checklistIds',
          checklistIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        );
      }
      if (dateTime != null) put('dateTime', Timestamp.fromDate(dateTime));
      put('location', _clean(location));
      put('note', _clean(note));
      put('status', _clean(status));
      if (imageUrls != null) {
        put(
          'imageUrls',
          imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        );
      }

      // choose customPrice > servicePrice if provided
      final chosen = _firstNonEmpty([
        _clean(customPrice),
        _clean(servicePrice),
      ]);
      if (chosen != null) put('price', chosen);

      if (fields.isNotEmpty) await _repo.updateAppointment(id, fields: fields);
      return true;
    } catch (e) {
      _error = 'Kunne ikke opdatere: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // -------------------- Delete --------------------
  Future<void> delete(String id, {bool deleteStorage = true}) async {
    if (deleteStorage && deleteImages != null) {
      await deleteImages!(id);
    }
    await _repo.deleteAppointment(id);
  }

  // -------------------- Calendar helpers --------------------
  /// **Sync** boolean for your dot in Week/Month views.
  // --- MONTH (sync, lightweight) ---
  List<MonthChip> monthChipsOn(DateTime day) {
    final d = _dateOnly(day);
    final items = _byDay[d] ?? const [];

    return items.map((a) {
      final client = _clientCache[a.clientId ?? ''];
      final title = client?.name ?? "";

      return (title: title, status: a.status!, time: a.dateTime!);
    }).toList()..sort((x, y) => x.time.compareTo(y.time));
  }

  /// Prefetch names for the visible range (no duplicates, no refetch).
  Future<void> prefetchForRange(DateTime start, DateTime end) async {
    // gather unique ids in range
    final idsClient = <String>{};
    final idsService = <String>{};

    for (
      var d = _dateOnly(start);
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    ) {
      for (final a in _byDay[d] ?? const <AppointmentModel>[]) {
        final c = (a.clientId ?? '').trim();
        if (c.isNotEmpty && !_clientCache.containsKey(c)) idsClient.add(c);
        final s = (a.serviceId ?? '').trim();
        if (s.isNotEmpty && !_serviceCache.containsKey(s)) idsService.add(s);
      }
    }

    if (idsClient.isEmpty && idsService.isEmpty) return;

    await Future.wait([
      for (final id in idsClient) _getClient(id),
      for (final id in idsService) _getService(id),
    ]);

    // names resolved -> re-render month grid with real titles
    notifyListeners();
  }

  bool hasEventsOn(DateTime day) => _daysWithEvents.contains(_dateOnly(day));

  /// Build *UI-ready* card models for all appointments on [day] (local time).
  Future<List<AppointmentCardModel>> cardsForDate(DateTime day) async {
    final d = _dateOnly(day);
    final todays = List<AppointmentModel>.from(_byDay[d] ?? const [])
      ..sort((a, b) => a.dateTime!.compareTo(b.dateTime!));

    // Pre-fetch distinct clients/services (memoized).
    final clientIds = todays
        .map((a) => a.clientId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final serviceIds = todays
        .map((a) => a.serviceId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    await Future.wait([
      for (final id in clientIds) _getClient(id),
      for (final id in serviceIds) _getService(id),
    ]);

    // Build cards using cached data.
    return todays.map((appt) {
      final client = _clientCache[appt.clientId ?? ''];
      final service = _serviceCache[appt.serviceId ?? ''];

      final price = _firstNonEmpty([
        _clean(appt.price),
        _clean(service?.price),
      ]);

      return AppointmentCardModel(
        clientName: client?.name ?? "",
        serviceName: service?.name ?? "",
        phone: client?.phone,
        email: client?.email,
        time: appt.dateTime!,
        price: price,
        duration: service?.duration,
        status: appt.status ?? 'ufaktureret',
      );
    }).toList();
  }

  // -------------------- Internal indexing --------------------
  void _rebuildIndexes(List<AppointmentModel> items) {
    _byDay.clear();
    _daysWithEvents.clear();

    for (final a in items) {
      final dt = a.dateTime;
      if (dt == null) continue;

      final day = _dateOnly(dt);
      (_byDay[day] ??= <AppointmentModel>[]).add(a);
      _daysWithEvents.add(day);
    }
  }

  // -------------------- Caching helpers --------------------
  Future<ClientModel?> _getClient(String id) async {
    if (_clientCache.containsKey(id)) return _clientCache[id];
    final pending = _clientPending[id];
    if (pending != null) return pending;

    final f = fetchClient(id).then((v) {
      _clientCache[id] = v;
      _clientPending.remove(id);
      return v;
    });
    _clientPending[id] = f;
    return f;
  }

  Future<ServiceModel?> _getService(String id) async {
    if (_serviceCache.containsKey(id)) return _serviceCache[id];
    final pending = _servicePending[id];
    if (pending != null) return pending;

    final f = fetchService(id).then((v) {
      _serviceCache[id] = v;
      _servicePending.remove(id);
      return v;
    });
    _servicePending[id] = f;
    return f;
  }

  // -------------------- Utilities --------------------
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String? _clean(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }

  String? _firstNonEmpty(List<String?> xs) {
    for (final x in xs) {
      final t = (x ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }
}
