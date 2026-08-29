import 'plant_model.dart';

class PlantHistory {
  final String id;
  final String plantName;
  final String scientificName;
  final String imagePath;
  final DateTime scannedAt;
  final String description;

  PlantHistory({
    required this.id,
    required this.plantName,
    required this.scientificName,
    required this.imagePath,
    required this.scannedAt,
    required this.description,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plantName': plantName,
      'scientificName': scientificName,
      'imagePath': imagePath,
      'scannedAt': scannedAt.toIso8601String(),
      'description': description,
    };
  }

  // Create from JSON
  factory PlantHistory.fromJson(Map<String, dynamic> json) {
    return PlantHistory(
      id: json['id'] as String,
      plantName: json['plantName'] as String,
      scientificName: json['scientificName'] as String,
      imagePath: json['imagePath'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      description: json['description'] as String,
    );
  }

  // Create from Plant model
  factory PlantHistory.fromPlant(Plant plant) {
    return PlantHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      plantName: plant.name,
      scientificName: plant.scientificName,
      imagePath: plant.imagePath ?? '',
      scannedAt: DateTime.now(),
      description: plant.description,
    );
  }
}
