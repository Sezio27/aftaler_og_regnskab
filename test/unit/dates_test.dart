import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateHelpers – simple unit tests', () {
    test('dateOnly zeros the time', () {
      final d = DateTime(2025, 10, 29, 12, 34, 56, 789);
      final only = dateOnly(d);
      expect(only, DateTime(2025, 10, 29));
    });

    test('endOfDayInclusive is 23:59:59.999', () {
      final e = endOfDayInclusive(DateTime(2025, 10, 29, 4, 5));
      expect(e, DateTime(2025, 10, 29, 23, 59, 59, 999));
    });

    test(
      'mondayOf returns same day for Monday, and the previous Monday otherwise',
      () {
        final mon = DateTime(2025, 10, 27); // Monday
        final wed = DateTime(2025, 10, 29); // Wednesday
        final sun = DateTime(2025, 11, 2); // Sunday

        expect(mondayOf(mon), DateTime(2025, 10, 27));
        expect(mondayOf(wed), DateTime(2025, 10, 27));
        expect(mondayOf(sun), DateTime(2025, 10, 27));
      },
    );

    test('start/end of month (incl leap year & December)', () {
      // Leap year February
      final febLeap = DateTime(2024, 2, 15);
      expect(startOfMonth(febLeap), DateTime(2024, 2, 1));
      expect(
        endOfMonthInclusive(febLeap),
        DateTime(2024, 2, 29, 23, 59, 59, 999),
      );

      // December boundary
      final dec = DateTime(2025, 12, 10);
      expect(startOfMonth(dec), DateTime(2025, 12, 1));
      expect(endOfMonthInclusive(dec), DateTime(2025, 12, 31, 23, 59, 59, 999));
    });

    test('weekRange spans Mon..Sun', () {
      final d = DateTime(2025, 10, 29); // Wed
      final r = weekRange(d);
      expect(r.start, DateTime(2025, 10, 27)); // Mon
      expect(r.end, DateTime(2025, 11, 2)); // Sun
    });

    test('monthRange and twoMonthRange', () {
      final d = DateTime(2025, 10, 15);
      final m = monthRange(d);
      expect(m.start, DateTime(2025, 10, 1));
      expect(m.end, DateTime(2025, 10, 31));

      final two = twoMonthRange(d);
      expect(two.start, DateTime(2025, 10, 1));
      expect(two.end, DateTime(2025, 11, 30));
    });

    test('addWeeks keeps Mondays aligned', () {
      final mon = DateTime(2025, 10, 27); // Monday
      expect(addWeeks(mon, 2), DateTime(2025, 11, 10));
      expect(addWeeks(mon, -1), DateTime(2025, 10, 20));
    });

    test('getMonth is first day of that month', () {
      final d = DateTime(2025, 3, 19, 23, 59);
      expect(getMonth(d), DateTime(2025, 3, 1));
    });

    test('addMonths handles -1, 0, +1 correctly', () {
      expect(addMonths(DateTime(2025, 3, 1), 0), DateTime(2025, 3, 1));
      expect(addMonths(DateTime(2025, 1, 1), -1), DateTime(2024, 12, 1));
      expect(addMonths(DateTime(2025, 12, 1), 1), DateTime(2026, 1, 1));
      // TIP: for larger deltas you can enhance addMonths; keep it simple for now.
    });

    group('ISO week utils', () {
      test('2020-12-31 is ISO week 53 of week-year 2020', () {
        final d = DateTime(2020, 12, 31);
        expect(isoWeekNumber(d), 53);
        expect(weekYear(d), 2020);
      });

      test('2021-01-01 is still ISO week 53 of 2020', () {
        final d = DateTime(2021, 1, 1);
        expect(isoWeekNumber(d), 53);
        expect(weekYear(d), 2020);
      });

      test('2019-12-31 is ISO week 1 of week-year 2020', () {
        final d = DateTime(2019, 12, 31);
        expect(isoWeekNumber(d), 1);
        expect(weekYear(d), 2020);
      });

      test('2025-01-01 is ISO week 1 of 2025', () {
        final d = DateTime(2025, 1, 1);
        expect(isoWeekNumber(d), 1);
        expect(weekYear(d), 2025);
      });
    });
  });
}
