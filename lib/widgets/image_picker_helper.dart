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
Future<XFile?> pickImageViaSheet(
  BuildContext context, {
  int? imageQuality = 85,
  double? maxWidth = 1200,
}) async {
  final source = await showImageSourceSheet(context);
  if (source == null) return null;

  final picker = ImagePicker();
  return picker.pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
}

Future<List<XFile>> pickImagesViaSheet(
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
    return one == null ? [] : [one];
  }

  // Gallery: allow multiple
  final many = await picker.pickMultiImage(
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  return many;
}
