import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
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

  // Latest (createdAt desc)
  Stream<AppointmentModel?> watchAppointment() {
    final uid = _uidOrThrow;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((q) => q.docs.isEmpty ? null : _fromDoc(q.docs.first));
  }

  Stream<AppointmentModel?> watchAppointmentById(String id) {
    final uid = _uidOrThrow;
    return _collection(uid).doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return _fromDoc(d);
    });
  }

  Stream<List<AppointmentModel>> watchAppointments() {
    final uid = _uidOrThrow;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  Future<AppointmentModel?> getAppointmentOnce(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  Future<AppointmentModel> addAppointment(AppointmentModel model) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc();
    final payload = _toFirestore(model.copyWith(id: doc.id), isCreate: true);
    await doc.set(payload);
    return model.copyWith(id: doc.id);
  }

  Future<void> createAppointmentWithId(
    String id,
    AppointmentModel model,
  ) async {
    final uid = _uidOrThrow;
    await _collection(
      uid,
    ).doc(id).set(_toFirestore(model.copyWith(id: id), isCreate: true));
  }

  Future<void> updateAppointment(
    String id, {
    AppointmentModel? patch,
    Map<String, Object?>? fields,
  }) async {
    final uid = _uidOrThrow;
    final data = fields ?? _toFirestore(patch!, isCreate: false);
    final withMeta = {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(), // Firestore-only
    }..removeWhere((k, v) => v == null);
    await _collection(uid).doc(id).set(withMeta, SetOptions(merge: true));
  }

  Future<void> deleteAppointment(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
  }

  // ---- Mapping ----
  AppointmentModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};

    DateTime? dt;
    final ts = data['dateTime'];
    if (ts is Timestamp) dt = ts.toDate();

    final checklistIds = (data['checklistIds'] as List? ?? const [])
        .map((e) => (e as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final imageUrls = (data['imageUrls'] as List? ?? const [])
        .map((e) => (e as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return AppointmentModel(
      id: d.id,
      clientId: data['clientId'] as String?,
      serviceId: data['serviceId'] as String?,
      checklistIds: checklistIds,
      dateTime: dt,
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
      'price': m.price,
      'location': m.location,
      'note': m.note,
      'imageUrls': m.imageUrls,
      'status': m.status,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}
