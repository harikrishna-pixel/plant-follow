/// First-class climate/place object. Not a folder.
/// User → Location → Plant. Plant placement (indoor/outdoor) is a separate field.
class PlantLocation {
  final String id;
  final String name;
  final String? city;
  final String? postcode;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const PlantLocation({
    required this.id,
    required this.name,
    this.city,
    this.postcode,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  /// Reuses the existing weather lookup identity (city name) when known.
  String? get weatherPlaceName {
    final trimmed = city?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'postcode': postcode,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PlantLocation.fromJson(Map<String, dynamic> json) {
    return PlantLocation(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Home',
      city: json['city'] as String?,
      postcode: json['postcode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  PlantLocation copyWith({
    String? id,
    String? name,
    String? city,
    String? postcode,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return PlantLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      postcode: postcode ?? this.postcode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
