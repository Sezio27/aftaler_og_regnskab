import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:flutter/material.dart';

class SoftTextField extends StatelessWidget {
  const SoftTextField({
    super.key,
    this.title,
    this.controller,
    this.onTap,
    this.keyboardType,
    this.maxLines = 1,
    this.showStroke = false,
    this.strokeColor,
    this.strokeWidth = 1.5,
    this.hintText,
    this.hintStyle,
    this.borderRadius = 16,
    this.fill, this.suffixText, this.suffixStyle,
  });

  final String? title;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool showStroke;
  final Color? strokeColor;
  final double? strokeWidth;
  final String? hintText;
  final TextStyle? hintStyle;
  final double borderRadius;
  final Color? fill;
  final String? suffixText;  
  final TextStyle? suffixStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMultiline = maxLines > 1;

    final effectiveStroke = strokeColor ?? cs.primary;

    final borderSide = showStroke
        ? BorderSide(color: effectiveStroke, width: strokeWidth!)
        : BorderSide.none;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: borderSide,
    );

    final effectiveFill = fill ?? cs.surface;

    final effectiveHintStyle =
        hintStyle ??
        AppTypography.b4.copyWith(color: cs.onSurface.withAlpha(200));

    final field = TextField(
      controller: controller,
      onTap: onTap,
      keyboardType:
          keyboardType ??
          (isMultiline ? TextInputType.multiline : TextInputType.text),
      maxLines: maxLines,
      textAlignVertical: TextAlignVertical.top,
      style: AppTypography.input1.copyWith(color: cs.onSurface),
      textInputAction: isMultiline
          ? TextInputAction.newline
          : TextInputAction.done,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: effectiveHintStyle,
        filled: true,
        fillColor: effectiveFill,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isMultiline ? 20 : 10,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        suffixText: suffixText,                         
        suffixStyle: suffixStyle ??
            AppTypography.b4.copyWith(color: cs.onSurface.withAlpha(200)),
      ),
    );

    if (title == null || title!.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title!, style: AppTypography.b3.copyWith(color: cs.onSurface)),
        const SizedBox(height: 3),
        field,
      ],
    );
  }
}
