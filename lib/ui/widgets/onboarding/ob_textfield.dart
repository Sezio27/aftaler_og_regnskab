import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:flutter/material.dart';

class ObTextfield extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final Iterable<String>? autofillHints;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const ObTextfield({
    super.key,
    required this.hintText,
    required this.controller,
    required this.autofillHints,
    this.onChanged,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: cs.onSurface, width: 1.5),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        cursorColor: cs.onSurface,
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 0,
          ),
          enabledBorder: underline,
          focusedBorder: underline,
          disabledBorder: underline,
          labelStyle: TextStyle(color: cs.onSurface),
          floatingLabelStyle: TextStyle(color: cs.onSurface),
        ),
        style: AppTypography.onSurface(context, AppTypography.b2),
        autofillHints: autofillHints,
      ),
    );
  }
}
