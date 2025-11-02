import 'dart:typed_data';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/widgets/pickers/image_picker_helper.dart';

class ImagesPickerGrid extends StatefulWidget {
  const ImagesPickerGrid({
    super.key,
    this.initial,
    this.onChanged,
    this.addLabel = 'Tilføj billeder',
    this.emptyLabel = 'Tilføj billeder',
    this.viewOnly = false,
  });

  final List<({Uint8List bytes, String name, String? mimeType})>? initial;
  final ValueChanged<List<({Uint8List bytes, String name, String? mimeType})>>?
  onChanged;
  final String addLabel;
  final String emptyLabel;
  final bool viewOnly;

  @override
  State<ImagesPickerGrid> createState() => _ImagesPickerGridState();
}

class _ImagesPickerGridState extends State<ImagesPickerGrid> {
  late List<({Uint8List bytes, String name, String? mimeType})> _images;

  @override
  void initState() {
    super.initState();
    _images = List<({Uint8List bytes, String name, String? mimeType})>.from(
      widget.initial ?? const [],
    );
  }

  void _notify() => widget.onChanged?.call(List.unmodifiable(_images));

  Future<void> _addImages() async {
    final picked = await pickImagesViaSheet(context);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked));
    _notify();
  }

  void _removeAt(int index) {
    setState(() => _images.removeAt(index));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_images.isEmpty) {
      return Center(
        child: widget.viewOnly
            ? Text("Ingen billeder tilføjet", style: AppTypography.b3)
            : TextButton.icon(
                onPressed: _addImages,
                icon: const Icon(Icons.add),
                label: Text(
                  widget.emptyLabel,
                  style: AppTypography.b3.copyWith(color: cs.primary),
                ),
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (ctx, c) {
            final crossAxisCount = c.maxWidth >= 520 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _images.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (ctx, i) => _ImageTile(
                bytes: _images[i].bytes,
                onRemove: () => _removeAt(i),
                canRemove: !widget.viewOnly,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        if (!widget.viewOnly)
          Center(
            child: TextButton.icon(
              onPressed: _addImages,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                widget.addLabel,
                style: AppTypography.b3.copyWith(color: cs.primary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.bytes,
    required this.onRemove,
    this.canRemove = true,
  });
  final Uint8List bytes;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Colors.black12),
          ),
          if (canRemove)
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: cs.surface.withAlpha(200),
                  padding: EdgeInsets.zero,
                ),
                tooltip: 'Fjern',
              ),
            ),
        ],
      ),
    );
  }
}
