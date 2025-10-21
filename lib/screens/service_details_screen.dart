import 'dart:io';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/persistence_ops.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/details/action_buttons.dart';
import 'package:aftaler_og_regnskab/widgets/details/image_pickers.dart';
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
                BannerImagePicker(
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
        ReadActionsRow(onEdit: onEdit, onDelete: onDelete),
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
                  BannerImagePicker(
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
            builder: (context, saving, _) => EditActionsRow(
              saving: saving,
              onCancel: widget.onCancel,
              onConfirm: _save,
            ),
          ),
        ],
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
