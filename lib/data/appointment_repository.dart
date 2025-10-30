import 'package:aftaler_og_regnskab/debug/bench.dart';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppointmentRepository {
  AppointmentRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  // ────────────────────────────────────────────────────────────────────────────
  // Internals
  // ────────────────────────────────────────────────────────────────────────────
  String get _uidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('appointments');

  DocumentReference<Map<String, dynamic>> newAppointmentRef() {
    final uid = _uidOrThrow;
    return _collection(uid).doc();
  }

  Stream<AppointmentModel?> watchAppointment(String id) {
    final uid = _uidOrThrow;
    return _collection(uid).doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _fromDoc(snap);
    });
  }

  Future<void> createAppointmentWithId(
    String id,
    AppointmentModel model,
  ) async {
    final uid = _uidOrThrow;
    final payload = _toFirestore(model.copyWith(id: id), isCreate: true);
    await _collection(uid).doc(id).set(payload);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Reads (range & detail)
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream appointments with `dateTime` in [start, end], inclusive.
  /// Sorted by `dateTime` ascending (what calendar/agenda UIs need).
  Stream<List<AppointmentModel>> watchAppointmentsBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) {
    final uid = _uidOrThrow;
    var countedFirstServer = false;

    return _collection(uid)
        .where(
          'dateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
        )
        .where(
          'dateTime',
          isLessThanOrEqualTo: Timestamp.fromDate(endInclusive),
        )
        .orderBy('dateTime')
        .snapshots()
        .map((q) {
          assert(() {
            if (!q.metadata.isFromCache) {
              if (!countedFirstServer) {
                bench?.liveFirstReads += q.docs.length; // count full set once
                countedFirstServer = true;
              } else {
                bench?.liveUpdateReads +=
                    q.docChanges.length; // only changes after
              }
            }
            return true;
          }());

          return q.docs.map(_fromDoc).toList();
        });
  }

  /// One-time fetch of an appointment by id.
  Future<AppointmentModel?> getAppointmentOnce(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  Future<Map<String, AppointmentModel?>> getAppointments(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final uid = _uidOrThrow;
    final idsList = ids.toList();
    final result = <String, AppointmentModel?>{};
    for (var i = 0; i < idsList.length; i += 10) {
      final chunk = idsList.sublist(
        i,
        i + 10 > idsList.length ? idsList.length : i + 10,
      );
      final querySnapshot = await _collection(
        uid,
      ).where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in querySnapshot.docs) {
        result[doc.id] = _fromDoc(doc);
      }
      for (final id in chunk) {
        result.putIfAbsent(id, () => null);
      }
    }
    return result;
  }

  // in AppointmentRepository
  // appointment_repository.dart
  Future<List<AppointmentModel>> getAppointmentsBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final uid = _uidOrThrow;
    final endOfDay = DateTime(
      endInclusive.year,
      endInclusive.month,
      endInclusive.day,
      23,
      59,
      59,
      999,
    );

    final q = await _collection(uid)
        .where(
          'dateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
        )
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('dateTime')
        .get();

    assert(() {
      if (!(q.metadata.isFromCache)) {
        bench?.pagedReads += q.docs.length;
      }
      return true;
    }());

    return q.docs.map(_fromDoc).toList();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Writes
  // ────────────────────────────────────────────────────────────────────────────

  /// Create a new appointment (id auto-generated).
  Future<AppointmentModel> addAppointment(AppointmentModel model) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc();
    final payload = _toFirestore(model.copyWith(id: doc.id), isCreate: true);
    await doc.set(payload);
    return model.copyWith(id: doc.id);
  }

  /// Patch fields on an appointment.
  /// Prefer passing a `fields` map (what your ViewModel does).
  Future<void> updateAppointment(
    String id, {
    AppointmentModel? patch, // optional: convert model into fields
    Map<String, Object?>? fields,
    Set<String> deletes = const {},
  }) async {
    final uid = _uidOrThrow;

    final data = fields ?? _toFirestore(patch!, isCreate: false);
    final payload = <String, Object?>{...data};
    for (final key in deletes) {
      payload[key] = FieldValue.delete();
    }
    payload.removeWhere((k, v) => v == null);

    if (deletes.any((key) => key.startsWith('progress.'))) {
      // use update() so nested deletes work
      await _collection(uid).doc(id).update(payload);
    } else {
      await _collection(uid).doc(id).set(payload, SetOptions(merge: true));
    }
  }

  // AppointmentRepository
  Future<void> updateStatus(String id, String newStatus) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).update({'status': newStatus.trim()});
  }

  Stream<Map<String, Set<int>>> watchChecklistProgress(String apptId) {
    final uid = _uidOrThrow;
    return _collection(uid).doc(apptId).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      final raw = (data['progress'] as Map<String, dynamic>? ?? const {});
      final out = <String, Set<int>>{};
      for (final e in raw.entries) {
        final list = (e.value as List? ?? const []);
        out[e.key] = list.map((x) => (x as num).toInt()).toSet();
      }
      return out;
    });
  }

  /// One **single** write to set the whole progress map on the parent appointment.
  Future<void> setAllChecklistProgress(
    String apptId,
    Map<String, Set<int>> progress,
  ) async {
    final uid = _uidOrThrow;
    final payload = <String, dynamic>{
      'progress': {
        for (final e in progress.entries) e.key: (e.value.toList()..sort()),
      },
    };
    await _collection(uid).doc(apptId).set(payload, SetOptions(merge: true));
  }

  Future<int> countAppointments({
    DateTime? startInclusive,
    DateTime? endInclusive,
    String? status,
  }) async {
    final uid = _uidOrThrow;
    Query<Map<String, dynamic>> q = _collection(uid);

    if (startInclusive != null) {
      q = q.where(
        'dateTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
      );
    }
    if (endInclusive != null) {
      final eod = DateTime(
        endInclusive.year,
        endInclusive.month,
        endInclusive.day,
        23,
        59,
        59,
        999,
      );
      q = q.where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(eod));
    }
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }

    debugPrint(
      '[countAppointments] uid=$uid start=$startInclusive end=$endInclusive status=$status',
    );

    try {
      final agg = await q.count().get();
      final c = agg.count ?? 0;
      debugPrint('[countAppointments] result=$c');
      return c;
    } catch (e, st) {
      // This will print the "requires index" link whether it's FirebaseException or PlatformException
      debugPrint('[countAppointments] ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<double> sumPaidInRange({
    DateTime? startInclusive,
    DateTime? endInclusive,
  }) async {
    final uid = _uidOrThrow;
    Query<Map<String, dynamic>> query = _collection(
      uid,
    ).where('status', isEqualTo: 'Betalt');

    if (startInclusive != null) {
      query = query.where(
        'dateTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
      );
    }
    if (endInclusive != null) {
      final endOfDay = DateTime(
        endInclusive.year,
        endInclusive.month,
        endInclusive.day,
        23,
        59,
        59,
        999,
      );
      query = query.where(
        'dateTime',
        isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
      );
    }

    final aggregateQuery = query.aggregate(sum('price'));

    // 🔎 Log BEFORE awaiting, so we know the function was called
    debugPrint(
      '[sumPaidInRange] uid=$uid start=$startInclusive end=$endInclusive',
    );

    try {
      final agg = await aggregateQuery.get();
      final val = agg.getSum('price');
      debugPrint('[sumPaidInRange] result=$val');
      return (val ?? 0.0).toDouble();
    } catch (e, st) {
      debugPrint('[sumPaidInRange] ERROR: $e\n$st');
      rethrow; // let UI show the error too
    }
  }

  Future<void> deleteAppointment(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
  }

  // Debug / devmode

  Future<int> deleteAllAppointments({int pageSize = 200}) async {
    final uid = _uidOrThrow;
    int total = 0;

    // Keep pulling pages until empty
    while (true) {
      final page = await _collection(uid).limit(pageSize).get();
      if (page.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in page.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      total += page.docs.length;

      // Tiny yield to avoid hammering on slow networks
      await Future.delayed(const Duration(milliseconds: 30));
    }
    return total;
  }

  Future<List<String>> createAppointmentsBatch(
    List<AppointmentModel> models,
  ) async {
    final uid = _uidOrThrow;
    final batch = _db.batch();
    final ids = <String>[];

    for (final m in models) {
      final doc = _collection(uid).doc();
      ids.add(doc.id);
      final payload = _toFirestore(m.copyWith(id: doc.id), isCreate: true);
      batch.set(doc, payload);
    }

    await batch.commit();
    return ids;
  }

  Future<
    ({
      List<AppointmentModel> items,
      DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    })
  >
  getAppointmentsPaged({
    DateTime? startInclusive,
    DateTime? endInclusive,
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDoc,
    bool descending = false,
  }) async {
    final uid = _uidOrThrow;
    Query<Map<String, dynamic>> q = _collection(uid);

    // Optionally constrain by date range
    if (startInclusive != null) {
      q = q.where(
        'dateTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive),
      );
    }
    if (endInclusive != null) {
      final endOfDay = DateTime(
        endInclusive.year,
        endInclusive.month,
        endInclusive.day,
        23,
        59,
        59,
        999,
      );
      q = q.where(
        'dateTime',
        isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
      );
    }

    // Order and limit the results
    q = q.orderBy('dateTime', descending: descending).limit(pageSize);

    // If a cursor was provided, start after it
    if (startAfterDoc != null) {
      q = q.startAfterDocument(startAfterDoc);
    }

    final snap = await q.get();
    // Map documents to models
    final items = snap.docs.map(_fromDoc).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;

    // Optionally count reads for bench (like getAppointmentsBetween)
    assert(() {
      if (!snap.metadata.isFromCache) {
        bench?.pagedReads += snap.docs.length;
      }
      return true;
    }());

    return (items: items, lastDoc: lastDoc);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Mapping
  // ────────────────────────────────────────────────────────────────────────────

  AppointmentModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};

    DateTime? dateTime;
    final ts = data['dateTime'];
    if (ts is Timestamp) dateTime = ts.toDate();

    DateTime? payDate;
    final tsPay = data['payDate'];
    if (tsPay is Timestamp) payDate = tsPay.toDate();

    final checklistIds = (data['checklistIds'] as List? ?? const [])
        .map((e) => (e as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final imageUrls = (data['imageUrls'] as List? ?? const [])
        .map((e) => (e as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return AppointmentModel(
      id: snap.id,
      clientId: data['clientId'] as String?,
      serviceId: data['serviceId'] as String?,
      checklistIds: checklistIds,
      dateTime: dateTime,
      payDate: payDate,
      price: (data['price'] as num?)?.toDouble(),
      location: data['location'] as String?,
      note: data['note'] as String?,
      imageUrls: imageUrls,
      status: data['status'] as String?,
    );
  }

  Map<String, dynamic> _toFirestore(
    AppointmentModel m, {
    required bool isCreate,
  }) {
    final map = <String, dynamic>{
      'clientId': m.clientId,
      'serviceId': m.serviceId,
      'checklistIds': m.checklistIds,
      'dateTime': m.dateTime == null ? null : Timestamp.fromDate(m.dateTime!),
      'payDate': m.payDate == null ? null : Timestamp.fromDate(m.payDate!),
      'price': m.price,
      'location': m.location,
      'note': m.note,
      'imageUrls': m.imageUrls,
      'status': m.status,
      if (isCreate) 'progress': <String, dynamic>{},
    };

    map.removeWhere((_, v) => v == null);
    return map;
  }
}
