import 'package:aftaler_og_regnskab/domain/appointment_model.dart';
import 'package:aftaler_og_regnskab/data/services/notification_service.dart';

class AppointmentNotifications {
  AppointmentNotifications(this._ns);
  final NotificationService _ns;

  Future<void> syncToday({
    required Iterable<AppointmentModel> appointments,
  }) async {
    if (!_ns.enabled) {
      for (final a in appointments) {
        final id = a.id;
        if (id != null) await _ns.cancelForAppointment(id);
      }
      return;
    }

    for (final a in appointments) {
      final start = a.dateTime!;

      await _ns.scheduleSameDayTwoHoursBefore(
        appointmentId: a.id!,
        appointmentDateTime: start,
        title: 'Aftale kl. ${_fmt(start)}',
        body: 'Du har en aftale kl. ${_fmt(start)}',
      );
    }
  }

  Future<void> cancelFor(String appointmentId) async {
    await _ns.cancelForAppointment(appointmentId);
  }

  Future<void> onAppointmentChanged(AppointmentModel appt) async {
    final id = appt.id;
    final dt = appt.dateTime;
    if (id == null || dt == null) return;

    await _ns.cancelForAppointment(id);

    await _ns.scheduleAt(
      id: _ns.stableId('appt-$id-2h'),
      title: 'Aftale om 2 timer',
      body:
          'Husk din aftale kl. ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      whenLocal: dt.subtract(const Duration(hours: 2)),
      payload: 'appt:$id',
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
