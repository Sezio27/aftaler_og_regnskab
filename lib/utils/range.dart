DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime mondayOf(DateTime d) {
  final shift = (d.weekday - DateTime.monday) % 7;
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: shift));
}

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonthInclusive(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);
DateTime startOfYear(DateTime d) => DateTime(d.year, 1, 1);

// (optional, to match your month helper style)
DateTime endOfYearInclusive(DateTime d) =>
    DateTime(d.year + 1, 1, 0, 23, 59, 59, 999);

DateTime endOfDayInclusive(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
DateTime getWeek(DateTime dt) {
  final d = dateOnly(dt);
  final shift = (d.weekday - DateTime.monday) % 7;
  return addDaysSafe(d, -shift);
}

DateTime addDaysSafe(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

DateTime addWeeks(DateTime monday, int delta) =>
    addDaysSafe(dateOnly(monday), 7 * delta);
({DateTime start, DateTime end}) weekRange(DateTime d) {
  final start = mondayOf(d);
  return (start: start, end: start.add(const Duration(days: 6)));
}

({DateTime start, DateTime end}) monthRange(DateTime d) {
  final start = DateTime(d.year, d.month, 1);
  return (start: start, end: DateTime(d.year, d.month + 1, 0));
}

({DateTime start, DateTime end}) twoMonthRange(DateTime d) {
  final start = DateTime(d.year, d.month, 1);
  return (start: start, end: DateTime(d.year, d.month + 2, 0));
}

({DateTime start, DateTime end}) prevMonthRange(DateTime d) {
  final start = d.subtract(const Duration(days: 31));
  return (start: start, end: d);
}

({DateTime start, DateTime end}) yearRange(DateTime d) {
  final start = DateTime(d.year, 1, 1);
  return (start: start, end: DateTime(d.year + 1, 1, 0));
}

({DateTime start, DateTime end}) twoWeekRange(DateTime d) {
  final start = DateTime(d.year, d.month, d.day);
  return (start: start, end: start.add(const Duration(days: 14)));
}

bool isInCurrentMonth(DateTime date) {
  final now = DateTime.now();
  final d = date.toLocal();
  return !d.isBefore(startOfMonth(now)) && !d.isAfter(endOfMonthInclusive(now));
}

bool isInCurrentYear(DateTime date) {
  final now = DateTime.now();
  final d = date.toLocal();
  return d.year == now.year;
}

// -------- ISO week utilities --------
// ISO week number: week containing Thursday is week of the year.
int isoWeekNumber(DateTime date) {
  final thursday = toThursday(date);
  final firstThursday = toThursday(DateTime(thursday.year, 1, 4));
  return (thursday.difference(mondayOf(firstThursday)).inDays ~/ 7) + 1;
}

// ISO week-year (week may belong to prev/next year)
int weekYear(DateTime date) => toThursday(date).year;

DateTime toThursday(DateTime d) => DateTime(
  d.year,
  d.month,
  d.day,
).add(Duration(days: (4 - (d.weekday == 7 ? 0 : d.weekday))));

DateTime getMonth(DateTime dt) => DateTime(dt.year, dt.month, 1);

DateTime addMonths(DateTime base, int delta) {
  final m = base.month + delta;
  final y = m == 0
      ? base.year - 1
      : m == 13
      ? base.year + 1
      : base.year;
  final nm = ((m - 1) % 12) + 1;

  return DateTime(y, nm, 1);
}
