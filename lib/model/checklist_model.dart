import 'package:flutter/foundation.dart';

@immutable
class ChecklistModel {
  final String? id;
  final String? name;
  final String? description;

  /// Ordered list of point texts (index = order).
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

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'points': points,
  };

  factory ChecklistModel.fromJson(Map<String, dynamic> json) => ChecklistModel(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    points: ((json['points'] as List?) ?? const [])
        .map((e) => (e as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(),
  );
}
