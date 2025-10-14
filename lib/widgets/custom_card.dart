import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final double? width;
  final double? height;
  final double? shadowX;
  final double? shadowY;
  final Color? shadowColor;
  final BlurStyle? blurStyle;
  final double? blurRadius;
  final Widget? field;
  final BoxConstraints? constraints;

  const CustomCard({
    super.key,
    this.width,
    this.height,
    this.shadowX = 0,
    this.shadowY = 1,
    this.shadowColor = AppColors.shadowColor,
    this.blurRadius = 4,
    this.field,
    this.constraints,
    this.blurStyle = BlurStyle.normal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: shadowColor!,
            spreadRadius: 0,
            blurRadius: blurRadius!,
            offset: Offset(shadowX!, shadowY!),
            blurStyle: blurStyle!,
          ),
        ],
        color: cs.onPrimary,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: field,
    );
  }
}
