import 'package:flutter/foundation.dart';

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
}
