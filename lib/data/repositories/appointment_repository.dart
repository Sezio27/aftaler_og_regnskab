import 'package:aftaler_og_regnskab/domain/appointment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentRepository {
  AppointmentRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

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

  Future<void> createAppointmentWithId(
    String id,
    AppointmentModel model,
  ) async {
    final uid = _uidOrThrow;
    final payload = _toFirestore(model.copyWith(id: id), isCreate: true);
    await _collection(uid).doc(id).set(payload);
  }

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
        .map((q) {
          return q.docs.map(_fromDoc).toList();
        });
  }

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

  Future<AppointmentModel> addAppointment(AppointmentModel model) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc();
    final payload = _toFirestore(model.copyWith(id: doc.id), isCreate: true);
    await doc.set(payload);
    return model.copyWith(id: doc.id);
  }

  Future<void> updateAppointment(
    String id, {
    AppointmentModel? patch,
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
      await _collection(uid).doc(id).update(payload);
    } else {
      await _collection(uid).doc(id).set(payload, SetOptions(merge: true));
    }
  }

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

  Future<void> deleteAppointment(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
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

    q = q.orderBy('dateTime', descending: descending).limit(pageSize);

    if (startAfterDoc != null) {
      q = q.startAfterDocument(startAfterDoc);
    }

    final snap = await q.get();

    final items = snap.docs.map(_fromDoc).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;

    return (items: items, lastDoc: lastDoc);
  }

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
