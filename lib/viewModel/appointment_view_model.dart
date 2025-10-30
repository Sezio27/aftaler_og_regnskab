import 'dart:async';
import 'dart:typed_data';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/client_service_cache.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef FetchClients =
    Future<Map<String, ClientModel?>> Function(Set<String> ids);
typedef FetchServices =
    Future<Map<String, ServiceModel?>> Function(Set<String> ids);
typedef MonthChip = ({String title, String status, DateTime time});

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo,
    this._imageStorage, {
    required this.cache,
    required this.financeVM,
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Dependencies
  // ────────────────────────────────────────────────────────────────────────────
  final AppointmentRepository _repo;
  final ClientServiceCache cache;
  final ImageStorage _imageStorage;
  final FinanceViewModel financeVM;

  // ────────────────────────────────────────────────────────────────────────────
  // Appointments data
  // ────────────────────────────────────────────────────────────────────────────
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

  // ────────────────────────────────────────────────────────────────────────────
  // List mode (paged months)
  // ────────────────────────────────────────────────────────────────────────────
  DateTime? _listStart, _listEnd;
  bool _listLoading = false;
  bool _listHasMore = false;
  final int _listPageSize = 20;
  DocumentSnapshot<Map<String, dynamic>>? _listLastDoc;
  final List<AppointmentModel> _pagedList = [];
  List<AppointmentModel> _listAll = const [];

  bool get listLoading => _listLoading;
  bool get listHasMore => _listHasMore;

  @override
  void dispose() {
    _initialSubscription?.cancel();
    super.dispose();
  }

  bool _isMonthCoveredByInitial(DateTime monthStart) {
    final monthEnd = endOfMonthInclusive(monthStart);
    return !monthStart.isBefore(_initialStart!) &&
        !monthEnd.isAfter(_initialEnd!);
  }

  Future<void> setInitialRange({String label = 'VM:setInitialRange'}) async {
    if (_initialSubscription != null) return;

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
      _updateAppointments(notify: false);
      notifyListeners();
      if (firstSnapshot) {
        debugPrint(
          '$label first_snapshot=${DateTime.now().difference(startedAt).inMilliseconds}ms',
        );
        firstSnapshot = false;
      }

      final changed = await _prefetchClientsAndServices(
        _initialStart!,
        _initialEnd!,
      );
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
              _updateAppointments(notify: false);
              if (firstSnapshot) {
                debugPrint(
                  '$label [$monthStart] first_snapshot=${DateTime.now().difference(startedAt).inMilliseconds}ms',
                );
                firstSnapshot = false;
              }

              final changed = await _prefetchClientsAndServices(
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

  void _updateAppointments({bool notify = true}) {
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

    if (notify) notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CRUD methods
  // ────────────────────────────────────────────────────────────────────────────
  Future<bool> addAppointment({
    required String? clientId,
    required String? serviceId,
    required DateTime? dateTime,
    required List<String> checklistIds,
    DateTime? payDate,
    String? location,
    String? note,
    double? price,
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

      final model = AppointmentModel(
        clientId: clientId,
        serviceId: serviceId,
        checklistIds: checklistIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        dateTime: dateTime,
        payDate: payDate,
        price: price,
        location: location,
        note: note,
        imageUrls: imageUrls,
        status: status,
      );

      await _repo.createAppointmentWithId(docRef.id, model);

      financeVM.onAddAppointment(
        status: PaymentStatusX.fromString(status),
        price: price ?? 0.0,
        dateTime: dateTime,
      );

      return true;
    } catch (e) {
      _lastErrorMessage = 'Kunne ikke oprette aftale: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus(
    String id,
    String oldStatus,
    double? price,
    String newStatus,
    DateTime date,
  ) async {
    await _repo.updateStatus(id, newStatus.trim());

    financeVM.onUpdateStatus(
      oldStatus: PaymentStatusX.fromString(oldStatus),
      newStatus: PaymentStatusX.fromString(newStatus),
      price: price ?? 0.0,
      date: date,
    );
  }

  Future<bool> updateAppointmentFields(
    AppointmentModel old, {
    String? clientId,
    String? serviceId,
    List<String>? checklistIds,
    DateTime? dateTime,
    DateTime? payDate,
    String? location,
    String? note,
    double? price,
    double? servicePrice,
    String? status,
    required List<String> currentImageUrls,
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
          appointmentId: old.id!,
          images: newImages,
        );
      }

      // 3) Compute final list locally (remove + add + dedupe)
      final removedSet = removedImageUrls.toSet();
      final kept = currentImageUrls.where((u) => !removedSet.contains(u));
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
      if (price != null || servicePrice != null) {
        final chosen = price ?? servicePrice;
        if (chosen == null) {
          deletes.add('price');
        } else {
          fields['price'] = chosen;
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
        await _repo.updateAppointment(
          old.id!,
          fields: fields,
          deletes: deletes,
        );
      }

      if (removedImageUrls.isNotEmpty) {
        try {
          await _imageStorage.deleteAppointmentImagesByUrls(removedImageUrls);
        } catch (_) {}
      }

      final oldStatus = PaymentStatusX.fromString(old.status);
      final newStatus = status != null
          ? PaymentStatusX.fromString(status)
          : oldStatus;
      final oldPrice = old.price ?? 0.0;
      final newPrice = price ?? 0.0;
      final oldDate = old.dateTime;
      final newDate = dateTime ?? oldDate;

      financeVM.onUpdateAppointmentFields(
        oldStatus: oldStatus,
        newStatus: newStatus,
        oldPrice: oldPrice,
        newPrice: newPrice,
        oldDate: oldDate,
        newDate: newDate,
      );

      return true;
    } catch (e) {
      _lastErrorMessage = 'Kunne ikke opdatere: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> delete(
    String id,
    String status,
    double? price,
    DateTime date,
  ) async {
    try {
      await _imageStorage.deleteAppointmentImages(id);
    } catch (_) {}
    await _repo.deleteAppointment(id);

    financeVM.onDeleteAppointment(
      status: PaymentStatusX.fromString(status),
      price: price ?? 0.0,
      date: date,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Query methods
  // ────────────────────────────────────────────────────────────────────────────
  Stream<AppointmentModel?> watchAppointmentById(String id) =>
      _repo.watchAppointment(id);

  List<AppointmentModel> getAppointmentsInRange(DateTime start, DateTime end) {
    return _rangeAppointments.where((a) {
      final dt = a.dateTime;
      return dt != null &&
          !dt.isBefore(dateOnly(start)) &&
          !dt.isAfter(endOfDayInclusive(dateOnly(end)));
    }).toList();
  }

  List<AppointmentCardModel> cardsForRange(DateTime start, DateTime end) {
    final appts = getAppointmentsInRange(start, end);

    final out = <AppointmentCardModel>[];
    for (final appt in appts) {
      if (appt.id == null || appt.dateTime == null) continue;
      out.add(_toCard(appt));
    }
    return out;
  }

  List<MonthChip> monthChipsOn(DateTime day) {
    final date = dateOnly(day);
    final items = _appointmentsByDay[date] ?? const <AppointmentModel>[];

    final chips = <MonthChip>[];
    for (final appt in items) {
      final clientName = cache.getClient(appt.clientId ?? '')?.name ?? '';
      final time = appt.dateTime!;
      final status = appt.status ?? 'ufaktureret';
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
            cache.getClient(a.clientId!) == null)
          a.clientId!,
    };
    final servicesToFetch = <String>{
      for (final a in appointmentsOnDay)
        if ((a.serviceId ?? '').isNotEmpty &&
            cache.getService(a.serviceId!) == null)
          a.serviceId!,
    };

    if (clientsToFetch.isNotEmpty || servicesToFetch.isNotEmpty) {
      await Future.wait([
        if (clientsToFetch.isNotEmpty) _fetchClientsBatched(clientsToFetch),
        if (servicesToFetch.isNotEmpty) _fetchServicesBatched(servicesToFetch),
      ]);
    }

    final out = <AppointmentCardModel>[];
    for (final appt in appointmentsOnDay) {
      if (appt.id == null || appt.dateTime == null) continue;
      out.add(_toCard(appt));
    }
    return out;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal: indexing and prefetch
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
        if (c.isNotEmpty && cache.getClient(c) == null) {
          clientIdsToFetch.add(c);
        }
        final s = (appt.serviceId ?? '').trim();
        if (s.isNotEmpty && cache.getService(s) == null) {
          serviceIdsToFetch.add(s);
        }
      }
    }

    if (clientIdsToFetch.isEmpty && serviceIdsToFetch.isEmpty) return false;

    await Future.wait([
      if (clientIdsToFetch.isNotEmpty) cache.fetchClients(clientIdsToFetch),
      if (serviceIdsToFetch.isNotEmpty) cache.fetchServices(serviceIdsToFetch),
    ]);

    return true;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal: caching helpers
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _fetchClientsBatched(Set<String> ids) async {
    await cache.fetchClients(ids);
  }

  Future<void> _fetchServicesBatched(Set<String> ids) async {
    await cache.fetchServices(ids);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Checklist methods
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

  // ────────────────────────────────────────────────────────────────────────────
  // List mode methods
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> beginListRange(DateTime start, DateTime end) async {
    _listStart = dateOnly(start);
    _listEnd = endOfDayInclusive(dateOnly(end));
    _pagedList.clear();
    _listLastDoc = null;
    _listHasMore = true;

    // Rebuild the list union without any paged data yet.
    _rebuildListUnion();
    notifyListeners();

    // Load initial pages (three at a time) until some items appear or no more.
    do {
      await loadNextListPage(count: 3);
    } while (_listAll.isEmpty && _listHasMore);
  }

  Future<void> loadNextListPage({int count = 1}) async {
    if (!_listHasMore || _listLoading) return;
    if (_listStart == null || _listEnd == null) return;
    _listLoading = true;
    notifyListeners();

    var loadedAny = false;
    try {
      var remaining = count;
      while (remaining > 0 && _listHasMore) {
        // Fetch one page from the repository
        final result = await _repo.getAppointmentsPaged(
          startInclusive: _listStart,
          endInclusive: _listEnd,
          pageSize: _listPageSize,
          startAfterDoc: _listLastDoc,
          descending: false,
        );

        final items = result.items;
        final lastDoc = result.lastDoc;

        // If no items returned, we've reached the end
        if (items.isEmpty) {
          _listHasMore = false;
          break;
        }

        _listLastDoc = lastDoc;
        _pagedList.addAll(items);

        // Prefetch any missing client/service data
        final clientIds = <String>{};
        final serviceIds = <String>{};
        for (final appt in items) {
          final c = (appt.clientId ?? '').trim();
          if (c.isNotEmpty && cache.getClient(c) == null) clientIds.add(c);
          final s = (appt.serviceId ?? '').trim();
          if (s.isNotEmpty && cache.getService(s) == null) serviceIds.add(s);
        }
        await Future.wait([
          if (clientIds.isNotEmpty) cache.fetchClients(clientIds),
          if (serviceIds.isNotEmpty) cache.fetchServices(serviceIds),
        ]);

        loadedAny = true;
        // If fewer items than pageSize, no more pages remain
        if (items.length < _listPageSize) {
          _listHasMore = false;
          break;
        }
        remaining--;
      }
    } finally {
      _listLoading = false;
      // Rebuild UI data when new items were loaded
      if (loadedAny) _rebuildListUnion();
      // Auto-fetch more pages if we still have very few items
      if (_listAll.length < 5 && _listHasMore && !_listLoading) {
        loadNextListPage(count: 3);
      }
      notifyListeners();
    }
  }

  void _rebuildListUnion() {
    if (_listStart == null || _listEnd == null) {
      return;
    }
    // Live data from initial and active windows
    final live = <AppointmentModel>[
      ..._initialAppointments,
      for (final v in _windowAppointments.values) ...v,
    ];
    // Data loaded via paged queries
    final paged = List<AppointmentModel>.from(_pagedList);

    // Merge, letting live data override paged data on ID conflicts
    final byId = <String, AppointmentModel>{};
    for (final a in paged) {
      final id = a.id;
      if (id != null) byId[id] = a;
    }
    for (final a in live) {
      final id = a.id;
      if (id != null) byId[id] = a;
    }

    // Filter to current list range and sort ascending by dateTime
    final listRangeAll = byId.values.where((a) {
      final dt = a.dateTime;
      if (dt == null) return false;
      if (_listStart != null && dt.isBefore(_listStart!)) return false;
      if (_listEnd != null && dt.isAfter(_listEnd!)) return false;
      return true;
    }).toList();
    listRangeAll.sort(
      (a, b) =>
          (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)),
    );
    _listAll = listRangeAll;
  }

  AppointmentCardModel _toCard(AppointmentModel appt) {
    final client = cache.getClient(appt.clientId ?? '');
    final service = cache.getService(appt.serviceId ?? '');
    final chosenPrice = appt.price;

    final hasCvr = ((client?.cvr ?? '').trim().isNotEmpty);

    return AppointmentCardModel(
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
      isBusiness: hasCvr,
    );
  }

  List<AppointmentCardModel> get listCards => _listAll
      .where((a) => a.id != null && a.dateTime != null)
      .map(_toCard)
      .toList();
}
