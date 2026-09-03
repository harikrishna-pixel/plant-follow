import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import 'plant_context.dart';

part 'plant_g.dart';

enum SpeciesConfidence { high, medium, low, unknown }

/// How confirmed the saved identity is. Independent of model confidence
/// so a user-selected alternative can be confirmed without faking a score.
enum IdentityStatus { confirmed, likely, unconfirmed }

class IdentityStatusCodec {
  static IdentityStatus? tryFromWire(dynamic raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'confirmed':
        return IdentityStatus.confirmed;
      case 'likely':
        return IdentityStatus.likely;
      case 'unconfirmed':
        return IdentityStatus.unconfirmed;
      default:
        return null;
    }
  }

  static String wireName(IdentityStatus value) {
    switch (value) {
      case IdentityStatus.confirmed:
        return 'confirmed';
      case IdentityStatus.likely:
        return 'likely';
      case IdentityStatus.unconfirmed:
        return 'unconfirmed';
    }
  }

  /// Empty/legacy records were saved as facts. Unknown confidence on those
  /// plants must not be rewritten as "likely".
  static IdentityStatus resolve({
    required String identityStatus,
    required SpeciesConfidence confidence,
  }) {
    final explicit = tryFromWire(identityStatus);
    if (explicit != null) return explicit;
    switch (confidence) {
      case SpeciesConfidence.high:
        return IdentityStatus.confirmed;
      case SpeciesConfidence.medium:
        return IdentityStatus.likely;
      case SpeciesConfidence.low:
        return IdentityStatus.unconfirmed;
      case SpeciesConfidence.unknown:
        return IdentityStatus.confirmed;
    }
  }
}

class SpeciesConfidenceCodec {
  static SpeciesConfidence fromWire(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'high':
        return SpeciesConfidence.high;
      case 'medium':
        return SpeciesConfidence.medium;
      case 'low':
        return SpeciesConfidence.low;
      default:
        return SpeciesConfidence.unknown;
    }
  }

  static String wireName(SpeciesConfidence value) {
    switch (value) {
      case SpeciesConfidence.high:
        return 'high';
      case SpeciesConfidence.medium:
        return 'medium';
      case SpeciesConfidence.low:
        return 'low';
      case SpeciesConfidence.unknown:
        return '';
    }
  }
}

@HiveType(typeId: 0)
class Plant {
  /// Durable business identifier. Never derived from image path.
  @HiveField(14)
  final String id;

  /// Indoor/outdoor/covered placement. Independent of [locationId].
  @HiveField(15)
  final PlantWeatherContext placement;

  /// Optional first-class Location. Folders are separate organizational groups.
  @HiveField(16)
  final String? locationId;

  /// Crop/harvest modules appear only when this plant is harvestable.
  /// Audience is a property of the plant, not a user mode. Defaults false.
  @HiveField(17)
  final bool isHarvestable;

  /// Optional crop profile id (tomato, leafy, generic). Unused when not harvestable.
  @HiveField(18)
  final String? cropId;

  /// Species identification confidence wire name: high / medium / low / empty.
  @HiveField(19)
  final String speciesConfidence;

  /// Model-supplied alternatives only. Never fabricated.
  @HiveField(20)
  final List<String> alternativeNames;

