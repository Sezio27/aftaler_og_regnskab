import 'dart:io';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/persistence_ops.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/image_picker_helper.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ServiceDetailsScreen extends StatelessWidget {
  const ServiceDetailsScreen({super.key, required this.serviceId});
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ServiceViewModel>();
    return StreamBuilder<ServiceModel?>(
      stream: vm.watchService(serviceId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Fejl: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final service = snap.data;
        if (service == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const SizedBox.shrink();
        }

        return _ServiceDetailsView(key: ValueKey(service.id), service: service);
      },
    );
  }
}

class _ServiceDetailsView extends StatefulWidget {
  const _ServiceDetailsView({super.key, required this.service});
  final ServiceModel service;

  @override
  State<_ServiceDetailsView> createState() => _ServiceDetailsViewState();
}

class _ServiceDetailsViewState extends State<_ServiceDetailsView> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final hPad = LayoutMetrics.horizontalPadding(context);

    return SingleChildScrollView(
      key: const PageStorageKey('serviceDetailsScroll'), // keeps scroll offset
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hPad,
          10,
          hPad,
          LayoutMetrics.navBarHeight(context) + 30,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _editing
              ? _ServiceEditPane(
                  key: const ValueKey('edit'),
                  service: widget.service,
                  onCancel: () => setState(() => _editing = false),
                  onSaved: () => setState(() => _editing = false),
                )
              : _ServiceReadPane(
                  key: const ValueKey('read'),
                  service: widget.service,
                  onEdit: () => setState(() => _editing = true),
                  onDelete: () async {
                    await handleDelete(
                      context: context,
                      componentLabel: 'Service',
                      onDelete: () => context.read<ServiceViewModel>().delete(
                        widget.service.id!,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ServiceReadPane extends StatelessWidget {
  const _ServiceReadPane({
    super.key,
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });
  final ServiceModel service;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.all(35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                //Image
                _ServiceImage(
                  url: service.image,
                  aspectRatio: 16 / 9,
                  borderRadius: 12,
                ),
                const SizedBox(height: 40),
                //Title
                Text(service.name!, style: AppTypography.h3),
                const SizedBox(height: 40),

                // Price
                _InfoRow(
                  icon: Icons.sell_outlined,
                  label: 'Pris',
                  value: service.price?.isNotEmpty == true
                      ? service.price!
                      : '—',
                ),
                const SizedBox(height: 26),

                // Duration
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Varighed',
                  value: service.duration != null
                      ? '${service.duration} timer'
                      : '—',
                ),

                const SizedBox(height: 40),

                // Description
                if ((service.description ?? '').isNotEmpty) ...[
                  Text(service.description!, style: AppTypography.b2),
                ] else ...[
                  Text('Ingen beskrivelse', style: AppTypography.b2),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: "Rediger",
                  textStyle: AppTypography.button3.copyWith(
                    color: cs.onSurface.withAlpha(200),
                  ),
                  onTap: onEdit,
                  borderRadius: 12,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: cs.onSurface.withAlpha(200),
                  ),
                  color: cs.onPrimary,
                  borderStroke: Border.all(color: cs.onSurface.withAlpha(200)),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: CustomButton(
                  text: "Slet",
                  textStyle: AppTypography.button3.copyWith(
                    color: cs.error.withAlpha(200),
                  ),
                  onTap: onDelete,
                  borderRadius: 12,
                  icon: Icon(Icons.delete, color: cs.error.withAlpha(200)),
                  color: cs.onPrimary,
                  borderStroke: Border.all(color: cs.error.withAlpha(200)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceEditPane extends StatefulWidget {
  const _ServiceEditPane({
    super.key,
    required this.service,
    required this.onCancel,
    required this.onSaved,
  });
  final ServiceModel service;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_ServiceEditPane> createState() => __ServiceEditPaneState();
}

class __ServiceEditPaneState extends State<_ServiceEditPane> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _dur;
  late final TextEditingController _desc;
  int? _active;

  XFile? _newPhoto;
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.service.name ?? '');
    _price = TextEditingController(text: widget.service.price ?? '');
    _dur = TextEditingController(text: widget.service.duration ?? '');
    _desc = TextEditingController(text: widget.service.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _dur.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickNewPhoto() async {
    final picked = await pickImageViaSheet(context);
    if (picked != null && mounted) {
      setState(() => _newPhoto = picked);
    }
  }

  Future<void> _save() async {
    await handleSave(
      context: context,
      validate: () {
        final name = _name.text.trim();
        if (name.isEmpty) return 'Angiv navn på servicen';
        return null;
      },
      onSave: () => context.read<ServiceViewModel>().updateServiceFields(
        widget.service.id!,
        name: _name.text.trim(),
        description: _desc.text,
        duration: _dur.text,
        price: _price.text,
        newImage: _newPhoto,
        removeImage: _removeImage,
      ),
      errorText: () => context.read<ServiceViewModel>().error ?? 'Ukendt fejl',
      onSuccess: widget.onSaved, // flip back to read mode
    );
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapRegion(
      onTapInside: (_) => _clearFocus(),
      onTapOutside: (_) => _clearFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.all(35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _pickNewPhoto,
                    child: _ServiceImage(
                      url: widget.service.image,
                      newFile: _newPhoto,
                      remove: _removeImage,
                      editable: true,
                      aspectRatio: 16 / 9,
                      onChanged: (file, remove) {
                        setState(() {
                          _newPhoto = file;
                          _removeImage = remove;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  SoftTextField(
                    hintText: 'Navn',
                    controller: _name,
                    fill: cs.onPrimary,
                    borderRadius: 8,
                    showStroke: true,
                    strokeColor: _active != 1
                        ? cs.onSurface.withAlpha(50)
                        : cs.primary,
                    strokeWidth: _active != 1 ? 1 : 1.5,
                    onTap: () => setState(() => _active = 1),
                  ),
                  const SizedBox(height: 18),

                  // Price
                  SoftTextField(
                    hintText: 'Pris (fx 1200 kr)',
                    controller: _price,
                    suffixText: "DKK",
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    fill: cs.onPrimary,
                    borderRadius: 8,
                    showStroke: true,
                    strokeColor: _active != 2
                        ? cs.onSurface.withAlpha(50)
                        : cs.primary,
                    strokeWidth: _active != 2 ? 1 : 1.5,
                    onTap: () => setState(() => _active = 2),
                  ),
                  const SizedBox(height: 18),

                  // Duration
                  SoftTextField(
                    hintText: 'Varighed (timer, fx 1.5)',
                    controller: _dur,
                    suffixText: "Timer",
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    fill: cs.onPrimary,
                    borderRadius: 8,
                    showStroke: true,
                    strokeColor: _active != 3
                        ? cs.onSurface.withAlpha(50)
                        : cs.primary,
                    strokeWidth: _active != 3 ? 1 : 1.5,
                    onTap: () => setState(() => _active = 3),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  SoftTextField(
                    hintText: 'Beskrivelse',
                    controller: _desc,
                    maxLines: 4,
                    fill: cs.onPrimary,
                    borderRadius: 8,
                    showStroke: true,
                    strokeColor: _active != 4
                        ? cs.onSurface.withAlpha(50)
                        : cs.primary,
                    strokeWidth: _active != 4 ? 1 : 1.5,
                    onTap: () => setState(() => _active = 4),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Selector<ServiceViewModel, bool>(
            selector: (_, vm) => vm.saving,
            builder: (context, saving, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Annuller',
                      onTap: widget.onCancel,
                      borderRadius: 12,
                      color: cs.onPrimary,
                      textStyle: AppTypography.button3.copyWith(
                        color: cs.onSurface.withAlpha(200),
                      ),
                      borderStroke: Border.all(
                        color: cs.onSurface.withAlpha(200),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: CustomButton(
                      text: saving ? "Gemmer" : "Bekræft",
                      onTap: saving ? () {} : _save,
                      borderRadius: 12,
                      color: cs.primary.withAlpha(200),
                      textStyle: AppTypography.button3.copyWith(
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceImage extends StatelessWidget {
  const _ServiceImage({
    super.key,
    this.url,
    this.newFile,
    this.remove = false,
    this.editable = false,
    this.onChanged, // (file, remove)
    this.aspectRatio = 16 / 9,
    this.borderRadius = 12,
  });

  final String? url;
  final XFile? newFile;
  final bool remove;
  final bool editable;
  final void Function(XFile? file, bool remove)? onChanged;

  final double aspectRatio;
  final double borderRadius;

  Future<void> _pick(BuildContext context) async {
    final picked = await pickImageViaSheet(context);
    if (picked != null)
      onChanged?.call(picked, false); // picking cancels removal
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content;
    if (newFile != null) {
      content = Image.file(File(newFile!.path), fit: BoxFit.cover);
    } else if (remove) {
      content = const _ImagePlaceholder();
    } else if ((url ?? '').isNotEmpty) {
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
        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
      );
    } else {
      content = const _ImagePlaceholder();
    }

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(aspectRatio: aspectRatio, child: content),
    );

    if (!editable) return image; // read mode: unchanged

    // edit mode: tap to pick + small top-left action
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Whole image tappable to pick
        GestureDetector(onTap: () => _pick(context), child: image),

        // Bottom-right pencil
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.edit, size: 18, color: Colors.white),
          ),
        ),

        // Top-left chip: remove / undo remove / undo new
        Positioned(
          left: 8,
          top: 8,
          child: Material(
            color: cs.surface.withAlpha(230),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (newFile != null) {
                  onChanged?.call(null, false); // undo new
                } else if (remove) {
                  onChanged?.call(null, false); // undo removal
                } else {
                  onChanged?.call(null, true); // request removal
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
                      newFile != null
                          ? Icons.undo
                          : (remove ? Icons.undo : Icons.delete_outline),
                      size: 16,
                      color: cs.onSurface.withAlpha(200),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      newFile != null
                          ? 'Fortryd nyt'
                          : (remove ? 'Fortryd fjernelse' : 'Fjern billede'),
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

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greyBackground.withAlpha(200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.hotel_class,
        size: 40,
        color: cs.onSurface.withAlpha(150),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: cs.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.h4),
              const SizedBox(height: 4),
              Text(value, style: AppTypography.num3),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRowEdit extends StatelessWidget {
  const _InfoRowEdit({
    required this.icon,
    required this.label,
    required this.editChild,
  });

  final IconData icon;
  final String label;
  final Widget editChild;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: cs.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.h4),
              const SizedBox(height: 4),
              editChild,
            ],
          ),
        ),
      ],
    );
  }
}
