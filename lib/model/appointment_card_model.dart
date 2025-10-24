// lib/model/appointment_card_model.dart
import 'package:flutter/foundation.dart';

enum AppointmentStatus { notInvoiced, invoiced, cancelled }

@immutable
class AppointmentCardModel {
  final String id;
  final String clientName;
  final String serviceName;
  final String? phone;
  final String? email;
  final String? imageUrl;
  final DateTime time;
  final String? duration;
  final double? price;
  final String status;
  final bool isBusiness;

  const AppointmentCardModel({
    required this.id,
    required this.clientName,
    required this.serviceName,
    required this.time,
    this.phone,
    this.email,
    this.imageUrl,
    this.duration,
    this.price,
    required this.status,
    this.isBusiness = false,
  });
}
