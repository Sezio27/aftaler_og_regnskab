import 'package:flutter/foundation.dart';

@immutable
class AppointmentModel {
  final String? id;
  final String? clientId;
  final String? serviceId;
  final List<String> checklistIds;

  /// When the appointment happens (local time on device).
  final DateTime? dateTime;
  final DateTime? payDate;

  /// Stored, resolved price (custom price if provided; otherwise service price; otherwise null).
  final double? price;

  final String? location;
  final String? note;
  final List<String> imageUrls;

  /// 'paid' | 'pending' | 'expired' | 'not_invoiced'
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

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'clientId': clientId,
    'serviceId': serviceId,
    'checklistIds': checklistIds,
    'dateTime': dateTime,
    'payDate': payDate,
    if (price != null) 'price': price,
    'location': location,
    'note': note,
    'imageUrls': imageUrls,
    'status': status,
  };

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final dt = json['dateTime'];
    DateTime? dtParsed;
    if (dt is DateTime) dtParsed = dt;

    final payDt = json['payDate'];
    DateTime? payDtParsed;
    if (payDt is DateTime) payDtParsed = payDt;

    return AppointmentModel(
      id: json['id'] as String?,
      clientId: json['clientId'] as String?,
      serviceId: json['serviceId'] as String?,
      checklistIds: ((json['checklistIds'] as List?) ?? const [])
          .map((e) => (e as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
      dateTime: dtParsed,
      payDate: payDtParsed,
      price: (json['price'] as num?)?.toDouble(),
      location: json['location'] as String?,
      note: json['note'] as String?,
      imageUrls: ((json['imageUrls'] as List?) ?? const [])
          .map((e) => (e as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
      status: json['status'] as String?,
    );
  }
}
