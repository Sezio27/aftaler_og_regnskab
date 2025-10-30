// New file: lib/viewModel/finance_view_model.dart
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:flutter/material.dart';

enum Segment { month, year, total }

class FinanceViewModel extends ChangeNotifier {
  FinanceViewModel(this._repo);

  final AppointmentRepository _repo;

  final Map<Segment, FinanceTotals> _financeTotals = {
    Segment.month: FinanceTotals(),
    Segment.year: FinanceTotals(),
    Segment.total: FinanceTotals(),
  };

  bool _financeInitialised = false;
  bool _homeInitialised = false;

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
    final t = _financeTotals[seg]!;
    return (count: t.totalCount, income: t.paidSum);
  }

  ({int paid, int waiting, int missing, int uninvoiced}) statusNow(
    Segment seg,
  ) {
    final t = _financeTotals[seg]!;
    return (
      paid: t.getCount(PaymentStatus.paid),
      waiting: t.getCount(PaymentStatus.waiting),
      missing: t.getCount(PaymentStatus.missing),
      uninvoiced: t.getCount(PaymentStatus.uninvoiced),
    );
  }

  Future<({int count, double income})> getSummaryBySegment(Segment seg) async {
    final t = _financeTotals[seg]!;
    return (count: t.totalCount, income: t.paidSum);
  }

  Future<({int paid, int waiting, int missing, int uninvoiced})> statusCount(
    DateTime? start,
    DateTime? end,
  ) async {
    final futures = <Future<int>>[
      _repo.countAppointments(
        startInclusive: start,
        endInclusive: end,
        status: 'Betalt',
      ),
      _repo.countAppointments(
        startInclusive: start,
        endInclusive: end,
        status: 'Afventer',
      ),
      _repo.countAppointments(
        startInclusive: start,
        endInclusive: end,
        status: 'Forfalden',
      ),
      _repo.countAppointments(
        startInclusive: start,
        endInclusive: end,
        status: 'Ufaktureret',
      ),
    ];

    final r = await Future.wait<int>(futures);
    return (paid: r[0], waiting: r[1], missing: r[2], uninvoiced: r[3]);
  }

  // Home: month summary ONLY
  Future<void> ensureFinanceForHomeSeeded() async {
    if (_homeInitialised) return;
    await seedFinanceSegment(
      Segment.month,
      withStatusCounts: false,
      skipSummary: false,
    );
    _homeInitialised = true;
    notifyListeners();
  }

  // Finance: all segments + status
  Future<void> ensureFinanceTotalsSeeded() async {
    if (_financeInitialised) return;

    // Month: if Home already seeded summary, skip it here and only fetch status
    await seedFinanceSegment(
      Segment.month,
      withStatusCounts: true,
      skipSummary: _homeInitialised, // ← avoids re-reading month summary
    );

    await seedFinanceSegment(
      Segment.year,
      withStatusCounts: true,
      skipSummary: false,
    );
    await seedFinanceSegment(
      Segment.total,
      withStatusCounts: true,
      skipSummary: false,
    );

    _financeInitialised = true;
    notifyListeners();
  }

  Future<void> seedFinanceSegment(
    Segment seg, {
    required bool withStatusCounts,
    bool skipSummary = false, // when Home already seeded month summary
  }) async {
    final r = _rangeFor(seg);
    final totals = _financeTotals[seg]!;

    // Build only the futures we actually need
    final futures = <Future<dynamic>>[];

    if (!skipSummary) {
      futures.add(
        _repo.countAppointments(startInclusive: r.start, endInclusive: r.end),
      ); // index 0 (if present)

      futures.add(
        _repo.sumPaidInRange(startInclusive: r.start, endInclusive: r.end),
      ); // index 1 (if present)
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
      ); // last index (if present)
    }

    if (futures.isEmpty) return;

    final results = await Future.wait(futures);
    var i = 0;

    if (!skipSummary) {
      totals.totalCount = results[i++] as int;
      totals.paidSum = results[i++] as double;
    }

    if (withStatusCounts) {
      final buckets = results[i++] as List<int>;
      totals.counts[PaymentStatus.paid] = buckets[0];
      totals.counts[PaymentStatus.waiting] = buckets[1];
      totals.counts[PaymentStatus.missing] = buckets[2];
      totals.counts[PaymentStatus.uninvoiced] = buckets[3];
    }
  }

  // Update methods for CRUD operations (called from AppointmentViewModel)
  void onAddAppointment({
    required PaymentStatus status,
    required double price,
    required DateTime dateTime,
  }) {
    final p = price;
    final segments = <Segment>[Segment.total];
    if (isInCurrentYear(dateTime)) segments.add(Segment.year);
    if (isInCurrentMonth(dateTime)) segments.add(Segment.month);

    final isPaid = (status == PaymentStatus.paid);

    for (final seg in segments) {
      final t = _financeTotals[seg]!;
      if (_shouldUpdateSummary(seg)) {
        if (isPaid) t.paidSum += p;
        t.totalCount++;
      }
      if (_financeInitialised) t.inc(status);
    }
    notifyListeners();
  }

  void onUpdateStatus({
    required PaymentStatus oldStatus,
    required PaymentStatus newStatus,
    required double price,
    required DateTime date,
  }) {
    final p = price;
    final segments = <Segment>[Segment.total];
    if (isInCurrentYear(date)) segments.add(Segment.year);
    if (isInCurrentMonth(date)) segments.add(Segment.month);

    final wasPaid = (oldStatus == PaymentStatus.paid);
    final isPaid = (newStatus == PaymentStatus.paid);

    for (final seg in segments) {
      final t = _financeTotals[seg]!;
      if (_shouldUpdateSummary(seg)) {
        if (isPaid) t.paidSum += p;
        if (wasPaid) t.paidSum -= p;
      }
      if (_financeInitialised) {
        t.dec(oldStatus);
        t.inc(newStatus);
      }
    }
    notifyListeners();
  }

  void onUpdateAppointmentFields({
    required PaymentStatus oldStatus,
    required PaymentStatus newStatus,
    required double oldPrice,
    required double newPrice,
    required DateTime? oldDate,
    required DateTime? newDate,
  }) {
    bool inSeg(Segment seg, DateTime? dt) {
      if (seg == Segment.total) return true;
      if (dt == null) return false;
      return (seg == Segment.month)
          ? isInCurrentMonth(dt)
          : isInCurrentYear(dt);
    }

    final wasPaid = (oldStatus == PaymentStatus.paid);
    final isPaid = (newStatus == PaymentStatus.paid);

    for (final seg in Segment.values) {
      final t = _financeTotals[seg]!;
      final wasIn = inSeg(seg, oldDate);
      final isIn = inSeg(seg, newDate);

      // Case A: moved OUT of this segment
      if (wasIn && !isIn) {
        if (_shouldUpdateSummary(seg)) {
          t.totalCount--;
          if (wasPaid) t.paidSum -= oldPrice;
        }
        if (_financeInitialised) t.dec(oldStatus);
        continue;
      }

      // Case B: moved IN to this segment
      if (!wasIn && isIn) {
        if (_shouldUpdateSummary(seg)) {
          t.totalCount++;
          if (isPaid) t.paidSum += newPrice;
        }
        if (_financeInitialised) t.inc(newStatus);
        continue;
      }

      // Case C: stayed within this segment
      if (wasIn && isIn) {
        if (_shouldUpdateSummary(seg)) {
          if (wasPaid && isPaid) {
            t.paidSum += (newPrice - oldPrice);
          } else if (wasPaid && !isPaid) {
            t.paidSum -= oldPrice;
          } else if (!wasPaid && isPaid) {
            t.paidSum += newPrice;
          }
        }
        if (_financeInitialised && newStatus != oldStatus) {
          t.inc(newStatus);
          t.dec(oldStatus);
        }
      }
    }
    notifyListeners();
  }

  void onDeleteAppointment({
    required PaymentStatus status,
    required double price,
    required DateTime date,
  }) {
    final p = price;
    final segments = <Segment>[Segment.total];
    if (isInCurrentYear(date)) segments.add(Segment.year);
    if (isInCurrentMonth(date)) segments.add(Segment.month);

    final isPaid = (status == PaymentStatus.paid);

    for (final seg in segments) {
      final t = _financeTotals[seg]!;
      if (_shouldUpdateSummary(seg)) {
        if (isPaid) t.paidSum -= p;
        t.totalCount--;
      }
      if (_financeInitialised) t.dec(status);
    }
    notifyListeners();
  }

  bool _shouldUpdateSummary(Segment seg) =>
      seg == Segment.month || _financeInitialised;
}

class FinanceTotals {
  int totalCount; // all appointments in segment (any status)
  double paidSum; // sum(price) where status == 'Betalt'
  final Map<PaymentStatus, int> counts; // per-status counts (no 'all')

  FinanceTotals({
    this.totalCount = 0,
    this.paidSum = 0.0,
    Map<PaymentStatus, int>? counts,
  }) : counts = {
         for (final s in PaymentStatus.values)
           if (s != PaymentStatus.all) s: counts?[s] ?? 0,
       };

  int getCount(PaymentStatus s) =>
      s == PaymentStatus.all ? totalCount : (counts[s] ?? 0);
  void inc(PaymentStatus s) {
    if (s != PaymentStatus.all) counts[s] = (counts[s] ?? 0) + 1;
  }

  void dec(PaymentStatus s) {
    if (s != PaymentStatus.all) counts[s] = (counts[s] ?? 0) - 1;
  }
}

@visibleForTesting
void vmTestResetFinance(FinanceViewModel vm) {
  vm._financeTotals[Segment.month] = FinanceTotals();
  vm._financeTotals[Segment.year] = FinanceTotals();
  vm._financeTotals[Segment.total] = FinanceTotals();
  vm._financeInitialised = false;
  vm._homeInitialised = false;
}
