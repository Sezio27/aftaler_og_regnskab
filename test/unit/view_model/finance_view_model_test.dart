import 'package:aftaler_og_regnskab/data/finance_summary_repository.dart';
import 'package:aftaler_og_regnskab/model/finance_model.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Mocks
/// ─────────────────────────────────────────────────────────────────────────────

class MockFinanceSummaryRepository extends Mock
    implements FinanceSummaryRepository {}

/// ─────────────────────────────────────────────────────────────────────────────
/// Helpers
/// ─────────────────────────────────────────────────────────────────────────────

FinanceModel fm({
  int total = 0,
  double sum = 0.0,
  Map<PaymentStatus, int>? counts,
}) => FinanceModel(
  totalCount: total,
  paidSum: sum,
  counts: counts ?? <PaymentStatus, int>{},
);

/// Pick dates relative to "now" so the "isInCurrentMonth/Year" helpers work.
class _Dates {
  final DateTime now;
  final DateTime sameMonth; // in current month
  final DateTime otherMonthSameYear; // different month, same year
  final DateTime lastYear; // same (safe) day/month, previous year

  _Dates()
    : now = DateTime.now(),
      sameMonth = DateTime.now(),
      otherMonthSameYear = _differentMonthSameYear(DateTime.now()),
      lastYear = _lastYearSameMonth(DateTime.now());

  static DateTime _differentMonthSameYear(DateTime n) {
    // Choose a different month but keep the same year (no wrap to next year).
    final int month = (n.month == 12) ? 11 : ((n.month == 1) ? 2 : n.month + 1);
    // Pick a safe day/time.
    return DateTime(n.year, month, 15, 12);
  }

  static DateTime _lastYearSameMonth(DateTime n) {
    // Safe day across months
    final day = n.day <= 28 ? n.day : 28;
    return DateTime(n.year - 1, n.month, day, 10);
  }
}

