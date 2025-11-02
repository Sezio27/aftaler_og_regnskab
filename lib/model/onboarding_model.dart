import 'package:flutter/foundation.dart';

@immutable
class OnboardingModel {
  final String? phone;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? businessName;
  final String? address;
  final String? city;
  final String? postal;

  const OnboardingModel({
    this.phone,
    this.email,
    this.firstName,
    this.lastName,
    this.businessName,
    this.address,
    this.city,
    this.postal,
  });

  bool get isComplete =>
      _notEmpty(phone) &&
      _notEmpty(email) &&
      _notEmpty(firstName) &&
      _notEmpty(lastName) &&
      _notEmpty(businessName) &&
      _notEmpty(address) &&
      _notEmpty(city) &&
      _notEmpty(postal);

  static bool _notEmpty(String? s) => (s ?? '').trim().isNotEmpty;

  OnboardingModel copyWith({
    String? phone,
    String? email,
    String? firstName,
    String? lastName,
    String? businessName,
    String? address,
    String? city,
    String? postal,
  }) {
    return OnboardingModel(
      phone: phone ?? this.phone,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      city: city ?? this.city,
      postal: postal ?? this.postal,
    );
  }

  Map<String, dynamic> toFirestoreMap({required String uid}) => {
    'uid': uid,
    'phone': phone,
    'email': email,
    'name': {'first': firstName, 'last': lastName},
    'business': {
      'name': businessName,
      'address': address,
      'city': city,
      'postal': postal,
    },
  };

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'businessName': businessName,
    'address': address,
    'city': city,
    'postal': postal,
  };

  factory OnboardingModel.fromJson(Map<String, dynamic> json) {
    return OnboardingModel(
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      businessName: json['businessName'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      postal: json['postal'] as String?,
    );
  }

  static const empty = OnboardingModel();
}
