import 'package:flutter/material.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';

enum PaymentStatus { all, paid, waiting, missing, uninvoiced }

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.all => 'Alle',
    PaymentStatus.paid => 'Betalt',
    PaymentStatus.waiting => 'Afventer',
    PaymentStatus.missing => 'Forfalden',
    PaymentStatus.uninvoiced => 'Ufaktureret',
  };

  static PaymentStatus fromString(String? s) {
    switch ((s ?? '').trim().toLowerCase()) {
      case 'alle':
        return PaymentStatus.all;
      case 'betalt':
        return PaymentStatus.paid;
      case 'afventer':
        return PaymentStatus.waiting;
      case 'forfalden':
        return PaymentStatus.missing;
      case 'ufaktureret':
      case 'ikke faktureret':
        return PaymentStatus.uninvoiced;
      default:
        return PaymentStatus.uninvoiced;
    }
  }
}

IconData statusIcon(String s) {
  switch (s.trim().toLowerCase()) {
    case 'betalt':
      return Icons.check_circle_outlined;
    case 'afventer':
      return Icons.access_time;
    case 'forfalden':
      return Icons.error_outline;
    case 'ufaktureret':
    case 'ikke faktureret':
      return Icons.radio_button_unchecked;
    default:
      return Icons.radio_button_unchecked;
  }
}

// Simple color helpers (keep your old calls working)
Color statusColor(String? status) {
  switch ((status ?? '').trim().toLowerCase()) {
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
  switch ((status ?? '').trim().toLowerCase()) {
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
