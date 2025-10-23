import 'dart:async';
import 'dart:typed_data';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef FetchClient = Future<ClientModel?> Function(String clientId);
typedef FetchService = Future<ServiceModel?> Function(String serviceId);

typedef MonthChip = ({String title, String status, DateTime time});

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo,
    this._imageStorage, {
    required this.fetchClient,
    required this.fetchService,
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Dependencies
  // ────────────────────────────────────────────────────────────────────────────
  final AppointmentRepository _repo;
  final FetchClient fetchClient;
  final FetchService fetchService;
  final ImageStorage _imageStorage;

  /// Appointments inside the current active range

  List<AppointmentModel> _rangeAppointments = const [];
  List<AppointmentModel> get all => _rangeAppointments;

  /// Quick lookup sets and maps for calendar queries
  final Map<DateTime, List<AppointmentModel>> _appointmentsByDay = {};

  // ────────────────────────────────────────────────────────────────────────────
  // Simple UI state flags
  // ────────────────────────────────────────────────────────────────────────────
  bool isReady = false;
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
    _initialSubscription?.cancel();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Range subscription control
  // ────────────────────────────────────────────────────────────────────────────
  /// Call this whenever month/week visible range changes.
  /// Subscribes only to appointments within [start]..[end] (by `dateTime`).
  ///
  StreamSubscription<List<AppointmentModel>>? _initialSubscription;
  final Map<DateTime, StreamSubscription<List<AppointmentModel>>>
  _windowSubscriptions = {};
  List<AppointmentModel> _initialAppointments = [];
  final Map<DateTime, List<AppointmentModel>> _windowAppointments = {};
  DateTime? _initialStart;
  DateTime? _initialEnd;
  DateTime? _activeMonthStart;

  Future<bool> _prefetchForInitialRange() async {
    return await _prefetchClientsAndServices(_initialStart!, _initialEnd!);
  }

  Future<bool> _prefetchForWindowRange(DateTime start, DateTime end) async {
    return await _prefetchClientsAndServices(start, end);
  }

  bool _isMonthCoveredByInitial(DateTime monthStart) {
    final monthEnd = endOfMonthInclusive(monthStart);
    return !monthStart.isBefore(_initialStart!) &&
        !monthEnd.isAfter(_initialEnd!);
  }

  Future<void> setInitialRange({String label = 'VM:setInitialRange'}) async {
    if (_initialSubscription != null) return; // already set

    final now = DateTime.now();
    final start = startOfMonth(now);
    final end = endOfMonthInclusive(DateTime(now.year, now.month + 1, 1));

    _initialStart = start;
    _initialEnd = end;

    final startedAt = DateTime.now();
    var firstSnapshot = true;
    _initialSubscription = _repo.watchAppointmentsBetween(start, end).listen((
      fetched,
    ) async {
      _initialAppointments = fetched;
      _updateAppointments();
      notifyListeners();
      if (firstSnapshot) {
        debugPrint(
          '$label first_snapshot=${DateTime.now().difference(startedAt).inMilliseconds}ms',
        );
        firstSnapshot = false;
      }

      final changed = await _prefetchForInitialRange();
      if (changed) {
        notifyListeners();
      }
    });
  }

  void setActiveWindow(
    DateTime visibleDate, {
    String label = 'VM:setActiveWindow',
  }) {
    if (_isMonthCoveredByInitial(visibleDate)) return;
    final newMonthStart = startOfMonth(visibleDate);

    if (_activeMonthStart == newMonthStart) return; // Same month, no change

    _activeMonthStart = newMonthStart;

    // Compute 3-month window starts: previous, current, next
    final windowMonthStarts = [
      addMonths(newMonthStart, -1),
      newMonthStart,
      addMonths(newMonthStart, 1),
    ];

    // Determine required non-overlapping months
    final requiredMonths = <DateTime>[];
    for (final monthStart in windowMonthStarts) {
      if (!_isMonthCoveredByInitial(monthStart)) {
        requiredMonths.add(monthStart);
      }
    }

    // Subscribe to new required months if not already
    for (final monthStart in requiredMonths) {
      if (!_windowSubscriptions.containsKey(monthStart)) {
        debugPrint("Måned: $monthStart");
        final monthEnd = endOfMonthInclusive(monthStart);
        final startedAt = DateTime.now();
        var firstSnapshot = true;
        _windowSubscriptions[monthStart] = _repo
            .watchAppointmentsBetween(monthStart, monthEnd)
            .listen((fetched) async {
              _windowAppointments[monthStart] = fetched;
              _updateAppointments();
              if (firstSnapshot) {
                debugPrint(
                  '$label [$monthStart] first_snapshot=${DateTime.now().difference(startedAt).inMilliseconds}ms',
                );
                firstSnapshot = false;
              }

              final changed = await _prefetchForWindowRange(
                monthStart,
                monthEnd,
              );
              if (changed) {
                notifyListeners();
              }
            });
      }
    }

    // Cleanup old window months not required anymore
    final currentRequiredSet = requiredMonths.toSet();
    final oldKeys = List.from(_windowSubscriptions.keys);
    var removedAny = false;
    for (final key in oldKeys) {
      if (!currentRequiredSet.contains(key)) {
        _windowSubscriptions[key]?.cancel();
        _windowSubscriptions.remove(key);
        _windowAppointments.remove(key);
        removedAny = true;
      }
    }

    if (removedAny) {
      _updateAppointments();
    }
  }

  void _updateAppointments() {
    var allAppointments = [..._initialAppointments];
    for (var list in _windowAppointments.values) {
      allAppointments.addAll(list);
    }
    allAppointments.sort(
      (a, b) =>
          (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)),
    );
    _rangeAppointments = allAppointments;
    _buildDailyIndexes(allAppointments);
    if (!isReady) isReady = true;
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CRUD
  // ────────────────────────────────────────────────────────────────────────────
  Future<bool> addAppointment({
    required String? clientId,
    required String? serviceId,
    required DateTime? dateTime,
    required List<String> checklistIds,
    DateTime? payDate,
    String? location,
    String? note,
    String? customPriceText,
    List<({Uint8List bytes, String name, String? mimeType})>? images,
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
      final docRef = _repo.newAppointmentRef();
      List<String> imageUrls = const [];

      if (images != null && images.isNotEmpty) {
        imageUrls = await _imageStorage.uploadAppointmentImages(
          appointmentId: docRef.id,
          images: images,
        );
      }

      String? chosenPrice = _trimOrNull(customPriceText);
      if ((chosenPrice == null || chosenPrice.isEmpty) &&
          (serviceId ?? '').isNotEmpty) {
        final svc = await _fetchServiceCached(serviceId!);
        chosenPrice = _trimOrNull(svc?.price);
      }

      final model = AppointmentModel(
        clientId: clientId,
        serviceId: serviceId,
        checklistIds: checklistIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        dateTime: dateTime,
        payDate: payDate,
        price: chosenPrice,
        location: _trimOrNull(location),
        note: _trimOrNull(note),
        imageUrls: imageUrls,
        status: status,
      );
      await _repo.createAppointmentWithId(docRef.id, model);

      return true;
    } catch (e) {
      _lastErrorMessage = 'Kunne ikke oprette aftale: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    await _repo.updateStatus(id, newStatus);
    notifyListeners();
  }

  Future<bool> updateAppointmentFields(
    String id, {
    String? clientId,
    String? serviceId,
    List<String>? checklistIds,
    DateTime? dateTime,
    DateTime? payDate,
    String? location,
    String? note,
    String? customPrice,
    String? servicePrice,
    String? status,
    List<String>? currentImageUrls,
    List<String> removedImageUrls = const [],
    List<({Uint8List bytes, String name, String? mimeType})> newImages =
        const [],
  }) async {
    _isSaving = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      // 1) Upload new images first
      List<String> uploadedUrls = const [];
      if (newImages.isNotEmpty) {
        uploadedUrls = await _imageStorage.uploadAppointmentImages(
          appointmentId: id,
          images: newImages,
        );
      }

      // 2) Base image list (0 reads if currentImageUrls provided)
      final existingImages =
          currentImageUrls ??
          (await _repo.getAppointmentOnce(id))?.imageUrls ??
          const <String>[];

      // 3) Compute final list locally (remove + add + dedupe)
      final removedSet = removedImageUrls.toSet();
      final kept = existingImages.where((u) => !removedSet.contains(u));
      final finalImageUrls = <String>{...kept, ...uploadedUrls}.toList();

      // 4) Build fields (empty string => delete), like Client updater
      final fields = <String, Object?>{'imageUrls': finalImageUrls};
      final deletes = <String>{};

      void putStr(String key, String? v) {
        if (v == null) return;
        final t = v.trim();
        if (t.isEmpty) {
          deletes.add(key);
        } else {
          fields[key] = t;
        }
      }

      void putTs(String key, DateTime? v) {
        if (v != null) fields[key] = Timestamp.fromDate(v);
      }

      // Scalars
      putStr('clientId', clientId);
      putStr('serviceId', serviceId);
      putStr('location', location);
      putStr('note', note);
      putStr('status', status);
      putTs('dateTime', dateTime);
      putTs('payDate', payDate);

      // Price: prefer custom, else service, and allow clearing
      if (customPrice != null || servicePrice != null) {
        final chosen =
            ((customPrice ?? '').isNotEmpty ? customPrice : servicePrice) ?? '';
        final t = chosen.trim();
        if (t.isEmpty) {
          deletes.add('price');
        } else {
          fields['price'] = t;
        }
      }

      // Lists
      if (checklistIds != null) {
        fields['checklistIds'] = checklistIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (fields.isNotEmpty || deletes.isNotEmpty) {
        await _repo.updateAppointment(id, fields: fields, deletes: deletes);
      }

      if (removedImageUrls.isNotEmpty) {
        try {
          await _imageStorage.deleteAppointmentImagesByUrls(removedImageUrls);
        } catch (_) {}
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
    return _rangeAppointments.where((a) {
      final dt = a.dateTime;
      return dt != null &&
          !dt.isBefore(dateOnly(start)) &&
          !dt.isAfter(endOfDayInclusive(dateOnly(end)));
    }).toList();
  }

  int countAppointmentsInRange(DateTime start, DateTime end) {
    return getAppointmentsInRange(start, end).length;
  }

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

  double _parsePrice(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    var s = raw.toLowerCase();
    s = s.replaceAll(RegExp(r'(dkk|kr|\s)'), '');
    s = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  ({int paid, int waiting, int missing, int uninvoiced}) statusCount(
    DateTime start,
    DateTime end,
  ) {
    var paid = 0, waiting = 0, missing = 0, uninvoiced = 0;

    final items = getAppointmentsInRange(start, end);

    for (final a in items) {
      switch ((a.status ?? '').toLowerCase()) {
        case 'betalt':
          paid++;
          break;
        case 'afventer':
          waiting++;
          break;
        case 'forfalden':
          missing++;
          break;
        case 'ufaktureret':
          uninvoiced++;
          break;
      }
    }

    return (
      paid: paid,
      waiting: waiting,
      missing: missing,
      uninvoiced: uninvoiced,
    );
  }

  Future<void> delete(String id) async {
    try {
      await _imageStorage.deleteAppointmentImages(id);
    } catch (_) {}
    await _repo.deleteAppointment(id);
  }

  // Detail helpers
  Stream<AppointmentModel?> watchAppointmentById(String id) =>
      _repo.watchAppointment(id);

  List<AppointmentCardModel> cardsForRange(DateTime start, DateTime end) {
    final appts = getAppointmentsInRange(start, end);

    final out = <AppointmentCardModel>[];
    for (final appt in appts) {
      if (appt.id == null || appt.dateTime == null) continue;
      final client = _clientCache[appt.clientId ?? ''];
      final service = _serviceCache[appt.serviceId ?? ''];
      final chosenPrice = _firstNonEmpty([
        _trimOrNull(appt.price),
        _trimOrNull(service?.price),
      ]);
      out.add(
        AppointmentCardModel(
          id: appt.id!,
          clientName: client?.name ?? '',
          serviceName: service?.name ?? '',
          phone: client?.phone,
          email: client?.email,
          time: appt.dateTime!,
          price: chosenPrice,
          duration: service?.duration,
          status: appt.status ?? 'ufaktureret',
          imageUrl: client?.image,
        ),
      );
    }
    return out;
    ;
  }

  List<MonthChip> monthChipsOn(DateTime day) {
    final date = dateOnly(day);
    final items = _appointmentsByDay[date] ?? const <AppointmentModel>[];

    final chips = <MonthChip>[];
    for (final appt in items) {
      final clientName = _clientCache[appt.clientId ?? '']?.name ?? '';
      final time = appt.dateTime!;
      final status = appt.status ?? 'not_invoiced';
      chips.add((title: clientName, status: status, time: time));
    }
    return chips;
  }

  bool hasEventsOn(DateTime day) {
    final d = dateOnly(day);
    final list = _appointmentsByDay[d];
    return list != null && list.isNotEmpty;
  }

  /// Build UI-ready cards for a specific date (prefetches client/service first).
  Future<List<AppointmentCardModel>> cardsForDate(DateTime day) async {
    final date = dateOnly(day);
    final appointmentsOnDay =
        _appointmentsByDay[date] ?? const <AppointmentModel>[];
    // No sort needed: repo orders by dateTime and _rebuildDailyIndexes preserves it.

    // Fetch only what’s missing from caches
    final clientsToFetch = <String>{
      for (final a in appointmentsOnDay)
        if ((a.clientId ?? '').isNotEmpty &&
            !_clientCache.containsKey(a.clientId))
          a.clientId!,
    };
    final servicesToFetch = <String>{
      for (final a in appointmentsOnDay)
        if ((a.serviceId ?? '').isNotEmpty &&
            !_serviceCache.containsKey(a.serviceId))
          a.serviceId!,
    };

    if (clientsToFetch.isNotEmpty || servicesToFetch.isNotEmpty) {
      await Future.wait([
        for (final id in clientsToFetch) _fetchClientCached(id),
        for (final id in servicesToFetch) _fetchServiceCached(id),
      ]);
    }

    return [
      for (final appt in appointmentsOnDay)
        if (appt.id != null && appt.dateTime != null)
          AppointmentCardModel(
            id: appt.id!,
            clientName: _clientCache[appt.clientId ?? '']?.name ?? '',
            serviceName: _serviceCache[appt.serviceId ?? '']?.name ?? '',
            phone: _clientCache[appt.clientId ?? '']?.phone,
            email: _clientCache[appt.clientId ?? '']?.email,
            time: appt.dateTime!,
            price: _firstNonEmpty([
              _trimOrNull(appt.price),
              _trimOrNull(_serviceCache[appt.serviceId ?? '']?.price),
            ]),
            duration: _serviceCache[appt.serviceId ?? '']?.duration,
            status: appt.status ?? 'ufaktureret',
            imageUrl: _clientCache[appt.clientId ?? '']?.image,
          ),
    ];
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal: indexing
  // ────────────────────────────────────────────────────────────────────────────

  void _buildDailyIndexes(List<AppointmentModel> appointments) {
    _appointmentsByDay.clear();

    for (final appointment in appointments) {
      final appointmentDateTime = appointment.dateTime;
      if (appointmentDateTime == null) {
        continue;
      }

      final date = dateOnly(appointmentDateTime);

      if (_appointmentsByDay[date] == null) {
        _appointmentsByDay[date] = <AppointmentModel>[];
      }

      _appointmentsByDay[date]!.add(appointment);
    }
  }

  Future<bool> _prefetchClientsAndServices(DateTime start, DateTime end) async {
    final clientIdsToFetch = <String>{};
    final serviceIdsToFetch = <String>{};

    final s = dateOnly(start);
    final e = dateOnly(end);

    for (final entry in _appointmentsByDay.entries) {
      final day = entry.key;
      if (day.isBefore(s) || day.isAfter(e)) {
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

    if (clientIdsToFetch.isEmpty && serviceIdsToFetch.isEmpty) return false;

    final beforeClients = _clientCache.length;
    final beforeServices = _serviceCache.length;

    await Future.wait([
      for (final id in clientIdsToFetch) _fetchClientCached(id),
      for (final id in serviceIdsToFetch) _fetchServiceCached(id),
    ]);

    final changed =
        _clientCache.length != beforeClients ||
        _serviceCache.length != beforeServices;
    return changed;
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
  Stream<Map<String, Set<int>>> checklistProgressStream(String appointmentId) =>
      _repo.watchChecklistProgress(appointmentId);

  Future<void> saveChecklistProgress({
    required String appointmentId,
    required Map<String, Set<int>> progress,
  }) => _repo.setAllChecklistProgress(appointmentId, progress);

  Future<void> setChecklistSelection({
    required String appointmentId,
    required Set<String> newSelection,
    Set<String> removedIds = const {},
    Set<String> resetProgressIds = const {},
  }) {
    return _repo.updateChecklistSelectionAndResets(
      apptId: appointmentId,
      newSelection: newSelection,
      removedIds: removedIds,
      resetProgressIds: resetProgressIds,
    );
  }

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
