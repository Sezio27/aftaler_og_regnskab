import 'dart:typed_data';

import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/image_picker_helper.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/photo_circle.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AddServicePanel extends StatefulWidget {
  const AddServicePanel({super.key});

  @override
  State<AddServicePanel> createState() => _AddServicePanelState();
}

class _AddServicePanelState extends State<AddServicePanel> {
  int? _active;
  ({Uint8List bytes, String name, String? mimeType})? _photo;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  Future<void> _choosePhoto() async {
    _clearFocus();
    setState(() {
      _active = 5;
    });
    final picked = await pickImageViaSheet(context);
    if (!mounted) return;
    if (picked != null) {
      setState(() => _photo = picked);
    }
    setState(() {
      _active = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<ServiceViewModel>();

    return TapRegion(
      onTapInside: (_) => _clearFocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          spacing: 14,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      'Tilføj ny service',
                      style: AppTypography.b1.copyWith(color: cs.onSurface),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
            SoftTextField(
              title: 'Service navn',
              hintText: "F.eks. Bryllups makeup",
              controller: _nameCtrl,
              showStroke: _active == 0,
              onTap: () => setState(() => _active = 0),
            ),
            const SizedBox(height: 4),
            SoftTextField(
              title: 'Beskrivelse',
              hintText: "Kort beskrivelse af servicen...",
              controller: _descCtrl,
              maxLines: 3,
              showStroke: _active == 1,
              onTap: () => setState(() => _active = 1),
            ),
            const SizedBox(height: 4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fields
                Expanded(
                  child: Column(
                    children: [
                      SoftTextField(
                        title: 'Varighed (timer)',
                        hintText: "2",
                        hintStyle: AppTypography.input2.copyWith(
                          color: cs.onSurface.withAlpha(200),
                        ),
                        showStroke: _active == 3,
                        keyboardType: TextInputType.number,
                        controller: _durCtrl,
                        onTap: () => setState(() => _active = 3),
                      ),
                      SizedBox(height: 12),
                      SoftTextField(
                        title: 'Pris (DKK)',
                        hintText: "1500",
                        hintStyle: AppTypography.input2.copyWith(
                          color: cs.onSurface.withAlpha(200),
                        ),
                        showStroke: _active == 4,
                        keyboardType: TextInputType.number,
                        controller: _priceCtrl,
                        onTap: () => setState(() => _active = 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                PhotoCircle(
                  image: _photo,
                  showStroke: _active == 5,
                  onTap: _choosePhoto,
                  onClear: () => setState(() {
                    _photo = null;
                  }),
                ),
              ],
            ),

            if (vm.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(vm.error!, style: TextStyle(color: cs.error)),
              ),

            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: "Annuller",
                    color: cs.onPrimary,
                    borderStroke: Border.all(
                      color: cs.onSurface.withAlpha(100),
                      width: 0.6,
                    ),
                    elevation: 0,
                    borderRadius: 14,
                    textStyle: AppTypography.b2.copyWith(color: cs.onSurface),
                    onTap: vm.saving ? () {} : () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: "Tilføj service",
                    borderRadius: 14,
                    textStyle: AppTypography.b3,
                    onTap: vm.saving
                        ? () {}
                        : () async {
                            final created = await context
                                .read<ServiceViewModel>()
                                .addService(
                                  name: _nameCtrl.text,
                                  description: _descCtrl.text,
                                  duration: _durCtrl.text,
                                  price: _priceCtrl.text,
                                  image: _photo,
                                );

                            if (!mounted) return;

                            if (created) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Service tilføjet'),
                                ),
                              );
                              context.pop();
                            } else if (vm.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(vm.error!)),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
