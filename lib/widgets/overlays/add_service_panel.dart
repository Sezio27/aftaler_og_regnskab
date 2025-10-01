import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/image_picker_helper.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/photo_circle.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class AddServicePanel extends StatefulWidget {
  const AddServicePanel({super.key});

  @override
  State<AddServicePanel> createState() => _AddServicePanelState();
}

class _AddServicePanelState extends State<AddServicePanel> {
  int? _active;
  XFile? _photo;
  final nameCtrl = TextEditingController();

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
              showStroke: _active == 0,
              onTap: () => setState(() => _active = 0),
            ),
            const SizedBox(height: 4),
            SoftTextField(
              title: 'Beskrivelse',
              hintText: "Kort beskrivelse af servicen...",
              keyboardType: TextInputType.phone,
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
                        onTap: () => setState(() => _active = 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Photo picker circle
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
                    onTap: () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: "Tilføj service",
                    borderRadius: 14,
                    textStyle: AppTypography.b3,
                    onTap: () => context.pop(),
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
