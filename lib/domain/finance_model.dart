import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:flutter/material.dart';

@immutable
class FinanceModel {
  final int totalCount;
  final double paidSum;
  final Map<PaymentStatus, int> counts;

  FinanceModel({
    this.totalCount = 0,
    this.paidSum = 0.0,
    Map<PaymentStatus, int>? counts,
  }) : counts = {
         for (final status in PaymentStatus.values)
           if (status != PaymentStatus.all) status: counts?[status] ?? 0,
       };
}
