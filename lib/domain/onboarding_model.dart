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

  static const empty = OnboardingModel();
}
