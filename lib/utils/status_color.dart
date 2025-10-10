import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:flutter/material.dart';

/// Solid tone (icons, borders, text accents).
Color statusColor(String? status) {
  switch ((status ?? '').toLowerCase().trim()) {
    case 'betalt':
      return AppColors.greenMain;
    case 'afventer':
      return AppColors.orangeMain;
    case 'forfalden':
      return AppColors.redMain;
    case 'ufaktureret':
      return AppColors.greyMain;
    default:
      return AppColors.greyMain;
  }
}

Color statusBackground(String? status) {
  switch ((status ?? '').toLowerCase().trim()) {
    case 'betalt':
      return AppColors.greenBackground;
    case 'afventer':
      return AppColors.orangeBackground;
    case 'forfalden':
      return AppColors.redBackground;
    case 'ufaktureret':
      return AppColors.greyBackground;
    default:
      return AppColors.greyBackground;
  }
}
