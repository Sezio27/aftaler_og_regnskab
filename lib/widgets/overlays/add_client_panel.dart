import 'dart:io';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/image_picker_helper.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class AddClientPanel extends StatefulWidget {
  const AddClientPanel({super.key});

  @override
  State<AddClientPanel> createState() => _AddClientPanelState();
}

class _AddClientPanelState extends State<AddClientPanel> {
  XFile? _photo;
  int? _active;
  final nameCtrl = TextEditingController();

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
              showStroke: _active == 0,
              onTap: () => setState(() => _active = 0),
            ),

            SoftTextField(
              title: 'Telefon',
              hintText: "+45xxxxxxxx",
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
              keyboardType: TextInputType.emailAddress,
              showStroke: _active == 2,
              onTap: () => setState(() => _active = 2),
            ),

            SoftTextField(
              title: 'Adresse',
              hintText: "Indtast adresse",
              showStroke: _active == 3,
              onTap: () => setState(() => _active = 3),
            ),

            SoftTextField(
              title: 'CVR',
              hintText: "Indtast CVR",
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
                        showStroke: _active == 5,
                        onTap: () => setState(() => _active = 5),
                      ),
                      SizedBox(height: 12),
                      SoftTextField(
                        title: 'Postnummer',
                        hintText: "Indtast postnummer",
                        keyboardType: TextInputType.number,
                        showStroke: _active == 6,
                        onTap: () => setState(() => _active = 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Photo picker circle
                _PhotoCircle(
                  image: _photo,
                  showStroke: _active == 7,
                  onTap: _choosePhoto,
                  onClear: () => setState(() {
                    _photo = null;
                  }),
                ),
              ],
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
                    text: "Tilføj klient",
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

/// Circular preview + "Tilføj billede" button
class _PhotoCircle extends StatelessWidget {
  const _PhotoCircle({
    required this.image,
    required this.onTap,
    required this.onClear,
    this.showStroke = false,
  });

  final XFile? image;
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
        child: Image.file(
          File(image!.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Stack(
      alignment: Alignment.topRight,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: border,
            ),
            child: inner,
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
