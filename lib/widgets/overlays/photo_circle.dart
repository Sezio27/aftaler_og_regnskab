import 'dart:io';

import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoCircle extends StatelessWidget {
  const PhotoCircle({
    super.key,
    required this.image,
    required this.onTap,
    required this.onClear,
    this.showStroke = false,
  });

  final XFile? image;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool showStroke;

  @override
  Widget build(BuildContext context) {
    const double size = 140;
    final cs = Theme.of(context).colorScheme;
    final border = showStroke ? Border.all(color: cs.primary) : null;
    final bg = cs.surface;

    Widget inner;
    if (image == null) {
      inner = Center(
        child: Text(
          'Tilføj billede',
          textAlign: TextAlign.center,
          style: AppTypography.b4.copyWith(color: cs.onSurface.withAlpha(200)),
        ),
      );
    } else {
      inner = ClipOval(
        child: Image.file(
          File(image!.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Stack(
      alignment: Alignment.topRight,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: border,
            ),
            child: inner,
          ),
        ),
        if (image != null)
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.close, size: 16),
              onPressed: onClear,
              tooltip: 'Fjern billede',
            ),
          ),
      ],
    );
  }
}
