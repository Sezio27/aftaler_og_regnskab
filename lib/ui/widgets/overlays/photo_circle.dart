import 'dart:typed_data';
import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:flutter/material.dart';

class PhotoCircle extends StatelessWidget {
  const PhotoCircle({
    super.key,
    required this.image,
    required this.onTap,
    required this.onClear,
    this.showStroke = false,
  });

  final ({Uint8List bytes, String name, String? mimeType})? image;
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
        child: Image.memory(
          image!.bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Material(
          color: bg,
          elevation: 2,
          shape: CircleBorder(
            side: showStroke ? BorderSide(color: cs.primary) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,

          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(width: size, height: size, child: inner),
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
