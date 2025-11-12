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

  factory FinanceModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return FinanceModel();
    final countMap = data['counts'] as Map<String, dynamic>? ?? {};
    return FinanceModel(
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      paidSum: (data['paidSum'] as num?)?.toDouble() ?? 0.0,
      counts: {
        for (final status in PaymentStatus.values)
          if (status != PaymentStatus.all)
            status: (countMap[status.label] as num?)?.toInt() ?? 0,
      },
    );
  }

  Map<String, dynamic> toMap() => {
    'totalCount': totalCount,
    'paidSum': paidSum,
    'counts': {for (final status in counts.keys) status.label: counts[status]},
  };
}