  /// confirmed / likely / unconfirmed. Empty on legacy plants.
  @HiveField(21)
  final String identityStatus;

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
    String? id,
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
    this.placement = PlantWeatherContext.unknown,
    this.locationId,
    this.isHarvestable = false,
    this.cropId,
    this.speciesConfidence = '',
    this.alternativeNames = const [],
    this.identityStatus = '',
  }) : id = (id != null && id.isNotEmpty) ? id : generateDurableId();

  SpeciesConfidence get identificationConfidence =>
      SpeciesConfidenceCodec.fromWire(speciesConfidence);

  IdentityStatus get identityConfirmation => IdentityStatusCodec.resolve(
        identityStatus: identityStatus,
        confidence: identificationConfidence,
      );

  File? get imageFile => imagePath != null ? File(imagePath!) : null;

  /// Legacy folder key: MD5 of image path (or name fallback).
  /// Kept so existing garden `plantIds` continue to resolve.
  /// New writes must use [id], not this value.
  String get uniqueId {
    String sourceString;

    if (imagePath != null && imagePath!.isNotEmpty) {
      sourceString = imagePath!;
    } else {
      sourceString =
          '${name.toLowerCase()}-${scientificName.toLowerCase()}-${description.substring(0, description.length > 50 ? 50 : description.length)}';
    }

    final bytes = utf8.encode(sourceString);
    final digest = md5.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// True if a stored folder/reminder id refers to this plant.
  bool matchesStoredId(String storedId) =>
      storedId == id || storedId == uniqueId;

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String generateDurableId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-'
        '${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  factory Plant.fromGemini(Map<String, dynamic> json, String imagePath) {
    return Plant(
      name: _firstNonEmpty([
            json['plant_name_common'],
            json['common_name'],
            json['plant_name'],
          ]) ??
          'Unknown',
      scientificName: _firstNonEmpty([
            json['plant_name_scientific'],
            json['scientific_name'],
          ]) ??
          '',
      description: _asGeminiText(json['description']),
      taxonomy: _asGeminiMap(json['taxonomy']),
      nativeRegion: _asGeminiText(json['native_region']),
      growthSeason: _asGeminiText(json['growth_season']),
      toxicity: _asGeminiText(json['toxicity']),
      careGuide: _asGeminiMap(json['care_guide']),
      healthScan: _asGeminiText(json['health_scan']),
      commonPests: _asGeminiText(json['common_pests']),
      commonDiseases: _asGeminiText(json['common_diseases']),
      usage: _asGeminiText(json['usage']),
      funFact: _asGeminiText(json['fun_fact']),
      imagePath: imagePath,
    );
  }

  static String _asGeminiText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      return value
          .map(_asGeminiText)
          .where((part) => part.trim().isNotEmpty)
          .join(', ');
    }
    if (value is Map) {
      for (final key in const [
        'text',
        'summary',
        'description',
        'notes',
        'value',
      ]) {
        final inner = value[key];
        if (inner is String && inner.trim().isNotEmpty) return inner;
      }
      return value.values
          .map(_asGeminiText)
          .where((part) => part.trim().isNotEmpty)
          .join('. ');
    }
    return value.toString();
  }

  static Map<String, dynamic> _asGeminiMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      return {'summary': value.trim()};
    }
    return {};
  }

  Plant copyWith({
    String? id,
    String? name,
    String? scientificName,
    String? description,
    Map<String, dynamic>? taxonomy,
    String? nativeRegion,
    String? growthSeason,
    String? toxicity,
    Map<String, dynamic>? careGuide,
    String? healthScan,
    String? commonPests,
    String? commonDiseases,
    String? usage,
    String? funFact,
    String? imagePath,
    PlantWeatherContext? placement,
    String? locationId,
    bool? isHarvestable,
    String? cropId,
    String? speciesConfidence,
    List<String>? alternativeNames,
    String? identityStatus,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      description: description ?? this.description,
      taxonomy: taxonomy ?? this.taxonomy,
      nativeRegion: nativeRegion ?? this.nativeRegion,
      growthSeason: growthSeason ?? this.growthSeason,
      toxicity: toxicity ?? this.toxicity,
      careGuide: careGuide ?? this.careGuide,
      healthScan: healthScan ?? this.healthScan,
      commonPests: commonPests ?? this.commonPests,
      commonDiseases: commonDiseases ?? this.commonDiseases,
      usage: usage ?? this.usage,
      funFact: funFact ?? this.funFact,
      imagePath: imagePath ?? this.imagePath,
      placement: placement ?? this.placement,
      locationId: locationId ?? this.locationId,
      isHarvestable: isHarvestable ?? this.isHarvestable,
      cropId: cropId ?? this.cropId,
      speciesConfidence: speciesConfidence ?? this.speciesConfidence,
      alternativeNames: alternativeNames ?? this.alternativeNames,
      identityStatus: identityStatus ?? this.identityStatus,
    );
  }
}
