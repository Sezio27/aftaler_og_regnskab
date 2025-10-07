import 'package:flutter/foundation.dart';

@immutable
class AppointmentModel {
  final String? id;
  final String? clientId;
  final String? serviceId;
  final List<String> checklistIds;

  /// When the appointment happens (local time on device).
  final DateTime? dateTime;

  /// Stored, resolved price (custom price if provided; otherwise service price; otherwise null).
  final String? price;

  final String? location;
  final String? note;
  final List<String> imageUrls; // already-uploaded URLs

  /// 'paid' | 'pending' | 'expired' | 'not_invoiced'
  final String? status;

  const AppointmentModel({
    this.id,
    this.clientId,
    this.serviceId,
    this.checklistIds = const [],
    this.dateTime,
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
    String? price,
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
    'dateTime': dateTime, // repo converts to Timestamp
    'price': price,
    'location': location,
    'note': note,
    'imageUrls': imageUrls,
    'status': status,
  };

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    // dateTime comes in as a Timestamp from Firestore; repo converts for us,
    // but be defensive if a DateTime is passed in already.
    final dt = json['dateTime'];
    DateTime? parsed;
    if (dt is DateTime) parsed = dt;
    // Leave Timestamp parsing to the repo mapping.

    return AppointmentModel(
      id: json['id'] as String?,
      clientId: json['clientId'] as String?,
      serviceId: json['serviceId'] as String?,
      checklistIds: ((json['checklistIds'] as List?) ?? const [])
          .map((e) => (e as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
      dateTime: parsed,
      price: json['price'] as String?,
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
