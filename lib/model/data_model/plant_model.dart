import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

part 'plant_g.dart';

@HiveType(typeId: 0)
class Plant {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String scientificName;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final Map<String, dynamic> taxonomy;
  @HiveField(4)
  final String nativeRegion;
  @HiveField(5)
  final String growthSeason;
  @HiveField(6)
  final String toxicity;
  @HiveField(7)
  final Map<String, dynamic> careGuide;
  @HiveField(8)
  final String healthScan;
  @HiveField(9)
  final String commonPests;
  @HiveField(10)
  final String commonDiseases;
  @HiveField(11)
  final String usage;
  @HiveField(12)
  final String funFact;
  @HiveField(13)
  final String? imagePath;

  Plant({
    required this.name,
    required this.scientificName,
    required this.description,
    required this.taxonomy,
    required this.nativeRegion,
    required this.growthSeason,
    required this.toxicity,
    required this.careGuide,
    required this.healthScan,
    required this.commonPests,
    required this.commonDiseases,
    required this.usage,
    required this.funFact,
    this.imagePath,
  });

  File? get imageFile => imagePath != null ? File(imagePath!) : null;

  // Generate a stable unique ID for this plant using deterministic MD5 hash
  // Dart's hashCode is NOT stable across different app runs!
  // Uses imagePath as the primary identifier since it's unique per scan
  // Falls back to a combination of name + scientificName for stability
  String get uniqueId {
    String sourceString;
    
    if (imagePath != null && imagePath!.isNotEmpty) {
      // Use the image path - stable and unique per scan
      sourceString = imagePath!;
    } else {
      // Fallback: combine name + scientific name + description for better uniqueness
      sourceString = '${name.toLowerCase()}-${scientificName.toLowerCase()}-${description.substring(0, description.length > 50 ? 50 : description.length)}';
    }
    
    // Use MD5 for deterministic hashing (always same output for same input)
    final bytes = utf8.encode(sourceString);
    final digest = md5.convert(bytes);
    
    // Take first 8 characters of hex for a shorter ID
    return digest.toString().substring(0, 16);
  }

  // Example: fromJson for the Gemini response
  factory Plant.fromGemini(Map<String, dynamic> json, String imagePath) {
    return Plant(
      name: json['plant_name_common'] ?? 'Unknown',
      scientificName: json['plant_name_scientific'] ?? '',
      description: json['description'] ?? '',
      taxonomy: Map<String, dynamic>.from(json['taxonomy'] ?? {}),
      nativeRegion: json['native_region'] ?? '',
      growthSeason: json['growth_season'] ?? '',
      toxicity: json['toxicity'] ?? '',
      careGuide: Map<String, dynamic>.from(json['care_guide'] ?? {}),
      healthScan: json['health_scan'] ?? '',
      commonPests: json['common_pests'] ?? '',
      commonDiseases: json['common_diseases'] ?? '',
      usage: json['usage'] ?? '',
      funFact: json['fun_fact'] ?? '',
      imagePath: imagePath,
    );
  }
}
