import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime mondayOf(DateTime d) {
  final x = DateTime(d.year, d.month, d.day);
  return x.subtract(
    Duration(days: x.weekday - DateTime.monday),
  ); // Mon=1..Sun=7
}

({DateTime start, DateTime end}) weekRange(DateTime d) {
  final start = mondayOf(d);
  return (start: start, end: start.add(const Duration(days: 6)));
}

({DateTime start, DateTime end}) monthRange(DateTime d) {
  final start = DateTime(d.year, d.month, 1);
  return (start: start, end: DateTime(d.year, d.month + 1, 0));
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

Future<List<AppointmentCardModel>> cardsForRange(
  AppointmentViewModel vm,
  DateTime start,
  DateTime end,
) async {
  final List<AppointmentCardModel> out = [];
  for (
    var d = DateTime(start.year, start.month, start.day);
    !d.isAfter(end);
    d = d.add(const Duration(days: 1))
  ) {
    final dayCards = await vm.cardsForDate(d);
    out.addAll(dayCards);
  }
  out.sort((a, b) => a.time.compareTo(b.time));
  return out;
}
