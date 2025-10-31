import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:aftaler_og_regnskab/services/notification_service.dart';

class AppointmentNotifications {
  AppointmentNotifications(this._ns);
  final NotificationService _ns;

  Future<void> syncToday({
    required Iterable<AppointmentModel> appointments,
  }) async {
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

  Future<void> onAppointmentChanged(AppointmentModel a) async {
    await syncToday(appointments: [a]);
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
