import 'dart:async';
import 'dart:typed_data';
import 'package:aftaler_og_regnskab/utils/appointment_notifications.dart';
import 'package:aftaler_og_regnskab/domain/cache/appointment_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/appointment_repository.dart';
import 'package:aftaler_og_regnskab/domain/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/domain/appointment_model.dart';
import 'package:aftaler_og_regnskab/data/services/image_storage.dart';
import 'package:aftaler_og_regnskab/data/services/notification_service.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef MonthChip = ({String title, String status, DateTime time});

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo,
    this._imageStorage, {
    required this.clientCache,
    required this.serviceCache,
    required this.checklistCache,
    required this.apptCache,
    required this.notifications,
  });

  final AppointmentRepository _repo;
  final ClientCache clientCache;
  final ServiceCache serviceCache;
  final ChecklistCache checklistCache;
  final AppointmentCache apptCache;
  final ImageStorage _imageStorage;
  final AppointmentNotifications notifications;

  bool _isSaving = false;
  String? _lastErrorMessage;

  bool get saving => _isSaving;
  String? get error => _lastErrorMessage;

  StreamSubscription<List<AppointmentModel>>? _initialSubscription;
  final Set<DateTime> _loadedMonths = {};

  bool _hasLoadedInitialWindow = false;
  bool get hasLoadedInitialWindow => _hasLoadedInitialWindow;
  DateTime? _initialStart;
  DateTime? _initialEnd;

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

  @override
  void dispose() {
    _initialSubscription?.cancel();
    super.dispose();
  }

  AppointmentModel? getAppointment(String id) => apptCache.getAppointment(id);

  Future<void> _handleSnapshot(
    List<AppointmentModel> fetched, {
    bool markInitialLoaded = false,
  }) async {
    if (fetched.isEmpty) {
      if (markInitialLoaded && !_hasLoadedInitialWindow) {
        _hasLoadedInitialWindow = true;
        notifyListeners();
      }
      return;
    }

    apptCache.cacheAppointments(fetched);

    await _prefetchClientsAndServices(fetched);
    if (markInitialLoaded && !_hasLoadedInitialWindow) {
      _hasLoadedInitialWindow = true;
    }

    notifyListeners();
  }

  void setInitialRange() {
    if (_initialSubscription != null) return;

    final now = DateTime.now();
    final start = startOfMonth(now);
    final end = endOfMonthInclusive(DateTime(now.year, now.month + 1, 1));
    _initialStart = start;
    _initialEnd = end;

    _initialSubscription = _repo
        .watchAppointmentsBetween(start, end)
        .listen((fetched) => _handleSnapshot(fetched, markInitialLoaded: true));
  }

  Future<void> ensureMonthLoaded(DateTime visibleDate) async {
    if (_initialStart == null || _initialEnd == null) {
      setInitialRange();
    }

    final monthStart = startOfMonth(visibleDate);
    final monthEnd = endOfMonthInclusive(monthStart);

    final inInitial =
        !monthStart.isBefore(_initialStart!) && !monthEnd.isAfter(_initialEnd!);
    if (inInitial) return;

    if (_loadedMonths.contains(monthStart)) return;

    final fetched = await _repo.getAppointmentsBetween(monthStart, monthEnd);

    apptCache.cacheAppointments(fetched);
    await _prefetchClientsAndServices(fetched);

    _loadedMonths.add(monthStart);
    notifyListeners();
  }

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
      final created = model.copyWith(id: docRef.id);
      apptCache.cacheAppointment(created);

      unawaited(notifications.onAppointmentChanged(created));
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
    await _repo.updateStatus(id, newStatus.trim());
    final a = apptCache.getAppointment(id);
    if (a != null) {
      apptCache.cacheAppointment(a.copyWith(status: newStatus.trim()));
    }
    notifyListeners();
  }

  Future<List<String>> handleImages(
    List<({Uint8List bytes, String name, String? mimeType})> newImages,
    List<String> removedImageUrls,
    List<String> currentImageUrls,
    String id,
  ) async {
    final uploadedUrls = newImages.isEmpty
        ? const <String>[]
        : await _imageStorage.uploadAppointmentImages(
            appointmentId: id,
            images: newImages,
          );

    final removedSet = removedImageUrls.toSet();
    final kept = currentImageUrls.where((u) => !removedSet.contains(u));

    return <String>{...kept, ...uploadedUrls}.toList();
  }

  Set<String>? handeNewChecklists(List<String>? checklistIds) {
    Set<String>? newChecklistSelection;
    if (checklistIds != null) {
      newChecklistSelection = {
        for (final id in checklistIds)
          if (id.trim().isNotEmpty) id.trim(),
      };
    }
    return newChecklistSelection;
  }

  Set<String> handleRemovedChecklists(
    Set<String>? newChecklists,
    List<String> oldChecklists,
  ) {
    return (newChecklists != null)
        ? oldChecklists.toSet().difference(newChecklists)
        : <String>{};
  }

  void handleFields(
    Map<String, Object?> fields,
    List<String> finalImageUrls,
    Set<String> deletes,
    String? clientId,
    String? serviceId,
    String? location,
    String? note,
    String? status,
    DateTime? dateTime,
    DateTime? payDate,
    double? price,
    Set<String>? newChecklistSelection,
    Set<String> removedChecklists,
  ) {
    fields['imageUrls'] = finalImageUrls;
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

    putStr('clientId', clientId);
    putStr('serviceId', serviceId);
    putStr('location', location);
    putStr('note', note);
    putStr('status', status);
    putTs('dateTime', dateTime);
    putTs('payDate', payDate);

    if (price != null) {
      fields['price'] = price;
    }

    if (newChecklistSelection != null) {
      fields['checklistIds'] = newChecklistSelection.toList();
    }
    for (final id in removedChecklists) {
      deletes.add('progress.$id');
    }
  }

  Future<void> handleDeleteImage(List<String> removedImageUrls) async {
    try {
      await _imageStorage.deleteAppointmentImagesByUrls(removedImageUrls);
    } catch (_) {}
  }

  Future<void> handleUpdate(
    AppointmentModel old,
    Map<String, Object?> fields,
    Set<String> deletes,
    String? clientId,
    String? serviceId,
    Set<String>? newChecklistSelection,
    DateTime? dateTime,
    DateTime? payDate,
    List<String> finalImageUrls,
  ) async {
    await _repo.updateAppointment(old.id!, fields: fields, deletes: deletes);

    final updated = old.copyWith(
      clientId: clientId ?? old.clientId,
      serviceId: serviceId ?? old.serviceId,
      checklistIds: newChecklistSelection?.toList() ?? old.checklistIds,
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
    unawaited(notifications.onAppointmentChanged(updated));
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
      final finalImageUrls = await handleImages(
        newImages,
        removedImageUrls,
        currentImageUrls,
        old.id!,
      );
      final newChecklistSelection = handeNewChecklists(checklistIds);
      final removedChecklists = handleRemovedChecklists(
        newChecklistSelection,
        old.checklistIds,
      );
      final fields = <String, Object?>{};
      final deletes = <String>{};

      handleFields(
        fields,
        finalImageUrls,
        deletes,
        clientId,
        serviceId,
        location,
        note,
        status,
        dateTime,
        payDate,
        price,
        newChecklistSelection,
        removedChecklists,
      );

      if (fields.isNotEmpty || deletes.isNotEmpty) {
        await handleUpdate(
          old,
          fields,
          deletes,
          clientId,
          serviceId,
          newChecklistSelection,
          dateTime,
          payDate,
          finalImageUrls,
        );
      }

      if (removedImageUrls.isNotEmpty) {
        await handleDeleteImage(removedImageUrls);
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

  Future<void> delete(
    String id,
    String status,
    double? price,
    DateTime date,
  ) async {
    try {
      await _imageStorage.deleteAppointmentImages(id);
    } catch (_) {}
    await notifications.cancelFor(id);
    await _repo.deleteAppointment(id);

    apptCache.remove(id);

    notifyListeners();
  }

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

  Future<void> rescheduleTodayAndFuture(NotificationService ns) async {
    await ns.cancelAll();

    final todayAppts = _dayAppts(DateTime.now());
    await notifications.syncToday(appointments: todayAppts);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(2100, 1, 1);

    DocumentSnapshot<Map<String, dynamic>>? cursor;
    const pageSize = 50;

    while (true) {
      final page = await _repo.getAppointmentsPaged(
        startInclusive: start,
        endInclusive: end,
        pageSize: pageSize,
        startAfterDoc: cursor,
        descending: false,
      );
      final items = page.items;
      if (items.isEmpty) break;

      for (final appt in items) {
        if (appt.id == null || appt.dateTime == null) continue;

        await notifications.onAppointmentChanged(appt);
      }

      cursor = page.lastDoc;
      if (items.length < pageSize) break;
    }
  }

  Stream<Map<String, Set<int>>> checklistProgressStream(String appointmentId) =>
      _repo.watchChecklistProgress(appointmentId);

  Future<void> saveChecklistProgress({
    required String appointmentId,
    required Map<String, Set<int>> progress,
  }) => _repo.setAllChecklistProgress(appointmentId, progress);

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
    _initialStart = null;
    _initialEnd = null;
    _listStart = null;
    _listEnd = null;
    _listLoading = false;
    _listHasMore = false;
    _listLastDoc = null;
    _isSaving = false;
    _lastErrorMessage = null;
    _hasLoadedInitialWindow = false;
    _loadedMonths.clear();
    apptCache.clear();
    notifyListeners();
  }
}
