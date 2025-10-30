import 'dart:async';
import 'dart:typed_data';
import 'package:aftaler_og_regnskab/data/appointment_cache.dart';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/client_cache.dart';
import 'package:aftaler_og_regnskab/data/service_cache.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef MonthChip = ({String title, String status, DateTime time});

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo,
    this._imageStorage, {
    required this.clientCache,
    required this.serviceCache,
    required this.apptCache,
    required this.financeVM,
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Dependencies
  // ────────────────────────────────────────────────────────────────────────────
  final AppointmentRepository _repo;
  final ClientCache clientCache;
  final ServiceCache serviceCache;
  final AppointmentCache apptCache;
  final ImageStorage _imageStorage;
  final FinanceViewModel financeVM;

  // ────────────────────────────────────────────────────────────────────────────
  // Simple UI state flags
  // ────────────────────────────────────────────────────────────────────────────
  bool isReady = false;
  bool _isSaving = false;
  String? _lastErrorMessage;

  bool get saving => _isSaving;
  String? get error => _lastErrorMessage;

  // ────────────────────────────────────────────────────────────────────────────
  // Range subscription control
  // ────────────────────────────────────────────────────────────────────────────
  StreamSubscription<List<AppointmentModel>>? _initialSubscription;
  final Map<DateTime, StreamSubscription<List<AppointmentModel>>>
  _windowSubscriptions = {};

  DateTime? _initialStart;
  DateTime? _initialEnd;
  DateTime? _activeMonthStart;

  // ────────────────────────────────────────────────────────────────────────────
  // List mode (paged months)
  // ────────────────────────────────────────────────────────────────────────────
  DateTime? _listStart, _listEnd;
  bool _listLoading = false;
  bool _listHasMore = false;
  bool get listLoading => _listLoading;
  bool get listHasMore => _listHasMore;
  final int _listPageSize = 20;
  DocumentSnapshot<Map<String, dynamic>>? _listLastDoc;
  List<AppointmentModel> get _listModels =>
      (_listStart != null && _listEnd != null)
      ? apptCache.getAppointmentsBetween(_listStart!, _listEnd!)
      : const [];

  Future<void> _handleSnapshot(
    List<AppointmentModel> fetched,
    DateTime start,
    DateTime end,
  ) async {
    apptCache.cacheAppointments(fetched);

    final becameReady = !isReady;
    if (becameReady) isReady = true;

    final changed = await _prefetchClientsAndServices(
      apptCache.getAppointmentsBetween(start, end),
    );

    if (becameReady || changed) notifyListeners();
  }

  StreamSubscription<List<AppointmentModel>> _subscribeMonth(
    DateTime monthStart,
  ) {
    final monthEnd = endOfMonthInclusive(monthStart);

    return _repo.watchAppointmentsBetween(monthStart, monthEnd).listen((
      fetched,
    ) async {
      await _handleSnapshot(fetched, monthStart, monthEnd);
    });
  }

  @override
  void dispose() {
    _initialSubscription?.cancel();
    for (final sub in _windowSubscriptions.values) {
      sub.cancel();
    }
    _windowSubscriptions.clear();
    super.dispose();
  }

  bool _isMonthCoveredByInitial(DateTime monthStart) {
    final monthEnd = endOfMonthInclusive(monthStart);
    return !monthStart.isBefore(_initialStart!) &&
        !monthEnd.isAfter(_initialEnd!);
  }

  Future<void> setInitialRange() async {
    if (_initialSubscription != null) return;

    final now = DateTime.now();
    final start = startOfMonth(now);
    final end = endOfMonthInclusive(DateTime(now.year, now.month + 1, 1));
    _initialStart = start;
    _initialEnd = end;

    _initialSubscription = _subscribeMonth(start);
  }

  void setActiveWindow(DateTime visibleDate) {
    if (_initialStart == null || _initialEnd == null) return;

    if (_isMonthCoveredByInitial(visibleDate)) return;
    final newMonthStart = startOfMonth(visibleDate);

    if (_activeMonthStart == newMonthStart) return;

    _activeMonthStart = newMonthStart;

    final windowMonthStarts = [
      addMonths(newMonthStart, -1),
      newMonthStart,
      addMonths(newMonthStart, 1),
    ];

    for (final m in windowMonthStarts) {
      if (!_isMonthCoveredByInitial(m)) {
        _windowSubscriptions.putIfAbsent(m, () => _subscribeMonth(m));
      }
    }

    final keep = windowMonthStarts.toSet();
    for (final m
        in _windowSubscriptions.keys.where((k) => !keep.contains(k)).toList()) {
      _windowSubscriptions[m]?.cancel();
      _windowSubscriptions.remove(m);
    }
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
      apptCache.cacheAppointment(model.copyWith(id: docRef.id));

      await financeVM.onAddAppointment(
        status: PaymentStatusX.fromString(status),
        price: price ?? 0.0,
        dateTime: dateTime,
      );
      notifyListeners();
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
    final a = apptCache.getAppointment(id);
    if (a != null) {
      apptCache.cacheAppointment(a.copyWith(status: newStatus.trim()));
    }
    await financeVM.onUpdateStatus(
      oldStatus: PaymentStatusX.fromString(oldStatus),
      newStatus: PaymentStatusX.fromString(newStatus),
      price: price ?? 0.0,
      date: date,
    );

    notifyListeners();
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

        final updated = old.copyWith(
          clientId: clientId ?? old.clientId,
          serviceId: serviceId ?? old.serviceId,
          checklistIds: checklistIds ?? old.checklistIds,
          dateTime: dateTime ?? old.dateTime,
          payDate: payDate ?? old.payDate,
          location: fields.containsKey('location')
              ? fields['location'] as String?
              : (deletes.contains('location') ? null : old.location),
          note: fields.containsKey('note')
              ? fields['note'] as String?
              : (deletes.contains('note') ? null : old.note),
          status: fields.containsKey('status')
              ? fields['status'] as String?
              : (deletes.contains('status') ? null : old.status),
          price: fields.containsKey('price')
              ? (fields['price'] as num?)?.toDouble()
              : (deletes.contains('price') ? null : old.price),
          imageUrls: finalImageUrls,
        );
        apptCache.cacheAppointment(updated);
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

      await financeVM.onUpdateAppointmentFields(
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
    apptCache.remove(id);
    financeVM.onDeleteAppointment(
      status: PaymentStatusX.fromString(status),
      price: price ?? 0.0,
      date: date,
    );
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Query methods
  // ────────────────────────────────────────────────────────────────────────────
  Stream<AppointmentModel?> watchAppointmentById(String id) =>
      _repo.watchAppointment(id);

  List<AppointmentModel> getAppointmentsInRange(DateTime start, DateTime end) {
    return apptCache.getAppointmentsBetween(
      dateOnly(start),
      endOfDayInclusive(dateOnly(end)),
    );
  }

  List<AppointmentCardModel> cardsForRange(DateTime start, DateTime end) {
    final appts = getAppointmentsInRange(start, end);
    return [
      for (final appt in appts)
        if (appt.id != null && appt.dateTime != null) _toCard(appt),
    ];
  }

  List<AppointmentModel> _dayAppts(DateTime d) {
    final s = dateOnly(d);
    final e = endOfDayInclusive(s);
    return apptCache.getAppointmentsBetween(s, e);
  }

  List<MonthChip> monthChipsOn(DateTime day) {
    final appointmentsOnDay = _dayAppts(day);

    final chips = <MonthChip>[];
    for (final appt in appointmentsOnDay) {
      final clientName = clientCache.getClient(appt.clientId ?? '')?.name ?? '';
      final time = appt.dateTime!;
      final status = appt.status ?? 'ufaktureret';
      chips.add((title: clientName, status: status, time: time));
    }
    return chips;
  }

  bool hasEventsOn(DateTime day) => _dayAppts(day).isNotEmpty;

  Future<List<AppointmentCardModel>> cardsForDate(DateTime day) async {
    final appointmentsOnDay = _dayAppts(day);

    final clientsToFetch = <String>{
      for (final a in appointmentsOnDay)
        if ((a.clientId ?? '').isNotEmpty &&
            clientCache.getClient(a.clientId!) == null)
          a.clientId!,
    };
    final servicesToFetch = <String>{
      for (final a in appointmentsOnDay)
        if ((a.serviceId ?? '').isNotEmpty &&
            serviceCache.getService(a.serviceId!) == null)
          a.serviceId!,
    };

    if (clientsToFetch.isNotEmpty || servicesToFetch.isNotEmpty) {
      await Future.wait([
        if (clientsToFetch.isNotEmpty) clientCache.fetchClients(clientsToFetch),
        if (servicesToFetch.isNotEmpty)
          serviceCache.fetchServices(servicesToFetch),
      ]);
    }

    return [
      for (final appt in appointmentsOnDay)
        if (appt.id != null && appt.dateTime != null) _toCard(appt),
    ];
  }

  Future<bool> _prefetchClientsAndServices(
    Iterable<AppointmentModel> appts,
  ) async {
    final clientIdsToFetch = <String>{};
    final serviceIdsToFetch = <String>{};

    for (final appt in appts) {
      final c = (appt.clientId ?? '').trim();
      if (c.isNotEmpty && clientCache.getClient(c) == null)
        clientIdsToFetch.add(c);
      final s = (appt.serviceId ?? '').trim();
      if (s.isNotEmpty && serviceCache.getService(s) == null)
        serviceIdsToFetch.add(s);
    }

    if (clientIdsToFetch.isEmpty && serviceIdsToFetch.isEmpty) return false;

    await Future.wait([
      if (clientIdsToFetch.isNotEmpty)
        clientCache.fetchClients(clientIdsToFetch),
      if (serviceIdsToFetch.isNotEmpty)
        serviceCache.fetchServices(serviceIdsToFetch),
    ]);

    return true;
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

    _listLastDoc = null;
    _listHasMore = true;

    notifyListeners();

    do {
      await loadNextListPage(count: 3);
    } while (_listModels.isEmpty && _listHasMore);
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
        final result = await _repo.getAppointmentsPaged(
          startInclusive: _listStart,
          endInclusive: _listEnd,
          pageSize: _listPageSize,
          startAfterDoc: _listLastDoc,
          descending: false,
        );

        final items = result.items;
        final lastDoc = result.lastDoc;

        if (items.isEmpty) {
          _listHasMore = false;
          break;
        }

        _listLastDoc = lastDoc;
        apptCache.cacheAppointments(items);

        _prefetchClientsAndServices(items);

        loadedAny = true;
        if (items.length < _listPageSize) {
          _listHasMore = false;
          break;
        }
        remaining--;
      }
    } finally {
      _listLoading = false;

      if (_listModels.length < 5 && _listHasMore && !_listLoading) {
        loadNextListPage(count: 3);
      }
      notifyListeners();
    }
  }

  AppointmentCardModel _toCard(AppointmentModel appt) {
    final client = clientCache.getClient(appt.clientId ?? '');
    final service = serviceCache.getService(appt.serviceId ?? '');

    final hasCvr = ((client?.cvr ?? '').trim().isNotEmpty);

    return AppointmentCardModel(
      id: appt.id!,
      clientName: client?.name ?? '',
      serviceName: service?.name ?? '',
      phone: client?.phone,
      email: client?.email,
      time: appt.dateTime!,
      price: appt.price,
      duration: service?.duration,
      status: appt.status ?? 'ufaktureret',
      imageUrl: client?.image,
      isBusiness: hasCvr,
    );
  }

  List<AppointmentCardModel> get listCards => _listModels
      .where((a) => a.id != null && a.dateTime != null)
      .map(_toCard)
      .toList();

  void resetOnAuthChange() {
    _initialSubscription?.cancel();
    _initialSubscription = null;

    for (final sub in _windowSubscriptions.values) {
      sub.cancel();
    }
    _windowSubscriptions.clear();
    _initialStart = null;
    _initialEnd = null;
    _activeMonthStart = null;

    _listStart = null;
    _listEnd = null;
    _listLoading = false;
    _listHasMore = false;
    _listLastDoc = null;
    isReady = false;
    _isSaving = false;
    _lastErrorMessage = null;
    apptCache.clear();
    notifyListeners();
  }
}
