import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientRepository {
  ClientRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
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
      _db.collection('users').doc(uid).collection('clients');

  Stream<ClientModel?> watchClient(String id) {
    final uid = _uidOrThrow;
    return _collection(uid).doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return _fromDoc(d);
    });
  }

  Stream<List<ClientModel>> watchClients() {
    final uid = _uidOrThrow;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  Future<ClientModel?> getClient(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  Future<Map<String, ClientModel?>> getClients(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final uid = _uidOrThrow;
    final idsList = ids.toList();
    final result = <String, ClientModel?>{};
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

  Future<ClientModel> addClient(ClientModel model) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc();
    final payload = _toFirestore(model.copyWith(id: doc.id), isCreate: true);
    await doc.set(payload);
    return model.copyWith(id: doc.id);
  }

  DocumentReference<Map<String, dynamic>> newClientRef() {
    final uid = _uidOrThrow;
    return _collection(uid).doc();
  }

  Future<void> createClientWithId(String id, ClientModel model) async {
    final uid = _uidOrThrow;
    final payload = _toFirestore(model.copyWith(id: id), isCreate: true);
    await _collection(uid).doc(id).set(payload);
  }

  Future<void> updateClient(
    String id, {
    ClientModel? patch,
    Map<String, Object?>? fields,
    Set<String> deletes = const {},
  }) async {
    final uid = _uidOrThrow;

    final base = fields ?? _toFirestore(patch!, isCreate: false);

    final payload = <String, Object?>{...base};

    for (final key in deletes) {
      payload[key] = FieldValue.delete();
    }

    payload.removeWhere((k, v) => v == null);

    await _collection(uid).doc(id).set(payload, SetOptions(merge: true));
  }

  Future<void> deleteClient(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
  }

  ClientModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};
    return ClientModel(
      id: d.id,
      name: data['name'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      city: data['city'] as String?,
      postal: data['postal'] as String?,
      cvr: data['cvr'] as String?,
      image: data['image'] as String?,
    );
  }

  Map<String, dynamic> _toFirestore(ClientModel m, {required bool isCreate}) {
    final map = <String, dynamic>{
      'name': m.name,
      'phone': m.phone,
      'email': m.email,
      'address': m.address,
      'city': m.city,
      'postal': m.postal,
      'cvr': m.cvr,
      'image': m.image,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}
