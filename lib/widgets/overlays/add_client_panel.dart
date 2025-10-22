import 'dart:typed_data';

import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/image_picker_helper.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/photo_circle.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AddClientPanel extends StatefulWidget {
  const AddClientPanel({super.key});

  @override
  State<AddClientPanel> createState() => _AddClientPanelState();
}

class _AddClientPanelState extends State<AddClientPanel> {
  ({Uint8List bytes, String name, String? mimeType})? _photo;
  int? _active;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _cvrCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    _cvrCtrl.dispose();
    super.dispose();
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  Future<void> _choosePhoto() async {
    _clearFocus();
    setState(() {
      _active = 7;
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
    final vm = context.watch<ClientViewModel>();

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
                      'Tilføj ny klient',
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
              title: 'Fulde navn',
              hintText: "F.eks. Sarah Johnson",
              controller: _nameCtrl,
              showStroke: _active == 0,
              onTap: () => setState(() => _active = 0),
            ),

            SoftTextField(
              title: 'Telefon',
              hintText: "+45xxxxxxxx",
              controller: _phoneCtrl,
              hintStyle: AppTypography.input2.copyWith(
                color: cs.onSurface.withAlpha(200),
              ),
              keyboardType: TextInputType.phone,
              showStroke: _active == 1,
              onTap: () => setState(() => _active = 1),
            ),

            SoftTextField(
              title: 'E-mail',
              hintText: "Indtast e-mail",
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              showStroke: _active == 2,
              onTap: () => setState(() => _active = 2),
            ),

            SoftTextField(
              title: 'Adresse',
              hintText: "Indtast adresse",
              controller: _addressCtrl,
              showStroke: _active == 3,
              onTap: () => setState(() => _active = 3),
            ),

            SoftTextField(
              title: 'CVR',
              hintText: "Indtast CVR",
              controller: _cvrCtrl,
              showStroke: _active == 4,
              keyboardType: TextInputType.number,
              onTap: () => setState(() => _active = 4),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fields
                Expanded(
                  child: Column(
                    children: [
                      SoftTextField(
                        title: 'By',
                        hintText: "Indtast by",
                        controller: _cityCtrl,
                        showStroke: _active == 5,
                        onTap: () => setState(() => _active = 5),
                      ),
                      SizedBox(height: 12),
                      SoftTextField(
                        title: 'Postnummer',
                        hintText: "Indtast postnummer",
                        controller: _postalCtrl,
                        keyboardType: TextInputType.number,
                        showStroke: _active == 6,
                        onTap: () => setState(() => _active = 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                PhotoCircle(
                  image: _photo,
                  showStroke: _active == 7,
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

            const SizedBox(height: 8),
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
                    text: vm.saving ? "Tilføjer..." : "Tilføj klient",
                    borderRadius: 14,
                    textStyle: AppTypography.b3,
                    onTap: vm.saving
                        ? () {}
                        : () async {
                            // Let the VM do the work
                            final created = await context
                                .read<ClientViewModel>()
                                .addClient(
                                  name: _nameCtrl.text,
                                  phone: _phoneCtrl.text,
                                  email: _emailCtrl.text,
                                  address: _addressCtrl.text,
                                  city: _cityCtrl.text,
                                  postal: _postalCtrl.text,
                                  cvr: _cvrCtrl.text,
                                  image: _photo,
                                );

                            if (!mounted) return;

                            if (created) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Klient tilføjet'),
                                ),
                              );
                              context.pop(); // close panel
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
