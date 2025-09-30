import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddServicePanel extends StatefulWidget {
  const AddServicePanel({super.key});

  @override
  State<AddServicePanel> createState() => _AddServicePanelState();
}

class _AddServicePanelState extends State<AddServicePanel> {
  int? _active;
  final nameCtrl = TextEditingController();

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
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

            SoftTextField(
              title: 'Beskrivelse',
              hintText: "Kort beskrivelse af servicen...",
              keyboardType: TextInputType.phone,
              maxLines: 5,
              showStroke: _active == 1,
              onTap: () => setState(() => _active = 1),
            ),

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
