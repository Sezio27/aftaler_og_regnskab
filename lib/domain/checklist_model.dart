import 'package:flutter/foundation.dart';

@immutable
class ChecklistModel {
  final String? id;
  final String? name;
  final String? description;
  final List<String> points;

  const ChecklistModel({
    this.id,
    this.name,
    this.description,
    this.points = const [],
  });

  ChecklistModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? points,
  }) => ChecklistModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    points: points ?? this.points,
  );
}
