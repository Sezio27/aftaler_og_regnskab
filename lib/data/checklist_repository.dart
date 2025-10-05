import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChecklistRepository {
  ChecklistRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
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
      _db.collection('users').doc(uid).collection('checklists');

  // Latest one (ordered by Firestore-only createdAt)
  Stream<ChecklistModel?> watchChecklist() {
    final uid = _uidOrThrow;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((q) => q.docs.isEmpty ? null : _fromDoc(q.docs.first));
  }

  // All checklists, latest first
  Stream<List<ChecklistModel>> watchChecklists() {
    final uid = _uidOrThrow;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  Future<ChecklistModel?> getChecklistOnce(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  Future<ChecklistModel> addChecklist(ChecklistModel model) async {
    final uid = _uidOrThrow;
    final doc = _collection(uid).doc();
    final payload = _toFirestore(model.copyWith(id: doc.id), isCreate: true);
    await doc.set(payload);
    return model.copyWith(id: doc.id);
  }

  Future<void> createChecklistWithId(String id, ChecklistModel model) async {
    final uid = _uidOrThrow;
    await _collection(
      uid,
    ).doc(id).set(_toFirestore(model.copyWith(id: id), isCreate: true));
  }

  Future<void> updateChecklist(
    String id, {
    ChecklistModel? patch,
    Map<String, Object?>? fields,
  }) async {
    final uid = _uidOrThrow;
    final data = fields ?? _toFirestore(patch!, isCreate: false);
    final withMeta = {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(), // metadata only in Firestore
    }..removeWhere((k, v) => v == null);

    await _collection(uid).doc(id).set(withMeta, SetOptions(merge: true));
  }

  Future<void> deleteChecklist(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
  }

  // ---- Points: single-write replace strategy ----
  Future<void> setPoints(
    String checklistId,
    List<ChecklistPoint> points,
  ) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(checklistId).set({
      'points': points.map((p) => p.toJson()).toList(),
    }, SetOptions(merge: true));
  }

  // ---- Mapping ----
  ChecklistModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};
    final rawPoints = (data['points'] as List?) ?? const [];
    return ChecklistModel(
      id: d.id,
      name: data['name'] as String?,
      description: data['description'] as String?,
      points: rawPoints
          .map(
            (e) => ChecklistPoint.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  Map<String, dynamic> _toFirestore(
    ChecklistModel m, {
    required bool isCreate,
  }) {
    final map = <String, dynamic>{
      'name': m.name,
      'description': m.description,
      'points': m.points.map((p) => p.toJson()).toList(),
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(), // Firestore-only
      'updatedAt': FieldValue.serverTimestamp(), // Firestore-only
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}
