import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: false,
    backgroundColor: cs.onPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Vælg fra bibliotek'),
            onTap: () => ctx.pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tag et billede'),
            onTap: () => ctx.pop(ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}

/// Convenience: opens the sheet and then the picker. Returns the picked photo (or null).
Future<({Uint8List bytes, String name, String? mimeType})?> pickImageViaSheet(
  BuildContext context, {
  int? imageQuality = 85,
  double? maxWidth = 1200,
}) async {
  final source = await showImageSourceSheet(context);
  if (source == null) return null;

  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final name = picked.name.isNotEmpty
      ? picked.name
      : '${DateTime.now().millisecondsSinceEpoch}.jpg';
  return (bytes: bytes, name: name, mimeType: picked.mimeType ?? 'image/jpeg');
}

Future<List<({Uint8List bytes, String name, String? mimeType})>>
pickImagesViaSheet(
  BuildContext context, {
  int imageQuality = 85,
  double maxWidth = 1200,
}) async {
  final source = await showImageSourceSheet(context);
  if (source == null) return [];

  final picker = ImagePicker();

  if (source == ImageSource.camera) {
    final one = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
    if (one == null) return [];
    final bytes = await one.readAsBytes();
    final name = one.name.isNotEmpty
        ? one.name
        : '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return [(bytes: bytes, name: name, mimeType: one.mimeType ?? 'image/jpeg')];
  }

  // Gallery: allow multiple
  final many = await picker.pickMultiImage(
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  final result = <({Uint8List bytes, String name, String? mimeType})>[];
  for (final p in many) {
    final bytes = await p.readAsBytes();
    final name = p.name.isNotEmpty
        ? p.name
        : '${DateTime.now().millisecondsSinceEpoch}.jpg';
    result.add((
      bytes: bytes,
      name: name,
      mimeType: p.mimeType ?? 'image/jpeg',
    ));
  }
  return result;
}
