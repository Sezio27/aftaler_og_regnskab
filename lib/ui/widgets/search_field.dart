import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.placeholder = 'Søg',
    this.onChanged,
    this.onSubmitted,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    this.borderRadius = 10,
    this.backgroundColor,
    this.itemColor,
    this.textStyle,
    this.placeholderStyle,
    this.showBorder = true,
    required this.ctx,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final EdgeInsets padding;
  final double borderRadius;

  final Color? backgroundColor;
  final Color? itemColor;

  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final bool showBorder;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoSearchTextField(
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
      onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
      itemColor: itemColor ?? cs.onSurface.withAlpha(180),
      style: (textStyle ?? AppTypography.b2).copyWith(color: cs.onSurface),
      placeholderStyle: (placeholderStyle ?? AppTypography.b2).copyWith(
        color: cs.onSurface.withAlpha(180),
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surface,
        border: (isDark || !showBorder)
            ? null
            : Border.all(color: cs.onSurface, width: 0.4),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
      ),
    );
  }
}
