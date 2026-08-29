import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class PlantCategory extends Equatable {
  final String name;
  final String imageUrl;
  final String description;

  const PlantCategory({
    required this.name,
    required this.imageUrl,
    required this.description,
  });

  factory PlantCategory.fromJson(Map<String, dynamic> json) {
    return PlantCategory(
      name: (json['name'] ?? json['title'] ?? 'Unknown') as String,
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? json['thumbnail'] ?? json['image'] ?? '')
          as String,
      description: (json['description'] ?? json['summary'] ?? '') as String,
    );
  }

  String get thumbnail {
    if (imageUrl.isEmpty) {
      // Return empty to use error builder fallback icon
      return '';
    }
    if (!_isValidUrl(imageUrl)) {
      // Return empty to use error builder fallback icon
      return '';
    }
    // Unsplash API URLs (images.unsplash.com/photo-...) are valid and reliable
    return imageUrl;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'image_url': imageUrl,
        'description': description,
      };

  @override
  List<Object?> get props => [name, imageUrl, description];
}

class PlantSummary extends Equatable {
  final String name;
  final String scientificName;
  final String category;
  final String imageUrl;
  final String description;

  const PlantSummary({
    required this.name,
    required this.scientificName,
    required this.category,
    required this.imageUrl,
    required this.description,
  });

  factory PlantSummary.fromJson(Map<String, dynamic> json) {
    return PlantSummary(
      name: (json['name'] ?? json['common_name'] ?? 'Unknown') as String,
      scientificName: (json['scientific_name'] ?? json['scientificName'] ?? json['botanical_name'] ?? '')
          as String,
      category: (json['category'] ?? json['type'] ?? '') as String,
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? json['thumbnail'] ?? json['image'] ?? '')
          as String,
      description: (json['description'] ?? json['summary'] ?? '') as String,
    );
  }

  String get displayName => name.isNotEmpty ? name : scientificName;

  String get thumbnail {
    if (imageUrl.isEmpty) {
      // Return empty to use error builder fallback icon
      return '';
    }
    if (!_isValidUrl(imageUrl)) {
      // Return empty to use error builder fallback icon
      return '';
    }
    // Unsplash API URLs (images.unsplash.com/photo-...) are valid and reliable
    return imageUrl;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'scientific_name': scientificName,
        'category': category,
        'image_url': imageUrl,
        'description': description,
      };

  @override
  List<Object?> get props => [name, scientificName, category, imageUrl, description];
}

class PlantSearchResult extends Equatable {
  final String city;
  final double temperature;
  final List<PlantCategory> categories;
  final List<PlantSummary> plants;

  const PlantSearchResult({
    required this.city,
    required this.temperature,
    required this.categories,
    required this.plants,
  });

  factory PlantSearchResult.fromJson(Map<String, dynamic> json) {
    return PlantSearchResult(
      city: json['city'] ?? 'Unknown',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((item) => PlantCategory.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      plants: (json['plants'] as List<dynamic>? ?? [])
          .map((item) => PlantSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'city': city,
        'temperature': temperature,
        'categories': categories.map((c) => c.toJson()).toList(),
        'plants': plants.map((p) => p.toJson()).toList(),
      };

  @override
  List<Object?> get props => [city, temperature, categories, plants];

  bool get hasValidImages {
    final categoryHasImage = categories.any((c) => _isValidUrl(c.imageUrl));
    final plantHasImage = plants.any((p) => _isValidUrl(p.imageUrl));
    return categoryHasImage && plantHasImage;
  }
}

bool _isValidUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return false;
  if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) return false;
  
  // Filter out URLs that likely contain non-plant content
  final lowerUrl = value.toLowerCase();
  final suspiciousKeywords = [
    'dog', 'cat', 'animal', 'person', 'people', 'human',
    'car', 'building', 'city', 'food', 'drink',
    'furniture', 'tech', 'gadget', 'phone'
  ];
  
  for (var keyword in suspiciousKeywords) {
    if (lowerUrl.contains(keyword)) {
      debugPrint('⚠️ Filtered out suspicious URL containing "$keyword": $value');
      return false;
    }
  }
  
  return true;
}
