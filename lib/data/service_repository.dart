import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository = the app's data facade for Clients.
/// - Hides Firestore specifics (FieldValue, Timestamp, paths).
/// - Exposes typed methods the rest of the app can call.
class ServiceRepository {
  ServiceRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
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
      _db.collection('users').doc(uid).collection('services');

  Stream<ServiceModel?> watchService(String id) {
    final uid = _uidOrThrow;
    return _collection(uid).doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return _fromDoc(d);
    });
  }

  Stream<List<ServiceModel>> watchServices() {
    final uid = _uidOrThrow;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  Future<ServiceModel?> getServiceOnce(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  Future<Map<String, ServiceModel?>> getServices(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final uid = _uidOrThrow;
    final idsList = ids.toList();
    final result = <String, ServiceModel?>{};
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

  Future<ServiceModel> addService(ServiceModel model) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc();
    final payload = _toFirestore(model.copyWith(id: doc.id), isCreate: true);
    await doc.set(payload);

    return model.copyWith(id: doc.id);
  }

  DocumentReference<Map<String, dynamic>> newServiceRef() {
    final uid = _uidOrThrow;
    return _collection(uid).doc();
  }

  Future<void> createServiceWithId(String id, ServiceModel model) async {
    final uid = _uidOrThrow;
    final payload = _toFirestore(model.copyWith(id: id), isCreate: true);
    await _collection(uid).doc(id).set(payload);
  }

  Future<void> updateService(
    String id, {
    ServiceModel? patch,
    Map<String, Object?>? fields,
    Set<String> deletes = const {}, // <-- NEW
  }) async {
    final uid = _uidOrThrow;

    // prefer explicit fields; otherwise map from patch
    final base = fields ?? _toFirestore(patch!, isCreate: false);

    final withMeta = <String, Object?>{...base};

    // translate deletes here (Firebase-specific)
    for (final key in deletes) {
      withMeta[key] = FieldValue.delete();
    }

    // keep dropping nulls, but don't drop FieldValue.delete()
    withMeta.removeWhere((k, v) => v == null);

    await _collection(uid).doc(id).set(withMeta, SetOptions(merge: true));
  }

  Future<void> deleteService(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
  }

  ServiceModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};
    return ServiceModel(
      id: d.id,
      name: data['name'] as String?,
      description: data['description'] as String?,
      duration: data['duration'] as String?,
      price: (data['price'] as num?)?.toDouble(),
      image: data['image'] as String?,
    );
  }

  Map<String, dynamic> _toFirestore(ServiceModel m, {required bool isCreate}) {
    final map = <String, dynamic>{
      'name': m.name,
      'description': m.description,
      'duration': m.duration,
      'price': m.price,
      'image': m.image,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}
