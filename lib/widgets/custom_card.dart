import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final double? width;
  final double? height;
  final double? shadowX;
  final double? shadowY;
  final Color? backgroundColor;
  final double? blurRadius;
  final Widget? field;
  final BoxConstraints? constraints;

  const CustomCard({
    super.key,
    this.width,
    this.height,
    this.shadowX = 0,
    this.shadowY = 1,
    this.backgroundColor = AppColors.shadowColor,
    this.blurRadius = 4,
    this.field,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: backgroundColor!,
            spreadRadius: 0,
            blurRadius: blurRadius!,
            offset: Offset(shadowX!, shadowY!), // changes position of shadow
          ),
        ],
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: field,
    );
  }
}
