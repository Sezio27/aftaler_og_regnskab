// lib/services/image_storage.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:image_picker/image_picker.dart';

class ImageStorage {
  ImageStorage({FirebaseAuth? auth, FirebaseStorage? storage})
    : _auth = auth ?? FirebaseAuth.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String get _uidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  Future<String> uploadClientImage({
    required String clientId,
    required XFile file,
  }) async {
    final uid = _uidOrThrow;
    final ref = _storage.ref('users/$uid/clients/$clientId/image');

    final meta = SettableMetadata(
      contentType: file.mimeType ?? 'image/jpeg',
      cacheControl: 'public,max-age=3600',
    );

    // Always use bytes; avoids scoped-storage/path issues.
    final bytes = await file.readAsBytes();

    try {
      final snap = await ref
          .putData(bytes, meta)
          .timeout(const Duration(seconds: 10)); // don’t hang forever
      return await snap.ref.getDownloadURL();
    } on TimeoutException {
      throw Exception('Billedupload tog for lang tid (timeout). Tjek netværk.');
    } on FirebaseException catch (e) {
      // Surface readable Storage errors (rules, bucket, etc.)
      throw Exception('Storage-fejl: ${e.code} ${e.message ?? ""}'.trim());
    }
  }

  Future<String> uploadServiceImage({
    required String serviceId,
    required XFile file,
  }) async {
    final uid = _uidOrThrow;
    final ref = _storage.ref('users/$uid/services/$serviceId/image');

    final meta = SettableMetadata(
      contentType: file.mimeType ?? 'image/jpeg',
      cacheControl: 'public,max-age=3600',
    );

    final bytes = await file.readAsBytes();

    try {
      final snap = await ref
          .putData(bytes, meta)
          .timeout(const Duration(seconds: 10)); // don’t hang forever
      return await snap.ref.getDownloadURL();
    } on TimeoutException {
      throw Exception('Billedupload tog for lang tid (timeout). Tjek netværk.');
    } on FirebaseException catch (e) {
      // Surface readable Storage errors (rules, bucket, etc.)
      throw Exception('Storage-fejl: ${e.code} ${e.message ?? ""}'.trim());
    }
  }

  Future<void> deleteClientImage(String clientId) async {
    final uid = _uidOrThrow;
    final ref = _storage.ref('users/$uid/clients/$clientId/image');
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      // If there isn't an object to delete, treat it as already gone.
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }

  Future<void> deleteServiceImage(String serviceId) async {
    final uid = _uidOrThrow;
    final ref = _storage.ref('users/$uid/services/$serviceId/image');
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }
}
