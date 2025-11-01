import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final double? width;
  final double? height;

  final Widget? field;
  final BoxConstraints? constraints;
  final Color? color;
  final double? elevation;
  final List<BoxShadow>? shadow;

  const CustomCard({
    super.key,
    this.width,
    this.height,

    this.field,
    this.constraints,

    this.color,
    this.elevation = 1,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        boxShadow: shadow,
        color: color ?? cs.onPrimary,

        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Material(
        elevation: elevation!,
        clipBehavior: Clip.antiAlias,
        color: color ?? cs.onPrimary,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        child: field,
      ),
    );
  }
}
