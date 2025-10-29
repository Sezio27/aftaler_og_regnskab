import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository = the app's data facade for Clients.
/// - Hides Firestore specifics (FieldValue, Timestamp, paths).
/// - Exposes typed methods the rest of the app can call.
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

  /// Live stream of all clients for the signed-in user.
  /// Ordered by createdAt (server time). Falls back safely if missing.
  Stream<List<ClientModel>> watchClients() {
    final uid = _uidOrThrow;
    // If you have newly created docs without createdAt yet,
    // you can omit orderBy or handle with try/catch.
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  /// Fetch one client once (returns null if not found).
  Future<ClientModel?> getClientOnce(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  // ---------- CREATE ----------

  /// Create a new client. Returns the created domain object (with id).
  Future<ClientModel> addClient(ClientModel model) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc(); // let Firestore generate id
    final payload = _toFirestore(model.copyWith(id: doc.id), isCreate: true);
    await doc.set(payload);
    // We *could* wait for a fresh snapshot; but returning the model is fine.
    return model.copyWith(id: doc.id);
  }

  DocumentReference<Map<String, dynamic>> newClientRef() {
    final uid = _uidOrThrow;
    return _collection(uid).doc(); // generates clientId
  }

  Future<void> createClientWithId(String id, ClientModel model) async {
    final uid = _uidOrThrow;
    final payload = _toFirestore(model.copyWith(id: id), isCreate: true);
    await _collection(uid).doc(id).set(payload);
  }

  // ---------- UPDATE (PATCH) ----------

  /// Patch fields on an existing client (pass only what changed).
  Future<void> updateClient(
    String id, {
    ClientModel? patch,
    Map<String, Object?>? fields,
    Set<String> deletes = const {}, // <--- NEW
  }) async {
    final uid = _uidOrThrow;

    // Prefer explicit fields if provided; otherwise map from patch.
    final base = fields ?? _toFirestore(patch!, isCreate: false);

    // Build final payload, add server timestamp.
    final payload = <String, Object?>{...base};

    // Translate deletes here (Firebase-specific).
    for (final key in deletes) {
      payload[key] = FieldValue.delete();
    }

    // Optional: still drop nulls from 'fields' to avoid writing null values.
    payload.removeWhere((k, v) => v == null);

    await _collection(uid).doc(id).set(payload, SetOptions(merge: true));
  }

  // ---------- DELETE ----------

  Future<void> deleteClient(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
  }

  // ---------- HELPERS ----------

  /// Map Firestore doc -> domain model (keep Firebase types here only).
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
      image: data['image'] as String?, // expect a URL if you use Storage
    );
  }

  /// Map domain -> Firestore map (drop nulls; add server timestamps).
  Map<String, dynamic> _toFirestore(ClientModel m, {required bool isCreate}) {
    final map = <String, dynamic>{
      'name': m.name,
      'phone': m.phone,
      'email': m.email,
      'address': m.address,
      'city': m.city,
      'postal': m.postal,
      'cvr': m.cvr,
      'image': m.image, // URL string if you upload images
      // Metadata
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}
