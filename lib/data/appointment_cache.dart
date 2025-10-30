import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';

class AppointmentCache {
  AppointmentCache(this._appointmentRepo);

  final AppointmentRepository _appointmentRepo;

  final Map<String, AppointmentModel?> _cache = {};

  /// Store a single client in the cache.
  void cacheAppointment(AppointmentModel model) {
    final id = model.id;
    if (id != null) _cache[id] = model;
  }

  /// Store multiple clients in the cache at once.
  void cacheAppointments(Iterable<AppointmentModel> models) {
    for (final a in models) {
      final id = a.id;
      if (id != null) _cache[id] = a;
    }
  }

  Future<Map<String, AppointmentModel?>> fetchAppointments(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final missing = ids.where((id) => !_cache.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      final batched = await _appointmentRepo.getAppointments(missing);
      _cache.addAll(batched);
    }
    return {for (final id in ids) id: _cache[id]};
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
