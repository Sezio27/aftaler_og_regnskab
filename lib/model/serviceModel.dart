import 'package:flutter/foundation.dart';

@immutable
class ServiceModel {
  final String? id;
  final String? name;
  final String? description;
  final String? duration;
  final String? price;
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
    String? price,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'duration': duration,
    'price': price,
    'image': image,
  };

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      duration: json['duration'] as String?,
      price: json['price'] as String?,
      image: json['image'] as String?,
    );
  }
}
