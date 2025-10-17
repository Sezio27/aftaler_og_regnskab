// lib/widgets/images_picker_grid.dart
import 'dart:io';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aftaler_og_regnskab/widgets/image_picker_helper.dart';

class ImagesPickerGrid extends StatefulWidget {
  const ImagesPickerGrid({
    super.key,
    this.initial,
    this.onChanged,
    this.addLabel = 'Tilføj billeder',
    this.emptyLabel = 'Tilføj billeder',
    this.viewOnly = false,
  });

  final List<XFile>? initial;
  final ValueChanged<List<XFile>>? onChanged;
  final String addLabel;
  final String emptyLabel;
  final bool viewOnly;

  @override
  State<ImagesPickerGrid> createState() => _ImagesPickerGridState();
}

class _ImagesPickerGridState extends State<ImagesPickerGrid> {
  late List<XFile> _files;

  @override
  void initState() {
    super.initState();
    _files = List<XFile>.from(widget.initial ?? const []);
  }

  void _notify() => widget.onChanged?.call(List.unmodifiable(_files));

  Future<void> _addImages() async {
    final picked = await pickImagesViaSheet(context);
    if (picked.isEmpty) return;
    setState(() => _files.addAll(picked));
    _notify();
  }

  void _removeAt(int index) {
    setState(() => _files.removeAt(index));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Empty state: just a "+ Tilføj billeder" button

    if (_files.isEmpty) {
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

    // With images: grid + "+ Tilføj" underneath
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (ctx, c) {
            final crossAxisCount = c.maxWidth >= 520 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (ctx, i) => _ImageTile(
                file: _files[i],
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
    required this.file,
    required this.onRemove,
    this.canRemove = true,
  });
  final XFile file;
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
          Image.file(File(file.path), fit: BoxFit.cover),
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
