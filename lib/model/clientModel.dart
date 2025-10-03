import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

@immutable
class ClientModel {
  final String? id;
  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? postal;
  final String? cvr;
  final String? image;

  const ClientModel({
    this.id,
    this.name,
    this.cvr,
    this.image,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.postal,
  });

  ClientModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? postal,
    String? cvr,
    String? image,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      postal: postal ?? this.postal,
      cvr: cvr ?? this.cvr,
      image: image ?? this.image,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'city': city,
    'postal': postal,
    'cvr': cvr,
    'image': image,
  };

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      postal: json['postal'] as String?,
      cvr: json['cvr'] as String?,
      image: json['image'] as String?,
    );
  }
}
