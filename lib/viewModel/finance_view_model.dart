import 'package:aftaler_og_regnskab/data/repositories/finance_summary_repository.dart';
import 'package:aftaler_og_regnskab/domain/finance_model.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:flutter/material.dart';

enum Segment { month, year, total }

class FinanceViewModel extends ChangeNotifier {
  FinanceViewModel(this._summaryRepo);

  final FinanceSummaryRepository _summaryRepo;

  final Map<Segment, FinanceModel> _financeModels = {
    Segment.month: FinanceModel(),
    Segment.year: FinanceModel(),
    Segment.total: FinanceModel(),
  };

  Future<void> fetchFinanceSegment(Segment seg) async {
    final summary = await _summaryRepo.fetchSummary(seg);
    _financeModels[seg] = FinanceModel(
      totalCount: summary.totalCount,
      paidSum: summary.paidSum,
      counts: Map<PaymentStatus, int>.from(summary.counts),
    );
    notifyListeners();
  }

  ({int count, double income}) summaryNow(Segment seg) {
    final m = _financeModels[seg]!;
    return (count: m.totalCount, income: m.paidSum);
  }

  ({int paid, int waiting, int missing, int uninvoiced}) statusNow(
    Segment seg,
  ) {
    final m = _financeModels[seg]!;
    return (
      paid: m.counts[PaymentStatus.paid] ?? 0,
      waiting: m.counts[PaymentStatus.waiting] ?? 0,
      missing: m.counts[PaymentStatus.missing] ?? 0,
      uninvoiced: m.counts[PaymentStatus.uninvoiced] ?? 0,
    );
  }

  Future<void> ensureFinanceForHomeSeeded() async {
    await fetchFinanceSegment(Segment.month);
  }

  Future<void> ensureFinanceTotalsSeeded() async {
    await fetchFinanceSegment(Segment.year);
    await fetchFinanceSegment(Segment.total);
  }

  Future<void> onAddAppointment({
    required PaymentStatus status,
    required double price,
    required DateTime dateTime,
  }) async {
    final segments = <Segment>[Segment.total];
    if (isInCurrentYear(dateTime)) segments.add(Segment.year);
    if (isInCurrentMonth(dateTime)) segments.add(Segment.month);

    for (final seg in segments) {
      final current = _financeModels[seg]!;
      var counts = Map<PaymentStatus, int>.from(current.counts);
      var totalCount = current.totalCount;
      var paidSum = current.paidSum;

      if (status == PaymentStatus.paid) {
        paidSum += price;
      }
      totalCount++;

      counts[status] = (counts[status] ?? 0) + 1;

      _financeModels[seg] = FinanceModel(
        totalCount: totalCount,
        paidSum: paidSum,
        counts: counts,
      );
    }
    await _summaryRepo.updateOnAdd(status, price, dateTime);
    notifyListeners();
  }

  Future<void> onUpdateStatus({
    required PaymentStatus oldStatus,
    required PaymentStatus newStatus,
    required double price,
    required DateTime date,
  }) async {
    final segments = <Segment>[Segment.total];
    if (isInCurrentYear(date)) segments.add(Segment.year);
    if (isInCurrentMonth(date)) segments.add(Segment.month);

    for (final seg in segments) {
      final current = _financeModels[seg]!;
      var counts = Map<PaymentStatus, int>.from(current.counts);
      var paidSum = current.paidSum;

      if (newStatus == PaymentStatus.paid) {
        paidSum += price;
      }
      if (oldStatus == PaymentStatus.paid) {
        paidSum -= price;
      }

      counts[oldStatus] = (counts[oldStatus] ?? 0) - 1;
      counts[newStatus] = (counts[newStatus] ?? 0) + 1;

      _financeModels[seg] = FinanceModel(
        totalCount: current.totalCount,
        paidSum: paidSum,
        counts: counts,
      );
    }
    await _summaryRepo.updateOnStatusChange(oldStatus, newStatus, price, date);
    notifyListeners();
  }

  Future<void> onUpdateAppointmentFields({
    required PaymentStatus oldStatus,
    required PaymentStatus newStatus,
    required double oldPrice,
    required double newPrice,
    required DateTime? oldDate,
    required DateTime? newDate,
  }) async {
    bool inSeg(Segment seg, DateTime? dt) {
      if (seg == Segment.total) return true;
      if (dt == null) return false;
      return seg == Segment.month ? isInCurrentMonth(dt) : isInCurrentYear(dt);
    }

    final wasPaid = oldStatus == PaymentStatus.paid;
    final isPaid = newStatus == PaymentStatus.paid;

    for (final seg in Segment.values) {
      final current = _financeModels[seg]!;
      var counts = Map<PaymentStatus, int>.from(current.counts);
      var totalCount = current.totalCount;
      var paidSum = current.paidSum;

      final wasIn = inSeg(seg, oldDate);
      final isIn = inSeg(seg, newDate);

      if (wasIn && !isIn) {
        totalCount--;
        if (wasPaid) paidSum -= oldPrice;

        counts[oldStatus] = (counts[oldStatus] ?? 0) - 1;
      } else if (!wasIn && isIn) {
        totalCount++;
        if (isPaid) paidSum += newPrice;

        counts[newStatus] = (counts[newStatus] ?? 0) + 1;
      } else if (wasIn && isIn) {
        if (wasPaid && isPaid) {
          paidSum += (newPrice - oldPrice);
        } else if (wasPaid && !isPaid) {
          paidSum -= oldPrice;
        } else if (!wasPaid && isPaid) {
          paidSum += newPrice;
        }

        if (newStatus != oldStatus) {
          counts[newStatus] = (counts[newStatus] ?? 0) + 1;
          counts[oldStatus] = (counts[oldStatus] ?? 0) - 1;
        }
      }

      _financeModels[seg] = FinanceModel(
        totalCount: totalCount,
        paidSum: paidSum,
        counts: counts,
      );
    }

    await _summaryRepo.updateOnFields(
      oldStatus,
      newStatus,
      oldPrice,
      newPrice,
      oldDate,
      newDate,
    );
    notifyListeners();
  }

  void onDeleteAppointment({
    required PaymentStatus status,
    required double price,
    required DateTime date,
  }) {
    final segments = <Segment>[Segment.total];
    if (isInCurrentYear(date)) segments.add(Segment.year);
    if (isInCurrentMonth(date)) segments.add(Segment.month);

    for (final seg in segments) {
      final current = _financeModels[seg]!;
      var counts = Map<PaymentStatus, int>.from(current.counts);
      var totalCount = current.totalCount;
      var paidSum = current.paidSum;

      if (status == PaymentStatus.paid) {
        paidSum -= price;
      }
      totalCount--;

      counts[status] = (counts[status] ?? 0) - 1;

      _financeModels[seg] = FinanceModel(
        totalCount: totalCount,
        paidSum: paidSum,
        counts: counts,
      );
    }

    _summaryRepo.updateOnDelete(status, price, date);
    notifyListeners();
  }
}
