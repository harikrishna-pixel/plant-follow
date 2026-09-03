import 'plant_model.dart';

class PlantFolder {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<String> plantIds; // List of plant IDs in this folder

  PlantFolder({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    List<String>? plantIds,
  }) : plantIds = plantIds ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'plantIds': plantIds,
    };
  }

  factory PlantFolder.fromJson(Map<String, dynamic> json) {
    return PlantFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      plantIds: (json['plantIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  bool containsPlant(Plant plant) {
    return plantIds.any(plant.matchesStoredId);
  }

  String get plantCountLabel {
    final n = plantIds.length;
    return n == 1 ? '1 plant' : '$n plants';
  }

  PlantFolder copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    List<String>? plantIds,
  }) {
    return PlantFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      plantIds: plantIds ?? this.plantIds,
    );
  }
}
