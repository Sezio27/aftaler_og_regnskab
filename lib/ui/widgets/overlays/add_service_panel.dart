import 'dart:typed_data';

import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/buttons/action_buttons.dart';
import 'package:aftaler_og_regnskab/ui/widgets/pickers/image/image_picker_helper.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/photo_circle.dart';
import 'package:aftaler_og_regnskab/ui/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> _createService(ServiceViewModel vm) async {
    FocusScope.of(context).unfocus();

    final priceText = _priceCtrl.text.trim();
    final priceValue = parsePrice(priceText);

    if (priceText.isNotEmpty && priceValue == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Angiv en gyldig pris')));
      return;
    }

    final created = await vm.addService(
      name: _nameCtrl.text,
      description: _descCtrl.text,
      duration: _durCtrl.text,
      price: priceValue,
      image: _photo,
    );

    if (!mounted) return;

    if (created) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service tilføjet')));
      context.pop();
    } else if (vm.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(vm.error!)));
    }
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text('Tilføj ny service', style: AppTypography.b1),
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
            AddActionRow(
              name: 'service',
              saving: vm.saving,
              onCancel: vm.saving ? () {} : () => context.pop(),
              onConfirm: vm.saving ? () {} : () => _createService(vm),
            ),
          ],
        ),
      ),
    );
  }
}
