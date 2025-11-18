import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum Tabs { month, week }

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({DateTime? initial})
    : _visibleMonth = getMonth(initial ?? DateTime.now()),
      _visibleWeek = getWeek(initial ?? DateTime.now());
  DateTime _selectedDay = DateTime.now();
  DateTime get selectedDay => _selectedDay;

  void selectDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (_selectedDay == d) return;
    _selectedDay = d;
    _visibleWeek = getWeek(d);
    notifyListeners();
  }

  DateTime _visibleMonth;
  DateTime get visibleMonth => _visibleMonth;

  String get monthTitle => DateFormat('MMMM y', 'da').format(_visibleMonth);

  void prevMonth() {
    _visibleMonth = addMonths(_visibleMonth, -1);
    notifyListeners();
  }

  void nextMonth() {
    _visibleMonth = addMonths(_visibleMonth, 1);
    notifyListeners();
  }

  void jumpToCurrentMonth() {
    _visibleMonth = getMonth(DateTime.now());
    notifyListeners();
  }

  DateTime _visibleWeek;
  DateTime get visibleWeek => _visibleWeek;

  String get weekTitle => 'Uge ${isoWeekNumber(_visibleWeek)}';

  String get weekSubTitle {
    final anchor = toThursday(_visibleWeek);
    return DateFormat('MMMM y', 'da').format(anchor);
  }

  List<DateTime> get weekDays =>
      List.generate(7, (i) => _visibleWeek.add(Duration(days: i)));

  void prevWeek() {
    final m = addWeeks(_visibleWeek, -1);
    _visibleWeek = m;
    _selectedDay = m;
    notifyListeners();
  }

  void nextWeek() {
    final m = addWeeks(_visibleWeek, 1);
    _visibleWeek = m;
    _selectedDay = m;
    notifyListeners();
  }

  void jumpToCurrentWeek() {
    _selectedDay = DateTime.now();
    _visibleWeek = getWeek(DateTime.now());
    notifyListeners();
  }

  Tabs _tab = Tabs.month;
  Tabs get tab => _tab;
  void setTab(Tabs value) {
    if (_tab == value) return;
    _tab = value;
    notifyListeners();
  }
}
