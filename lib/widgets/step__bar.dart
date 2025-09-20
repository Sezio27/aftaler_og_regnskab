import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

class StepBar extends StatelessWidget {
  final double value; // 0.0..1.0
  const StepBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 6,
          color: Colors.black12,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: AppGradients.peach3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
