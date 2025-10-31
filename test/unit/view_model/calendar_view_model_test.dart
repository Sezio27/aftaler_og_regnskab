import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('da');
  });

  group('initialization', () {
    test('respects provided initial date for visibleMonth and visibleWeek', () {
      final initial = DateTime(2025, 1, 15, 12, 34);
      final vm = CalendarViewModel(initial: initial);

      expect(vm.visibleMonth, getMonth(initial));
      expect(vm.visibleWeek, getWeek(initial));

      // selectedDay is *now* (by design), not derived from initial
      final now = DateTime.now();
      expect(vm.selectedDay.year, now.year);
      expect(vm.selectedDay.month, now.month);
      expect(vm.selectedDay.day, now.day);
    });
  });

  group('selectDay', () {
    test('normalizes to Y-M-D, updates visibleWeek, and notifies once', () {
      final vm = CalendarViewModel(initial: DateTime(2025, 2, 1));
      var ticks = 0;
      vm.addListener(() => ticks++);

      final raw = DateTime(
        2025,
        2,
        10,
        14,
        33,
        44,
        555,
      ); // Monday-week candidate
      final normalized = DateTime(2025, 2, 10);
      vm.selectDay(raw);

      expect(vm.selectedDay, normalized);
      expect(vm.visibleWeek, getWeek(normalized));
      expect(ticks, 1);

      // Selecting the same day is a no-op (no notify)
      vm.selectDay(DateTime(2025, 2, 10, 23, 59));
      expect(ticks, 1);
    });
  });

  group('month navigation', () {
    test('prevMonth and nextMonth move by one month and notify', () {
      final initial = DateTime(2025, 6, 15);
      final vm = CalendarViewModel(initial: initial);
      expect(vm.visibleMonth, getMonth(initial));

      var ticks = 0;
      vm.addListener(() => ticks++);

      vm.prevMonth();
      expect(vm.visibleMonth, addMonths(getMonth(initial), -1));
      expect(ticks, 1);

      vm.nextMonth();
      expect(vm.visibleMonth, getMonth(initial)); // back to start
      expect(ticks, 2);

      vm.nextMonth();
      expect(vm.visibleMonth, addMonths(getMonth(initial), 1));
      expect(ticks, 3);
    });

    test('jumpToCurrentMonth sets month to current', () {
      final vm = CalendarViewModel(initial: DateTime(1990, 1, 10));
      var ticks = 0;
      vm.addListener(() => ticks++);

      vm.jumpToCurrentMonth();
      expect(vm.visibleMonth, getMonth(DateTime.now()));
      expect(ticks, 1);
    });
  });

  group('week navigation', () {
    test(
      'prevWeek and nextWeek move by one week, set selectedDay to Monday, and notify',
      () {
        final initial = DateTime(2025, 1, 7); // Tue
        final vm = CalendarViewModel(initial: initial);
        final startWeek = getWeek(initial);
        expect(vm.visibleWeek, startWeek);

        var ticks = 0;
        vm.addListener(() => ticks++);

        vm.prevWeek();
        final prev = addWeeks(startWeek, -1);
        expect(vm.visibleWeek, prev);
        expect(vm.selectedDay, prev); // selected becomes Monday
        expect(ticks, 1);

        vm.nextWeek();
        expect(vm.visibleWeek, startWeek);
        expect(vm.selectedDay, startWeek);
        expect(ticks, 2);

        vm.nextWeek();
        final next = addWeeks(startWeek, 1);
        expect(vm.visibleWeek, next);
        expect(vm.selectedDay, next);
        expect(ticks, 3);
      },
    );

    test(
      'jumpToCurrentWeek sets visibleWeek to current and selectedDay to today',
      () {
        final vm = CalendarViewModel(initial: DateTime(2010, 3, 3));
        var ticks = 0;
        vm.addListener(() => ticks++);

        vm.jumpToCurrentWeek();
        final now = DateTime.now();
        expect(vm.visibleWeek, getWeek(now));
        expect(vm.selectedDay.year, now.year);
        expect(vm.selectedDay.month, now.month);
        expect(vm.selectedDay.day, now.day);
        expect(ticks, 1);
      },
    );

    test('weekDays returns 7 consecutive days starting on visible Monday', () {
      final initial = DateTime(2025, 4, 9); // Wed
      final vm = CalendarViewModel(initial: initial);
      final monday = getWeek(initial);

      final days = vm.weekDays;
      expect(days.length, 7);
      expect(days.first, monday);
      for (var i = 0; i < 7; i++) {
        expect(days[i], monday.add(Duration(days: i)));
      }
    });
  });

  group('titles', () {
    test('monthTitle matches Danish long month+year', () {
      final anchor = DateTime(2025, 7, 4);
      final vm = CalendarViewModel(initial: anchor);
      final expected = DateFormat('MMMM y', 'da').format(getMonth(anchor));
      expect(vm.monthTitle, expected);
    });

    test(
      'weekTitle = "Uge <isoWeek>, <weekYear>" and weekSubTitle uses Thursday anchor',
      () {
        final anchor = DateTime(2024, 12, 31); // week-year boundary edge
        final vm = CalendarViewModel(initial: anchor);

        final w = vm.visibleWeek; // Monday
        final expectedTitle = 'Uge ${isoWeekNumber(w)}, ${weekYear(w)}';
        expect(vm.weekTitle, expectedTitle);

        final thursdayAnchor = toThursday(w);
        final expectedSub = DateFormat('MMMM y', 'da').format(thursdayAnchor);
        expect(vm.weekSubTitle, expectedSub);
      },
    );
  });

  group('tabs', () {
    test('setTab does nothing when same; notifies when changed', () {
      final vm = CalendarViewModel();
      expect(vm.tab, Tabs.month);

      var ticks = 0;
      vm.addListener(() => ticks++);

      vm.setTab(Tabs.month); // no-op
      expect(vm.tab, Tabs.month);
      expect(ticks, 0);

      vm.setTab(Tabs.week);
      expect(vm.tab, Tabs.week);
      expect(ticks, 1);

      vm.setTab(Tabs.week); // no-op again
      expect(ticks, 1);
    });
  });
}
