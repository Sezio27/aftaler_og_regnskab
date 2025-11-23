import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Simple wrapper around Firebase Storage for user-scoped images.
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
    required ({Uint8List bytes, String name, String? mimeType}) image,
  }) async {
    final uid = _uidOrThrow;

    // Store the client image at a fixed path per user/client.
    final ref = _storage.ref('users/$uid/clients/$clientId/image');
    final meta = SettableMetadata(
      contentType: image.mimeType ?? 'image/jpeg',
      cacheControl: 'public,max-age=3600',
    );
    try {
      // Add a timeout so a hanging upload does not block the UI indefinitely.
      final snap = await ref
          .putData(image.bytes, meta)
          .timeout(const Duration(seconds: 10));
      return await snap.ref.getDownloadURL();
    } on TimeoutException {
      throw Exception('Billedupload tog for lang tid (timeout). Tjek netværk.');
    } on FirebaseException catch (e) {
      // Wrap the Firebase error in a user-facing message.
      throw Exception('Storage-fejl: ${e.code} ${e.message ?? ""}'.trim());
    }
  }

  Future<String> uploadServiceImage({
    required String serviceId,
    required ({Uint8List bytes, String name, String? mimeType}) image,
  }) async {
    final uid = _uidOrThrow;
    final ref = _storage.ref('users/$uid/services/$serviceId/image');
    final meta = SettableMetadata(
      contentType: image.mimeType ?? 'image/jpeg',
      cacheControl: 'public,max-age=3600',
    );
    try {
      final snap = await ref
          .putData(image.bytes, meta)
          .timeout(const Duration(seconds: 10));
      return await snap.ref.getDownloadURL();
    } on TimeoutException {
      throw Exception('Billedupload tog for lang tid (timeout). Tjek netværk.');
    } on FirebaseException catch (e) {
      throw Exception('Storage-fejl: ${e.code} ${e.message ?? ""}'.trim());
    }
  }

  Future<List<String>> uploadAppointmentImages({
    required String appointmentId,
    required List<({Uint8List bytes, String name, String? mimeType})> images,
  }) async {
    if (images.isEmpty) return const [];

    final uid = _uidOrThrow;

    // Folder containing all images for a given appointment.
    final folder = _storage.ref('users/$uid/appointments/$appointmentId');

    final uploads = <Future<String>>[];
    for (final img in images) {
      // Use a timestamp prefix to avoid name collisions.
      final name = '${DateTime.now().microsecondsSinceEpoch}_${img.name}';
      final ref = folder.child(name);

      final meta = SettableMetadata(
        contentType: img.mimeType ?? 'image/jpeg',
        cacheControl: 'public,max-age=3600',
      );

      // Each upload is a small async function returning the download URL.
      uploads.add(() async {
        try {
          final snap = await ref
              .putData(img.bytes, meta)
              .timeout(const Duration(seconds: 20));
          return await snap.ref.getDownloadURL();
        } on TimeoutException {
          throw Exception('Billedupload tog for lang tid. Tjek netværk.');
        } on FirebaseException catch (e) {
          throw Exception('Storage-fejl: ${e.code} ${e.message ?? ""}'.trim());
        }
      }());
    }

    // Wait for all uploads and collect the URLs.
    return Future.wait(uploads);
  }

  Future<void> deleteClientImage(String clientId) async {
    final uid = _uidOrThrow;
    final ref = _storage.ref('users/$uid/clients/$clientId/image');
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
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

  Future<void> deleteAppointmentImages(String appointmentId) async {
    final uid = _uidOrThrow;
    final folder = _storage.ref('users/$uid/appointments/$appointmentId');
    try {
      // List all blobs under the appointment folder and delete them one by one.
      final list = await folder.listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }

  Future<void> deleteAppointmentImagesByUrls(Iterable<String> urls) async {
    for (final url in urls) {
      try {
        // Derive the storage reference from the public download URL.
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') continue;
        rethrow;
      }
    }
  }
}
