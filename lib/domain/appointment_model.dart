import 'package:flutter/foundation.dart';

@immutable
class AppointmentModel {
  final String? id;
  final String? clientId;
  final String? serviceId;
  final List<String> checklistIds;
  final DateTime? dateTime;
  final DateTime? payDate;
  final double? price;
  final String? location;
  final String? note;
  final List<String> imageUrls;
  final String? status;

  const AppointmentModel({
    this.id,
    this.clientId,
    this.serviceId,
    this.checklistIds = const [],
    this.dateTime,
    this.payDate,
    this.price,
    this.location,
    this.note,
    this.imageUrls = const [],
    this.status,
  });

  AppointmentModel copyWith({
    String? id,
    String? clientId,
    String? serviceId,
    List<String>? checklistIds,
    DateTime? dateTime,
    DateTime? payDate,
    double? price,
    String? location,
    String? note,
    List<String>? imageUrls,
    String? status,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      serviceId: serviceId ?? this.serviceId,
      checklistIds: checklistIds ?? this.checklistIds,
      dateTime: dateTime ?? this.dateTime,
      payDate: payDate ?? this.payDate,
      price: price ?? this.price,
      location: location ?? this.location,
      note: note ?? this.note,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
    );
  }
}