void main() {
  late MockFinanceSummaryRepository repo;
  late FinanceViewModel vm;
  late _Dates D;
  setUpAll(() {
    // Needed whenever we use any<PaymentStatus>() / captureAny on PaymentStatus
    registerFallbackValue(PaymentStatus.uninvoiced);

    // Needed if we use any<DateTime>() or any<DateTime?>()
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(DateTime(2000, 1, 1));
  });

  setUp(() {
    repo = MockFinanceSummaryRepository();
    vm = FinanceViewModel(repo);
    D = _Dates();
  });

  group('fetch & getters', () {
    test('fetchFinanceSegment updates model and notifies', () async {
      var notified = 0;
      vm.addListener(() => notified++);

      when(() => repo.fetchSummary(Segment.month)).thenAnswer(
        (_) async => fm(
          total: 3,
          sum: 1200.0,
          counts: {PaymentStatus.paid: 2, PaymentStatus.waiting: 1},
        ),
      );

      await vm.fetchFinanceSegment(Segment.month);

      expect(vm.summaryNow(Segment.month), (count: 3, income: 1200.0));
      final st = vm.statusNow(Segment.month);
      expect(st.paid, 2);
      expect(st.waiting, 1);
      expect(st.missing, 0);
      expect(st.uninvoiced, 0);
      expect(notified, 1);
    });

    test('ensureFinanceForHomeSeeded fetches month only', () async {
      when(
        () => repo.fetchSummary(Segment.month),
      ).thenAnswer((_) async => fm(total: 1, sum: 100.0));

      await vm.ensureFinanceForHomeSeeded();

      verify(() => repo.fetchSummary(Segment.month)).called(1);
      verifyNever(() => repo.fetchSummary(Segment.year));
      verifyNever(() => repo.fetchSummary(Segment.total));
      expect(vm.summaryNow(Segment.month), (count: 1, income: 100.0));
    });

    test('ensureFinanceTotalsSeeded fetches year and total', () async {
      when(
        () => repo.fetchSummary(Segment.year),
      ).thenAnswer((_) async => fm(total: 10, sum: 5000.0));
      when(
        () => repo.fetchSummary(Segment.total),
      ).thenAnswer((_) async => fm(total: 50, sum: 25000.0));

      await vm.ensureFinanceTotalsSeeded();

      verify(() => repo.fetchSummary(Segment.year)).called(1);
      verify(() => repo.fetchSummary(Segment.total)).called(1);

      expect(vm.summaryNow(Segment.year), (count: 10, income: 5000.0));
      expect(vm.summaryNow(Segment.total), (count: 50, income: 25000.0));
    });

    test('statusNow returns zeros when counts missing', () async {
      when(
        () => repo.fetchSummary(Segment.total),
      ).thenAnswer((_) async => fm(total: 0, sum: 0.0));
      await vm.fetchFinanceSegment(Segment.total);
      final st = vm.statusNow(Segment.total);
      expect(st.paid, 0);
      expect(st.waiting, 0);
      expect(st.missing, 0);
      expect(st.uninvoiced, 0);
    });
  });

  group('onAddAppointment', () {
    test('today + PAID updates month, year, and total; repo called', () async {
      var notified = 0;
      vm.addListener(() => notified++);

      when(
        () => repo.updateOnAdd(PaymentStatus.paid, 100.0, D.sameMonth),
      ).thenAnswer((_) async {});

      await vm.onAddAppointment(
        status: PaymentStatus.paid,
        price: 100.0,
        dateTime: D.sameMonth,
      );

      // All three segments increment
      for (final seg in Segment.values) {
        final s = vm.summaryNow(seg);
        expect(s.count, 1);
        expect(s.income, 100.0);
        final st = vm.statusNow(seg);
        expect(st.paid, 1);
        expect(st.waiting, 0);
        expect(st.missing, 0);
        expect(st.uninvoiced, 0);
      }

      verify(
        () => repo.updateOnAdd(PaymentStatus.paid, 100.0, D.sameMonth),
      ).called(1);
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('current year but other month: updates year & total only', () async {
      when(
        () =>
            repo.updateOnAdd(PaymentStatus.waiting, 50.0, D.otherMonthSameYear),
      ).thenAnswer((_) async {});

      await vm.onAddAppointment(
        status: PaymentStatus.waiting,
        price: 50.0,
        dateTime: D.otherMonthSameYear,
      );

      // Month should remain zero
      expect(vm.summaryNow(Segment.month), (count: 0, income: 0.0));
      // Year & Total increment count; income unaffected (waiting)
      for (final seg in [Segment.year, Segment.total]) {
        final s = vm.summaryNow(seg);
        expect(s.count, 1);
        expect(s.income, 0.0);
        final st = vm.statusNow(seg);
        expect(st.waiting, 1);
      }

      verify(
        () =>
            repo.updateOnAdd(PaymentStatus.waiting, 50.0, D.otherMonthSameYear),
      ).called(1);
    });

    test('previous year: updates total only', () async {
      when(
        () => repo.updateOnAdd(PaymentStatus.missing, 70.0, D.lastYear),
      ).thenAnswer((_) async {});

      await vm.onAddAppointment(
        status: PaymentStatus.missing,
        price: 70.0,
        dateTime: D.lastYear,
      );

      expect(vm.summaryNow(Segment.month), (count: 0, income: 0.0));
      expect(vm.summaryNow(Segment.year), (count: 0, income: 0.0));
      final total = vm.summaryNow(Segment.total);
      expect(total.count, 1);
      expect(total.income, 0.0);
      final st = vm.statusNow(Segment.total);
      expect(st.missing, 1);

      verify(
        () => repo.updateOnAdd(PaymentStatus.missing, 70.0, D.lastYear),
      ).called(1);
    });
  });

  group('onUpdateStatus', () {
    setUp(() async {
      // Seed some starting values so increments/decrements are visible.
      when(() => repo.fetchSummary(Segment.month)).thenAnswer(
        (_) async => fm(total: 1, sum: 0.0, counts: {PaymentStatus.waiting: 1}),
      );
      when(() => repo.fetchSummary(Segment.year)).thenAnswer(
        (_) async => fm(total: 1, sum: 0.0, counts: {PaymentStatus.waiting: 1}),
      );
      when(() => repo.fetchSummary(Segment.total)).thenAnswer(
        (_) async => fm(total: 1, sum: 0.0, counts: {PaymentStatus.waiting: 1}),
      );
      await vm.fetchFinanceSegment(Segment.month);
      await vm.fetchFinanceSegment(Segment.year);
      await vm.fetchFinanceSegment(Segment.total);
    });

    test('waiting -> paid (today): paidSum +price; counts swapped', () async {
      when(
        () => repo.updateOnStatusChange(
          PaymentStatus.waiting,
          PaymentStatus.paid,
          200.0,
          D.sameMonth,
        ),
      ).thenAnswer((_) async {});

      await vm.onUpdateStatus(
        oldStatus: PaymentStatus.waiting,
        newStatus: PaymentStatus.paid,
        price: 200.0,
        date: D.sameMonth,
      );

      for (final seg in Segment.values) {
        final s = vm.summaryNow(seg);
        expect(s.count, 1); // unchanged
        expect(s.income, 200.0); // added
        final st = vm.statusNow(seg);
        expect(st.paid, 1);
        expect(st.waiting, 0);
      }

      verify(
        () => repo.updateOnStatusChange(
          PaymentStatus.waiting,
          PaymentStatus.paid,
          200.0,
          D.sameMonth,
        ),
      ).called(1);
    });

    test('paid -> waiting (today): paidSum -price; counts swapped', () async {
      // Reseed as paid to make this meaningful
      when(() => repo.fetchSummary(Segment.month)).thenAnswer(
        (_) async => fm(total: 1, sum: 200.0, counts: {PaymentStatus.paid: 1}),
      );
      when(() => repo.fetchSummary(Segment.year)).thenAnswer(
        (_) async => fm(total: 1, sum: 200.0, counts: {PaymentStatus.paid: 1}),
      );
      when(() => repo.fetchSummary(Segment.total)).thenAnswer(
        (_) async => fm(total: 1, sum: 200.0, counts: {PaymentStatus.paid: 1}),
      );
      await vm.fetchFinanceSegment(Segment.month);
      await vm.fetchFinanceSegment(Segment.year);
      await vm.fetchFinanceSegment(Segment.total);

      when(
        () => repo.updateOnStatusChange(
          PaymentStatus.paid,
          PaymentStatus.waiting,
          200.0,
          D.sameMonth,
        ),
      ).thenAnswer((_) async {});

      await vm.onUpdateStatus(
        oldStatus: PaymentStatus.paid,
        newStatus: PaymentStatus.waiting,
        price: 200.0,
        date: D.sameMonth,
      );

      for (final seg in Segment.values) {
        final s = vm.summaryNow(seg);
        expect(s.count, 1);
        expect(s.income, 0.0);
        final st = vm.statusNow(seg);
        expect(st.paid, 0);
        expect(st.waiting, 1);
      }

      verify(
        () => repo.updateOnStatusChange(
          PaymentStatus.paid,
          PaymentStatus.waiting,
          200.0,
          D.sameMonth,
        ),
      ).called(1);
    });

    test(
      'paid -> paid (today): no net paidSum change; counts unchanged',
      () async {
        when(() => repo.fetchSummary(Segment.month)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 300.0, counts: {PaymentStatus.paid: 1}),
        );
        when(() => repo.fetchSummary(Segment.year)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 300.0, counts: {PaymentStatus.paid: 1}),
        );
        when(() => repo.fetchSummary(Segment.total)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 300.0, counts: {PaymentStatus.paid: 1}),
        );
        await vm.fetchFinanceSegment(Segment.month);
        await vm.fetchFinanceSegment(Segment.year);
        await vm.fetchFinanceSegment(Segment.total);

        when(
          () => repo.updateOnStatusChange(
            PaymentStatus.paid,
            PaymentStatus.paid,
            300.0,
            D.sameMonth,
          ),
        ).thenAnswer((_) async {});

        await vm.onUpdateStatus(
          oldStatus: PaymentStatus.paid,
          newStatus: PaymentStatus.paid,
          price: 300.0,
          date: D.sameMonth,
        );

        for (final seg in Segment.values) {
          final s = vm.summaryNow(seg);
          expect(s.income, 300.0); // +300 -300 = 0 change
          final st = vm.statusNow(seg);
          expect(st.paid, 1);
        }

        verify(
          () => repo.updateOnStatusChange(
            PaymentStatus.paid,
            PaymentStatus.paid,
            300.0,
            D.sameMonth,
          ),
        ).called(1);
      },
    );

    test(
      'current year but other month: month unchanged; year & total change',
      () async {
        // Start year=waiting:1; total=waiting:1; month unaffected
        when(
          () => repo.updateOnStatusChange(
            PaymentStatus.waiting,
            PaymentStatus.paid,
            50.0,
            D.otherMonthSameYear,
          ),
        ).thenAnswer((_) async {});

        await vm.onUpdateStatus(
          oldStatus: PaymentStatus.waiting,
          newStatus: PaymentStatus.paid,
          price: 50.0,
          date: D.otherMonthSameYear,
        );

        // Month unchanged
        expect(vm.statusNow(Segment.month).waiting, 1);
        expect(vm.summaryNow(Segment.month).income, 0.0);

        // Year & total updated
        for (final seg in [Segment.year, Segment.total]) {
          expect(vm.statusNow(seg).waiting, 0);
          expect(vm.statusNow(seg).paid, 1);
          expect(vm.summaryNow(seg).income, 50.0);
        }

        verify(
          () => repo.updateOnStatusChange(
            PaymentStatus.waiting,
            PaymentStatus.paid,
            50.0,
            D.otherMonthSameYear,
          ),
        ).called(1);
      },
    );
  });

  group('onUpdateAppointmentFields', () {
    test(
      'moved OUT of month (paid→paid), month-- and sum -oldPrice; year/total adjust delta',
      () async {
        // Seed: each seg has one paid item of 100
        when(() => repo.fetchSummary(Segment.month)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 100.0, counts: {PaymentStatus.paid: 1}),
        );
        when(() => repo.fetchSummary(Segment.year)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 100.0, counts: {PaymentStatus.paid: 1}),
        );
        when(() => repo.fetchSummary(Segment.total)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 100.0, counts: {PaymentStatus.paid: 1}),
        );
        await vm.fetchFinanceSegment(Segment.month);
        await vm.fetchFinanceSegment(Segment.year);
        await vm.fetchFinanceSegment(Segment.total);

        // Move from current month to next month (still same year),
        // keep status=paid but change price old=100 -> new=200
        when(
          () => repo.updateOnFields(
            PaymentStatus.paid,
            PaymentStatus.paid,
            100.0,
            200.0,
            D.sameMonth,
            DateTime(D.sameMonth.year, D.sameMonth.month + 1, 15, 12),
          ),
        ).thenAnswer((_) async {});

        final newDate = DateTime(
          D.sameMonth.year,
          D.sameMonth.month + 1,
          15,
          12,
        );

        await vm.onUpdateAppointmentFields(
          oldStatus: PaymentStatus.paid,
          newStatus: PaymentStatus.paid,
          oldPrice: 100.0,
          newPrice: 200.0,
          oldDate: D.sameMonth,
          newDate: newDate,
        );

        // Month: moved OUT → totalCount--, sum -= oldPrice (100), counts paid--
        expect(vm.summaryNow(Segment.month), (count: 0, income: 0.0));
        final mst = vm.statusNow(Segment.month);
        expect(mst.paid, 0);

        // Year: stayed within → sum += (new-old) = +100
        expect(vm.summaryNow(Segment.year), (count: 1, income: 200.0));
        expect(vm.statusNow(Segment.year).paid, 1);

        // Total: stayed within → same as year
        expect(vm.summaryNow(Segment.total), (count: 1, income: 200.0));
        expect(vm.statusNow(Segment.total).paid, 1);

        verify(
          () => repo.updateOnFields(
            PaymentStatus.paid,
            PaymentStatus.paid,
            100.0,
            200.0,
            D.sameMonth,
            newDate,
          ),
        ).called(1);
      },
    );

    test(
      'moved IN to month (waiting→paid), month++ and sum +newPrice; year/total stayed-within adjust',
      () async {
        // Seed: month is empty; year/total contain waiting:1 with sum 0
        when(
          () => repo.fetchSummary(Segment.month),
        ).thenAnswer((_) async => fm(total: 0, sum: 0.0, counts: {}));
        when(() => repo.fetchSummary(Segment.year)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 0.0, counts: {PaymentStatus.waiting: 1}),
        );
        when(() => repo.fetchSummary(Segment.total)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 0.0, counts: {PaymentStatus.waiting: 1}),
        );
        await vm.fetchFinanceSegment(Segment.month);
        await vm.fetchFinanceSegment(Segment.year);
        await vm.fetchFinanceSegment(Segment.total);

        final oldDate = DateTime(
          D.sameMonth.year,
          D.sameMonth.month == 1 ? 12 : D.sameMonth.month - 1,
          10,
          10,
        );
        when(
          () => repo.updateOnFields(
            PaymentStatus.waiting,
            PaymentStatus.paid,
            0.0,
            80.0,
            oldDate,
            D.sameMonth,
          ),
        ).thenAnswer((_) async {});

        await vm.onUpdateAppointmentFields(
          oldStatus: PaymentStatus.waiting,
          newStatus: PaymentStatus.paid,
          oldPrice: 0.0,
          newPrice: 80.0,
          oldDate: oldDate, // last month
          newDate: D.sameMonth, // now
        );

        // Month: moved IN → count++, paidSum += newPrice, counts[paid]++
        expect(vm.summaryNow(Segment.month), (count: 1, income: 80.0));
        expect(vm.statusNow(Segment.month).paid, 1);

        // Year: stayed within (same year) and waiting→paid → paidSum += newPrice, counts swap
        expect(vm.summaryNow(Segment.year), (count: 1, income: 80.0));
        final yst = vm.statusNow(Segment.year);
        expect(yst.waiting, 0);
        expect(yst.paid, 1);

        // Total: same as year
        expect(vm.summaryNow(Segment.total), (count: 1, income: 80.0));
        final tst = vm.statusNow(Segment.total);
        expect(tst.waiting, 0);
        expect(tst.paid, 1);

        verify(
          () => repo.updateOnFields(
            PaymentStatus.waiting,
            PaymentStatus.paid,
            0.0,
            80.0,
            oldDate,
            D.sameMonth,
          ),
        ).called(1);
      },
    );

    test(
      'stayed within (paid→paid) adjusts sum by delta, counts unchanged',
      () async {
        // Seed a paid item priced 100
        for (final seg in Segment.values) {
          when(() => repo.fetchSummary(seg)).thenAnswer(
            (_) async =>
                fm(total: 1, sum: 100.0, counts: {PaymentStatus.paid: 1}),
          );
        }
        await vm.fetchFinanceSegment(Segment.month);
        await vm.fetchFinanceSegment(Segment.year);
        await vm.fetchFinanceSegment(Segment.total);

        when(
          () => repo.updateOnFields(
            PaymentStatus.paid,
            PaymentStatus.paid,
            100.0,
            150.0,
            D.sameMonth,
            D.sameMonth,
          ),
        ).thenAnswer((_) async {});

        await vm.onUpdateAppointmentFields(
          oldStatus: PaymentStatus.paid,
          newStatus: PaymentStatus.paid,
          oldPrice: 100.0,
          newPrice: 150.0,
          oldDate: D.sameMonth,
          newDate: D.sameMonth,
        );

        // Sum += (150 - 100) = +50; counts unchanged
        for (final seg in Segment.values) {
          expect(vm.summaryNow(seg), (count: 1, income: 150.0));
          expect(vm.statusNow(seg).paid, 1);
        }

        verify(
          () => repo.updateOnFields(
            PaymentStatus.paid,
            PaymentStatus.paid,
            100.0,
            150.0,
            D.sameMonth,
            D.sameMonth,
          ),
        ).called(1);
      },
    );

    test(
      'stayed within (paid→waiting) subtracts oldPrice; counts swap',
      () async {
        for (final seg in Segment.values) {
          when(() => repo.fetchSummary(seg)).thenAnswer(
            (_) async =>
                fm(total: 1, sum: 200.0, counts: {PaymentStatus.paid: 1}),
          );
        }
        await vm.fetchFinanceSegment(Segment.month);
        await vm.fetchFinanceSegment(Segment.year);
        await vm.fetchFinanceSegment(Segment.total);

        when(
          () => repo.updateOnFields(
            PaymentStatus.paid,
            PaymentStatus.waiting,
            200.0,
            0.0,
            D.sameMonth,
            D.sameMonth,
          ),
        ).thenAnswer((_) async {});

        await vm.onUpdateAppointmentFields(
          oldStatus: PaymentStatus.paid,
          newStatus: PaymentStatus.waiting,
          oldPrice: 200.0,
          newPrice: 0.0,
          oldDate: D.sameMonth,
          newDate: D.sameMonth,
        );

        for (final seg in Segment.values) {
          expect(vm.summaryNow(seg), (count: 1, income: 0.0));
          final st = vm.statusNow(seg);
          expect(st.paid, 0);
          expect(st.waiting, 1);
        }

        verify(
          () => repo.updateOnFields(
            PaymentStatus.paid,
            PaymentStatus.waiting,
            200.0,
            0.0,
            D.sameMonth,
            D.sameMonth,
          ),
        ).called(1);
      },
    );

    test(
      'null dates: moved OUT if oldDate in seg and newDate=null; moved IN if oldDate=null and newDate in seg',
      () async {
        // Seed totals: one waiting in all segments
        for (final seg in Segment.values) {
          when(() => repo.fetchSummary(seg)).thenAnswer(
            (_) async =>
                fm(total: 1, sum: 0.0, counts: {PaymentStatus.waiting: 1}),
          );
        }
        await vm.fetchFinanceSegment(Segment.month);
        await vm.fetchFinanceSegment(Segment.year);
        await vm.fetchFinanceSegment(Segment.total);

        // Case A: oldDate in month/year; newDate = null => moved OUT of month/year; total always in
        when(
          () => repo.updateOnFields(
            PaymentStatus.waiting,
            PaymentStatus.waiting,
            0.0,
            0.0,
            D.sameMonth,
            null,
          ),
        ).thenAnswer((_) async {});

        await vm.onUpdateAppointmentFields(
          oldStatus: PaymentStatus.waiting,
          newStatus: PaymentStatus.waiting,
          oldPrice: 0.0,
          newPrice: 0.0,
          oldDate: D.sameMonth,
          newDate: null,
        );

        expect(vm.summaryNow(Segment.month).count, 0);
        expect(vm.summaryNow(Segment.year).count, 0);
        expect(vm.summaryNow(Segment.total).count, 1);

        // Case B: oldDate = null; newDate in month/year => moved IN
        when(
          () => repo.updateOnFields(
            PaymentStatus.waiting,
            PaymentStatus.paid,
            0.0,
            10.0,
            null,
            D.sameMonth,
          ),
        ).thenAnswer((_) async {});

        await vm.onUpdateAppointmentFields(
          oldStatus: PaymentStatus.waiting,
          newStatus: PaymentStatus.paid,
          oldPrice: 0.0,
          newPrice: 10.0,
          oldDate: null,
          newDate: D.sameMonth,
        );

        expect(vm.summaryNow(Segment.month).count, 1);
        expect(vm.summaryNow(Segment.year).count, 1);
        expect(vm.summaryNow(Segment.total).count, 1);
        expect(vm.summaryNow(Segment.month).income, 10.0);
        expect(vm.summaryNow(Segment.year).income, 10.0);
        expect(vm.summaryNow(Segment.total).income, 10.0);

        verify(
          () => repo.updateOnFields(
            PaymentStatus.waiting,
            PaymentStatus.waiting,
            0.0,
            0.0,
            D.sameMonth,
            null,
          ),
        ).called(1);
        verify(
          () => repo.updateOnFields(
            PaymentStatus.waiting,
            PaymentStatus.paid,
            0.0,
            10.0,
            null,
            D.sameMonth,
          ),
        ).called(1);
      },
    );
  });

  group('onDeleteAppointment', () {
    setUp(() async {
      // Seed: one paid item across all segments with price 100
      for (final seg in Segment.values) {
        when(() => repo.fetchSummary(seg)).thenAnswer(
          (_) async =>
              fm(total: 1, sum: 100.0, counts: {PaymentStatus.paid: 1}),
        );
      }
      await vm.fetchFinanceSegment(Segment.month);
      await vm.fetchFinanceSegment(Segment.year);
      await vm.fetchFinanceSegment(Segment.total);
      when(
        () => repo.updateOnDelete(any(), any(), any()),
      ).thenAnswer((_) async {});
    });

    test('today + paid: month/year/total decrement and paidSum -= price', () {
      var notified = 0;
      vm.addListener(() => notified++);

      // updateOnDelete is not awaited in the VM and may return void.
      // We just verify it is called.
      vm.onDeleteAppointment(
        status: PaymentStatus.paid,
        price: 100.0,
        date: D.sameMonth,
      );

      for (final seg in Segment.values) {
        final s = vm.summaryNow(seg);
        expect(s.count, 0);
        expect(s.income, 0.0);
        final st = vm.statusNow(seg);
        expect(st.paid, 0);
      }

      verify(
        () => repo.updateOnDelete(PaymentStatus.paid, 100.0, D.sameMonth),
      ).called(1);
      expect(notified, greaterThanOrEqualTo(1));
    });

    test(
      'current year but other month: year & total change; month unchanged',
      () {
        vm.onDeleteAppointment(
          status: PaymentStatus.paid,
          price: 100.0,
          date: D.otherMonthSameYear,
        );

        // Month still has the original
        expect(vm.summaryNow(Segment.month), (count: 1, income: 100.0));
        expect(vm.statusNow(Segment.month).paid, 1);

        // Year & total decremented
        for (final seg in [Segment.year, Segment.total]) {
          expect(vm.summaryNow(seg), (count: 0, income: 0.0));
          expect(vm.statusNow(seg).paid, 0);
        }

        verify(
          () => repo.updateOnDelete(
            PaymentStatus.paid,
            100.0,
            D.otherMonthSameYear,
          ),
        ).called(1);
      },
    );

    test('previous year: only total changes', () {
      vm.onDeleteAppointment(
        status: PaymentStatus.paid,
        price: 100.0,
        date: D.lastYear,
      );

      // Month & year unchanged
      expect(vm.summaryNow(Segment.month), (count: 1, income: 100.0));
      expect(vm.summaryNow(Segment.year), (count: 1, income: 100.0));

      // Total decremented
      expect(vm.summaryNow(Segment.total), (count: 0, income: 0.0));
      expect(vm.statusNow(Segment.total).paid, 0);

      verify(
        () => repo.updateOnDelete(PaymentStatus.paid, 100.0, D.lastYear),
      ).called(1);
    });
  });
}
