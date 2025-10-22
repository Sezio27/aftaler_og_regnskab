import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository for reading/writing appointments under:
///   users/{uid}/appointments/{appointmentId}
///
/// Notes:
/// - All calendar reads should be **range-driven** by `dateTime`.
/// - Writes set `createdAt` (on create) and always touch `updatedAt` (server).
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
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  /// One-time fetch of an appointment by id.
  Future<AppointmentModel?> getAppointmentOnce(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
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
    final withMeta = <String, Object?>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final key in deletes) {
      withMeta[key] = FieldValue.delete();
    }
    withMeta.removeWhere((k, v) => v == null);

    await _collection(uid).doc(id).set(withMeta, SetOptions(merge: true));
  }

  Future<void> updateStatus(String id, String newStatus) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).set({
      'status': newStatus.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _collection(uid).doc(apptId).set(payload, SetOptions(merge: true));
  }

  Future<void> updateChecklistSelectionAndResets({
    required String apptId,
    required Set<String> newSelection,
    Set<String> removedIds = const {},
    Set<String> resetProgressIds = const {},
  }) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc(apptId);

    // Build payload for update(): dotted paths for deletes are supported here.
    final Map<String, Object?> payload = {
      'checklistIds': newSelection.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Delete nested progress entries for removed or reset ids
    final toDelete = {...removedIds, ...resetProgressIds};
    for (final id in toDelete) {
      // ⚠ If your checklist IDs could contain a dot ".", use IDs without dots.
      payload['progress.$id'] = FieldValue.delete();
    }

    await doc.update(payload);
  }

  /// Delete an appointment document.
  Future<void> deleteAppointment(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
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
      price: data['price'] as String?,
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
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    map.removeWhere((_, v) => v == null);
    return map;
  }
}
