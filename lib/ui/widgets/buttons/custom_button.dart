import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  final double height;
  final double? width;
  final double borderRadius;
  final double elevation;

  final Color? color;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final TextStyle? textStyle;
  final BoxBorder? borderStroke;
  final bool loading;
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
    this.elevation = 0.5,
    this.loading = false,
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

    return Container(
      decoration: BoxDecoration(
        boxShadow: shadow,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        elevation: elevation,
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            height: height,
            width: width ?? double.infinity,
            decoration: BoxDecoration(
              gradient: gradient,
              color: bgColor,
              borderRadius: radius,
              border: borderStroke,
            ),
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[icon!, const SizedBox(width: 6)],
                      Flexible(
                        child: Text(
                          text,
                          style: labelStyle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
