import 'package:aftaler_og_regnskab/model/checklist_model.dart';
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

  Stream<ChecklistModel?> watchChecklist(String id) {
    final uid = _uidOrThrow;
    return _collection(uid).doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return _fromDoc(d);
    });
  }

  // All checklists, latest first
  Stream<List<ChecklistModel>> watchChecklists() {
    final uid = _uidOrThrow;
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  Future<ChecklistModel?> getChecklist(String id) async {
    final uid = _uidOrThrow;
    final snap = await _collection(uid).doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  Future<Map<String, ChecklistModel?>> getChecklists(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final uid = _uidOrThrow;
    final idsList = ids.toList();
    final result = <String, ChecklistModel?>{};
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
    final payload = {...data}..removeWhere((k, v) => v == null);

    await _collection(uid).doc(id).set(payload, SetOptions(merge: true));
  }

  Future<void> deleteChecklist(String id) async {
    final uid = _uidOrThrow;
    await _collection(uid).doc(id).delete();
  }

  Future<void> setPoints(String checklistId, List<String> points) async {
    final uid = _uidOrThrow;
    final clean = points
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await _collection(
      uid,
    ).doc(checklistId).set({'points': clean}, SetOptions(merge: true));
  }

  ChecklistModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const <String, dynamic>{};
    final rawPoints = (data['points'] as List?) ?? const [];
    final points = rawPoints
        .map((e) => (e as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return ChecklistModel(
      id: d.id,
      name: data['name'] as String?,
      description: data['description'] as String?,
      points: points,
    );
  }

  Map<String, dynamic> _toFirestore(
    ChecklistModel m, {
    required bool isCreate,
  }) {
    final map = <String, dynamic>{
      'name': m.name,
      'description': m.description,
      'points': m.points
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }
}
