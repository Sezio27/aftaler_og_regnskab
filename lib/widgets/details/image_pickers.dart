import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aftaler_og_regnskab/widgets/pickers/image_picker_helper.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';

class AvatarImagePicker extends StatelessWidget {
  const AvatarImagePicker({
    super.key,
    this.url,
    this.newImage,
    this.remove = false,
    this.editable = false,
    this.onChanged,
    this.radius = 46,
  });

  final String? url;
  final ({Uint8List bytes, String name, String? mimeType})? newImage;
  final bool remove;
  final bool editable;
  final void Function(
    ({Uint8List bytes, String name, String? mimeType})? image,
    bool remove,
  )?
  onChanged;
  final double radius;

  Future<void> _pick(BuildContext context) async {
    final picked = await pickImageViaSheet(context);
    if (picked != null) onChanged?.call(picked, false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasUrl = (url ?? '').isNotEmpty;
    final hasImage = (newImage != null) || (hasUrl && !remove);

    final ImageProvider<Object>? provider = newImage != null
        ? MemoryImage(newImage!.bytes)
        : (hasUrl && !remove ? NetworkImage(url!) : null);

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: cs.secondary.withAlpha(150),
      backgroundImage: provider,
      child: provider == null ? const Icon(Icons.person, size: 36) : null,
    );

    if (!editable) return avatar;

    final showUndoNew = newImage != null;
    final showUndoRemove = (newImage == null && remove);
    final showDelete = (newImage == null && !remove && hasImage);
    final showChip = showUndoNew || showUndoRemove || showDelete;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(onTap: () => _pick(context), child: avatar),

        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _pick(context),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),

        if (showChip)
          Positioned(
            left: 8,
            top: 8,
            child: Material(
              color: cs.surface.withAlpha(230),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (showUndoNew) {
                    onChanged?.call(null, false);
                  } else if (showUndoRemove) {
                    onChanged?.call(null, false);
                  } else if (showDelete) {
                    onChanged?.call(null, true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showUndoNew
                            ? Icons.undo
                            : (showUndoRemove
                                  ? Icons.undo
                                  : Icons.delete_outline),
                        size: 16,
                        color: cs.onSurface.withAlpha(200),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        showUndoNew
                            ? 'Fortryd'
                            : (showUndoRemove ? 'Fortryd' : 'Fjern billede'),
                        style: AppTypography.b6.copyWith(
                          color: cs.onSurface.withAlpha(220),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 16:9 banner (used for Service)
class BannerImagePicker extends StatelessWidget {
  const BannerImagePicker({
    super.key,
    this.url,
    this.newImage,
    this.remove = false,
    this.editable = false,
    this.onChanged,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 12,
  });

  final String? url;
  final ({Uint8List bytes, String name, String? mimeType})? newImage;
  final bool remove;
  final bool editable;
  final void Function(
    ({Uint8List bytes, String name, String? mimeType})? image,
    bool remove,
  )?
  onChanged;
  final double aspectRatio;
  final double borderRadius;

  Future<void> _pick(BuildContext context) async {
    final picked = await pickImageViaSheet(context);
    if (picked != null) onChanged?.call(picked, false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasUrl = (url ?? '').isNotEmpty;
    final hasImage = (newImage != null) || (hasUrl && !remove);

    Widget content;
    if (newImage != null) {
      content = Image.memory(
        newImage!.bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(cs),
      );
    } else if (hasUrl && !remove) {
      content = Image.network(
        url!,
        fit: BoxFit.cover,
        loadingBuilder: (c, w, p) => p == null
            ? w
            : Container(
                alignment: Alignment.center,
                color: cs.surfaceVariant.withAlpha(80),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
        errorBuilder: (_, __, ___) => _placeholder(cs),
      );
    } else {
      content = _placeholder(cs);
    }

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(aspectRatio: aspectRatio, child: content),
    );

    if (!editable) return image;

    final showUndoNew = newImage != null;
    final showUndoRemove = (newImage == null && remove);
    final showDelete = (newImage == null && !remove && hasImage);
    final showChip = showUndoNew || showUndoRemove || showDelete;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(onTap: () => _pick(context), child: image),

        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _pick(context),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),

        if (showChip)
          Positioned(
            left: 8,
            top: 8,
            child: Material(
              color: cs.surface.withAlpha(230),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (showUndoNew) {
                    onChanged?.call(null, false);
                  } else if (showUndoRemove) {
                    onChanged?.call(null, false);
                  } else if (showDelete) {
                    onChanged?.call(null, true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showUndoNew
                            ? Icons.undo
                            : (showUndoRemove
                                  ? Icons.undo
                                  : Icons.delete_outline),
                        size: 16,
                        color: cs.onSurface.withAlpha(200),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        showUndoNew
                            ? 'Fortryd'
                            : (showUndoRemove ? 'Fortryd' : 'Fjern billede'),
                        style: AppTypography.b6.copyWith(
                          color: cs.onSurface.withAlpha(220),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    alignment: Alignment.center,
    child: Icon(
      Icons.hotel_class,
      size: 40,
      color: cs.onSurface.withAlpha(150),
    ),
  );
}
