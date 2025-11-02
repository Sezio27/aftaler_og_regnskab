import 'package:aftaler_og_regnskab/model/onboarding_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  UserRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String? get _uid => _auth.currentUser?.uid;

  Future<void> saveOnboarding(OnboardingModel model) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    final docRef = _db.collection('users').doc(uid);
    final now = FieldValue.serverTimestamp();
    final base = model.toFirestoreMap(uid: uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final payload = {
        ...base,
        if (!snap.exists) 'createdAt': now,
        'updatedAt': now,
      };
      tx.set(docRef, payload, SetOptions(merge: true));
    });

    final user = _auth.currentUser;
    final name = model.firstName;
    if (user != null && name!.isNotEmpty && user.displayName != name) {
      try {
        await user.updateDisplayName(name);
      } catch (_) {}
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> fetchUserDoc() async {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> userDocStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> patchUserData(Map<String, Object?> patch) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    await _db.collection('users').doc(uid).set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> userDocExists({String? uid}) async {
    final id = uid ?? _uid;
    if (id == null) return false;
    final snap = await _db.collection('users').doc(id).get();
    return snap.exists;
  }
}
