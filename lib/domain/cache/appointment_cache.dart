import 'package:aftaler_og_regnskab/domain/appointment_model.dart';

class AppointmentCache {
  AppointmentCache();

  final Map<String, AppointmentModel?> _cache = {};
  void cacheAppointment(AppointmentModel model) {
    final id = model.id;
    if (id != null) _cache[id] = model;
  }

  void cacheAppointments(Iterable<AppointmentModel> models) {
    for (final a in models) {
      final id = a.id;
      if (id != null) _cache[id] = a;
    }
  }

  AppointmentModel? getAppointment(String id) => _cache[id];

  List<AppointmentModel> getAppointmentsBetween(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    final out = <AppointmentModel>[];
    for (final a in _cache.values) {
      final appt = a;
      if (appt == null) continue;
      final dt = appt.dateTime;
      if (dt == null) continue;
      if (!dt.isBefore(s) && !dt.isAfter(e)) out.add(appt);
    }
    out.sort(
      (a, b) =>
          (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)),
    );
    return out;
  }

  void remove(String id) => _cache.remove(id);
  void clear() => _cache.clear();
}
