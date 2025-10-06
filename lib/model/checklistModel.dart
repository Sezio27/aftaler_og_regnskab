import 'package:flutter/material.dart';

@immutable
class ChecklistPoint {
  final String id;
  final int number;
  final String text;

  const ChecklistPoint({
    required this.id,
    required this.number,
    required this.text,
  });

  Map<String, dynamic> toJson() => {'id': id, 'number': number, 'text': text};

  factory ChecklistPoint.fromJson(Map<String, dynamic> j) => ChecklistPoint(
    id: j['id'] as String,
    number: (j['number'] as num?)?.toInt() ?? 0,
    text: j['text'] as String? ?? '',
  );
}

@immutable
class ChecklistModel {
  final String? id;
  final String? name;
  final String? description;
  final List<ChecklistPoint> points;

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
    List<ChecklistPoint>? points,
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
    'points': points.map((p) => p.toJson()).toList(),
  };

  factory ChecklistModel.fromJson(Map<String, dynamic> json) => ChecklistModel(
    id: json['id'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    points: ((json['points'] as List?) ?? const [])
        .map(
          (e) => ChecklistPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}
