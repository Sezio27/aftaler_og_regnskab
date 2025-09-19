import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  // layout
  final double height;
  final double? width;
  final double borderRadius;

  // style
  final Color? color; // solid fill
  final Gradient? gradient; // overrides color if set
  final List<BoxShadow>? shadow; // drop shadow (optional)
  final TextStyle? textStyle; // override label style

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
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null
                ? (color ?? Theme.of(context).colorScheme.primary)
                : null,
            borderRadius: radius,
            boxShadow: shadow,
          ),
          child: Center(
            child: Text(
              text,
              style:
                  (textStyle ??
                      Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.white)) ??
                  const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
