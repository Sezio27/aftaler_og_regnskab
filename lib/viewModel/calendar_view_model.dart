import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum Tabs { month, week }

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({DateTime? initial})
    : _visibleMonth = _getMonth(initial ?? DateTime.now()),
      _visibleWeek = _getWeek(initial ?? DateTime.now());
  DateTime _selectedDay = DateTime.now();
  DateTime get selectedDay => _selectedDay;

  void selectDay(DateTime day) {
    // keep only date part
    final d = DateTime(day.year, day.month, day.day);
    if (_selectedDay == d) return;
    _selectedDay = d;
    // also keep visibleWeek aligned to the selected day
    _visibleWeek = _getWeek(d);
    notifyListeners();
  }

  // OPTIONAL: placeholder event count for dots
  int eventCountFor(DateTime day) {
    // replace with your real lookup
    // e.g. return eventsByDate[DateOnly(day)]?.length ?? 0;
    return (day.day % 3 == 0) ? 1 : (day.day % 5 == 0 ? 2 : 0);
  }

  // -------- Month state --------
  DateTime _visibleMonth; // first day of visible month
  DateTime get visibleMonth => _visibleMonth;

  String get monthTitle => DateFormat('MMMM y', 'da').format(_visibleMonth);

  void prevMonth() {
    _visibleMonth = _addMonths(_visibleMonth, -1);
    notifyListeners();
  }

  void nextMonth() {
    _visibleMonth = _addMonths(_visibleMonth, 1);
    notifyListeners();
  }

  void jumpToCurrentMonth() {
    _visibleMonth = _getMonth(DateTime.now());
    notifyListeners();
  }

  static DateTime _getMonth(DateTime dt) => DateTime(dt.year, dt.month, 1);

  static DateTime _addMonths(DateTime base, int delta) {
    final m = base.month + delta;
    final y = base.year + ((m - 1) ~/ 12);
    final nm = ((m - 1) % 12) + 1;
    return DateTime(y, nm, 1);
  }

  // -------- Week state (Monday-based) --------
  DateTime _visibleWeek; // Monday of visible week
  DateTime get visibleWeek => _visibleWeek;

  /// ISO-like title: "Uge 37, 2025"
  String get weekTitle =>
      'Uge ${_isoWeekNumber(_visibleWeek)}, ${_weekYear(_visibleWeek)}';

  /// Optional sublabel for UI: e.g. "September 2025"
  String get weekSubTitle => DateFormat('MMMM y', 'da').format(_visibleWeek);

  /// The 7 dates (Mon..Sun) of the visible week.
  List<DateTime> get weekDays =>
      List.generate(7, (i) => _visibleWeek.add(Duration(days: i)));

  void prevWeek() {
    _visibleWeek = _addWeeks(_visibleWeek, -1);
    notifyListeners();
  }

  void nextWeek() {
    _visibleWeek = _addWeeks(_visibleWeek, 1);
    notifyListeners();
  }

  void jumpToCurrentWeek() {
    _visibleWeek = _getWeek(DateTime.now());
    notifyListeners();
  }

  static DateTime _getWeek(DateTime dt) {
    // Normalize to local date (midnight), then step back to Monday.
    final d = DateTime(dt.year, dt.month, dt.day);
    final shift = (d.weekday - DateTime.monday) % 7; // Mon=1..Sun=7
    return d.subtract(Duration(days: shift));
  }

  static DateTime _addWeeks(DateTime monday, int delta) =>
      monday.add(Duration(days: 7 * delta));

  // -------- Tabs --------
  Tabs _tab = Tabs.month;
  Tabs get tab => _tab;
  void setTab(Tabs value) {
    if (_tab == value) return;
    _tab = value;
    notifyListeners();
  }

  // -------- ISO week utilities --------
  // ISO week number: week containing Thursday is week of the year.
  static int _isoWeekNumber(DateTime date) {
    final thursday = _toThursday(date);
    final firstThursday = _toThursday(DateTime(thursday.year, 1, 4));
    return (thursday.difference(_mondayOf(firstThursday)).inDays ~/ 7) + 1;
  }

  // ISO week-year (week may belong to prev/next year)
  static int _weekYear(DateTime date) => _toThursday(date).year;

  static DateTime _toThursday(DateTime d) => DateTime(
    d.year,
    d.month,
    d.day,
  ).add(Duration(days: (4 - (d.weekday == 7 ? 0 : d.weekday))));

  static DateTime _mondayOf(DateTime d) {
    final shift = (d.weekday - DateTime.monday) % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: shift));
  }
}
