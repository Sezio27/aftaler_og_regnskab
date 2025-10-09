import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum Tabs { month, week }

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({DateTime? initial})
    : _visibleMonth = _getMonth(initial ?? DateTime.now());

  DateTime _visibleMonth;

  DateTime get visibleMonth => _visibleMonth;

  String get monthTitle => DateFormat('MMMM y', 'da').format(_visibleMonth);

  /// Move one month backward/forward.
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

  static DateTime _getMonth(DateTime dt) => DateTime(dt.year, dt.month);

  static DateTime _addMonths(DateTime base, int delta) {
    final y = base.year;
    final m = base.month + delta;
    final newYear = y + ((m - 1) ~/ 12);
    final newMonth = ((m - 1) % 12) + 1;
    return DateTime(newYear, newMonth, 1);
  }

  // ---- Tabs state ----
  Tabs _tab = Tabs.month;
  Tabs get tab => _tab;
  void setTab(Tabs value) {
    if (_tab == value) return;
    _tab = value;
    notifyListeners();
  }
}
