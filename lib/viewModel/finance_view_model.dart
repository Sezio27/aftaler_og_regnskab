import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/finance_summary_repository.dart';
import 'package:aftaler_og_regnskab/model/finance_model.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:flutter/material.dart';

enum Segment { month, year, total }

class FinanceViewModel extends ChangeNotifier {
  FinanceViewModel(this._repo, this._summaryRepo);

  final AppointmentRepository _repo;
  final FinanceSummaryRepository _summaryRepo;

  // Use FinanceModel instead of FinanceTotals
  final Map<Segment, FinanceModel> _financeModels = {
    Segment.month: FinanceModel(),
    Segment.year: FinanceModel(),
    Segment.total: FinanceModel(),
  };

  bool _financeInitialised = false;
  bool _homeInitialised = false;

  Future<void> refreshFinanceSegment(Segment seg) async {
    final summary = await _summaryRepo.fetchSummary(seg);
    _financeModels[seg] = FinanceModel(
      totalCount: summary.totalCount,
      paidSum: summary.paidSum,
      counts: Map<PaymentStatus, int>.from(summary.counts),
    );
    notifyListeners();
  }

  ({DateTime? start, DateTime? end}) _rangeFor(Segment s) {
    final now = DateTime.now();
    switch (s) {
      case Segment.month:
        return (start: startOfMonth(now), end: endOfMonthInclusive(now));
      case Segment.year:
        return (start: startOfYear(now), end: endOfYearInclusive(now));
      case Segment.total:
        return (start: null, end: null);
    }
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

  Future<({int count, double income})> getSummaryBySegment(Segment seg) async {
    final m = _financeModels[seg]!;
    return (count: m.totalCount, income: m.paidSum);
  }

  Future<({int paid, int waiting, int missing, int uninvoiced})> statusCount(
    DateTime? start,
    DateTime? end,
  ) async {
    // Decide which summary to read based on the range.
    // For simplicity, assume null range => total, month range => month, etc.
    final Segment seg = (start == null && end == null)
        ? Segment.total
        : (start?.year == end?.year && start?.month == end?.month)
        ? Segment.month
        : Segment.year;

    final summary = await _summaryRepo.fetchSummary(seg);
    return (
      paid: summary.counts[PaymentStatus.paid] ?? 0,
      waiting: summary.counts[PaymentStatus.waiting] ?? 0,
      missing: summary.counts[PaymentStatus.missing] ?? 0,
      uninvoiced: summary.counts[PaymentStatus.uninvoiced] ?? 0,
    );
  }

  Future<void> ensureFinanceForHomeSeeded() async {
    if (_homeInitialised) return;
    // Only load the precomputed summary for the month segment
    await refreshFinanceSegment(Segment.month);
    _homeInitialised = true;
  }

  Future<void> ensureFinanceTotalsSeeded() async {
    if (_financeInitialised) return;
    // Refresh all segments once; no fallback counting
    await refreshFinanceSegment(Segment.month);
    await refreshFinanceSegment(Segment.year);
    await refreshFinanceSegment(Segment.total);
    _financeInitialised = true;
  }

  Future<void> seedFinanceSegment(
    Segment seg, {
    required bool withStatusCounts,
    bool skipSummary = false,
  }) async {
    // Load precomputed summary from Firestore
    final docTotals = await _summaryRepo.fetchSummary(
      seg,
    ); // returns FinanceModel
    var newCounts = Map<PaymentStatus, int>.from(docTotals.counts);
    var newTotalCount = docTotals.totalCount;
    var newPaidSum = docTotals.paidSum;

    final r = _rangeFor(seg);
    final futures = <Future<dynamic>>[];

    // Build fallback queries if summary is missing or needs refreshing
    if (!skipSummary) {
      futures.add(
        _repo.countAppointments(startInclusive: r.start, endInclusive: r.end),
      );
      futures.add(
        _repo.sumPaidInRange(startInclusive: r.start, endInclusive: r.end),
      );
    }

    if (withStatusCounts) {
      futures.add(
        Future.wait<int>([
          _repo.countAppointments(
            startInclusive: r.start,
            endInclusive: r.end,
            status: PaymentStatus.paid.label,
          ),
          _repo.countAppointments(
            startInclusive: r.start,
            endInclusive: r.end,
            status: PaymentStatus.waiting.label,
          ),
          _repo.countAppointments(
            startInclusive: r.start,
            endInclusive: r.end,
            status: PaymentStatus.missing.label,
          ),
          _repo.countAppointments(
            startInclusive: r.start,
            endInclusive: r.end,
            status: PaymentStatus.uninvoiced.label,
          ),
        ]),
      );
    }

    if (futures.isNotEmpty) {
      final results = await Future.wait(futures);
      var i = 0;
      if (!skipSummary) {
        newTotalCount = results[i++] as int;
        newPaidSum = results[i++] as double;
      }
      if (withStatusCounts) {
        final buckets = results[i++] as List<int>;
        newCounts[PaymentStatus.paid] = buckets[0];
        newCounts[PaymentStatus.waiting] = buckets[1];
        newCounts[PaymentStatus.missing] = buckets[2];
        newCounts[PaymentStatus.uninvoiced] = buckets[3];
      }
    }

    // Save into map
    _financeModels[seg] = FinanceModel(
      totalCount: newTotalCount,
      paidSum: newPaidSum,
      counts: newCounts,
    );
  }

  // Update methods for CRUD operations (called from AppointmentViewModel)

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

      if (_shouldUpdateSummary(seg)) {
        if (status == PaymentStatus.paid) {
          paidSum += price;
        }
        totalCount++;
      }
      if (_financeInitialised) {
        counts[status] = (counts[status] ?? 0) + 1;
      }

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

      if (_shouldUpdateSummary(seg)) {
        if (newStatus == PaymentStatus.paid) {
          paidSum += price;
        }
        if (oldStatus == PaymentStatus.paid) {
          paidSum -= price;
        }
      }
      if (_financeInitialised) {
        counts[oldStatus] = (counts[oldStatus] ?? 0) - 1;
        counts[newStatus] = (counts[newStatus] ?? 0) + 1;
      }

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
        // moved OUT of this segment
        if (_shouldUpdateSummary(seg)) {
          totalCount--;
          if (wasPaid) paidSum -= oldPrice;
        }
        if (_financeInitialised) {
          counts[oldStatus] = (counts[oldStatus] ?? 0) - 1;
        }
      } else if (!wasIn && isIn) {
        // moved IN to this segment
        if (_shouldUpdateSummary(seg)) {
          totalCount++;
          if (isPaid) paidSum += newPrice;
        }
        if (_financeInitialised) {
          counts[newStatus] = (counts[newStatus] ?? 0) + 1;
        }
      } else if (wasIn && isIn) {
        // stayed within this segment
        if (_shouldUpdateSummary(seg)) {
          if (wasPaid && isPaid) {
            paidSum += (newPrice - oldPrice);
          } else if (wasPaid && !isPaid) {
            paidSum -= oldPrice;
          } else if (!wasPaid && isPaid) {
            paidSum += newPrice;
          }
        }
        if (_financeInitialised && newStatus != oldStatus) {
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

      if (_shouldUpdateSummary(seg)) {
        if (status == PaymentStatus.paid) {
          paidSum -= price;
        }
        totalCount--;
      }
      if (_financeInitialised) {
        counts[status] = (counts[status] ?? 0) - 1;
      }

      _financeModels[seg] = FinanceModel(
        totalCount: totalCount,
        paidSum: paidSum,
        counts: counts,
      );
    }
    notifyListeners();
  }

  bool _shouldUpdateSummary(Segment seg) =>
      seg == Segment.month || _financeInitialised;
}
