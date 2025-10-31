// test/helpers/mocks.dart
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

// Import your VMs and models
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';

class MockFinanceVM extends Mock
    with ChangeNotifier
    implements FinanceViewModel {}

class MockAppointmentVM extends Mock
    with ChangeNotifier
    implements AppointmentViewModel {}

class MockCalendarVM extends Mock
    with ChangeNotifier
    implements CalendarViewModel {}

class MockServiceVM extends Mock
    with ChangeNotifier
    implements ServiceViewModel {}

class MockChecklistVM extends Mock
    with ChangeNotifier
    implements ChecklistViewModel {}

AppointmentCardModel makeCard({
  required String id,
  required DateTime time,
  String clientName = 'Anna',
  String serviceName = 'Makeup',
  double price = 500,
  String status = 'waiting',
  String? imageUrl,
}) {
  return AppointmentCardModel(
    id: id,
    clientName: clientName,
    serviceName: serviceName,
    time: time,
    price: price,
    status: status,
    imageUrl: imageUrl,
  );
}
