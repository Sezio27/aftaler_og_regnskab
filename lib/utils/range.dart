DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime mondayOf(DateTime d) {
  final x = DateTime(d.year, d.month, d.day);
  return x.subtract(
    Duration(days: x.weekday - DateTime.monday),
  ); // Mon=1..Sun=7
}

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonthInclusive(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);
DateTime endOfDayInclusive(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

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

DateTime addMonths(DateTime d, int months) =>
    DateTime(d.year, d.month + months, 1);

({DateTime start, DateTime end}) yearRange(DateTime d) {
  final start = DateTime(d.year, 1, 1);
  return (start: start, end: DateTime(d.year + 1, 1, 0));
}

({DateTime start, DateTime end}) twoWeekRange(DateTime d) {
  final start = DateTime(d.year, d.month, d.day);
  return (start: start, end: start.add(const Duration(days: 14)));
}
