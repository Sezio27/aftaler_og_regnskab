import 'package:flutter/foundation.dart';

@immutable
class ServiceModel {
  final String? id;
  final String? name;
  final String? description;
  final String? duration;
  final double? price;
  final String? image;

  const ServiceModel({
    this.id,
    this.name,
    this.description,
    this.duration,
    this.price,
    this.image,
  });

  ServiceModel copyWith({
    String? id,
    String? name,
    String? description,
    String? duration,
    double? price,
    String? image,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      image: image ?? this.image,
    );
  }
}
