import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  final double height;
  final double? width;
  final double borderRadius;

  final Color? color;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final TextStyle? textStyle;
  final BoxBorder? borderStroke;

  final Widget? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onTap,
    this.height = 52,
    this.width,
    this.borderRadius = 28,
    this.color,
    this.gradient,
    this.shadow,
    this.textStyle,
    this.icon,
    this.borderStroke,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(borderRadius);

    final bgColor = gradient == null ? (color ?? cs.primary) : null;

    final labelStyle =
        (textStyle ?? tt.labelLarge)?.copyWith(
          color: (textStyle?.color) ?? cs.onPrimary,
        ) ??
        TextStyle(color: cs.onPrimary);

    return Material(
      elevation: 1,
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            gradient: gradient,
            color: bgColor,
            borderRadius: radius,
            boxShadow: shadow,
            border: borderStroke,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 6)],
              Text(text, style: labelStyle, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
