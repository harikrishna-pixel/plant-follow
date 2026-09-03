import '../model/data_model/plant_model.dart';
import 'identification_result.dart';
import 'plant_ai_client.dart';

/// Debug-only pipeline categories for TestFlight diagnosis. Never shown in UI.
enum IdentifyFailureKind {
  network,
  api,
  model,
  parser,
  invalid,
  storage,
  local,
}

class IdentifyAttempt {
  final Plant? plant;
  final IdentificationResult? result;
  final IdentifyFailureKind? failure;
  final String? debugDetail;

  const IdentifyAttempt._({
    this.plant,
    this.result,
    this.failure,
    this.debugDetail,
  });

  factory IdentifyAttempt.ok(Plant plant, IdentificationResult result) =>
      IdentifyAttempt._(plant: plant, result: result);

  factory IdentifyAttempt.fail(IdentifyFailureKind failure, [String? detail]) =>
      IdentifyAttempt._(failure: failure, debugDetail: detail);

  bool get isSuccess => plant != null && failure == null;
}

class IdentifyFailureCopy {
  IdentifyFailureCopy._();

  static String title(IdentifyFailureKind? kind) {
    switch (kind) {
      case IdentifyFailureKind.network:
        return "We couldn't connect.";
      case IdentifyFailureKind.api:
      case IdentifyFailureKind.model:
        return "We couldn't identify this plant right now.";
      case IdentifyFailureKind.parser:
        return "We couldn't read the result.";
      case IdentifyFailureKind.invalid:
        return "We couldn't find enough plant detail.";
      case IdentifyFailureKind.storage:
      case IdentifyFailureKind.local:
        return "We couldn't save this plant.";
      case null:
        return "We couldn't identify this plant right now.";
    }
  }

  static String body(IdentifyFailureKind? kind) {
    switch (kind) {
      case IdentifyFailureKind.network:
        return 'Check your connection and try again.';
      case IdentifyFailureKind.api:
      case IdentifyFailureKind.model:
        return 'Please try again.';
      case IdentifyFailureKind.parser:
        return 'Try another photo.';
      case IdentifyFailureKind.invalid:
        return 'Try a clearer photo of the plant, flower, or leaves.';
      case IdentifyFailureKind.storage:
      case IdentifyFailureKind.local:
        return 'The identification is still here. Please try saving again.';
      case null:
        return 'Please try again.';
    }
  }
}

class IdentifyLogic {
  IdentifyLogic._();

  static const notSureCopy = "We're not fully sure yet.";
  static const retryAction = 'Try another photo';

  static IdentifyAttempt fromModelText(String? content, String imagePath) {
    if (content == null || content.trim().isEmpty) {
      return IdentifyAttempt.fail(IdentifyFailureKind.model, 'empty output');
    }
    Map<String, dynamic>? json;
    try {
      json = PlantAiClient.extractJson(content);
    } catch (e) {
      return IdentifyAttempt.fail(IdentifyFailureKind.parser, '$e');
    }
    if (json == null) {
      return IdentifyAttempt.fail(IdentifyFailureKind.parser, 'no json');
    }
    return fromJson(json, imagePath);
  }

  static IdentifyAttempt fromJson(Map<String, dynamic> json, String imagePath) {
    final imageQuality = ImageQualityCodec.fromWire(
      json['image_quality'] ?? json['photo_quality'],
    );
    final error = (json['error'] ?? '').toString().trim().toLowerCase();
    if (error == 'no_image_received' || error == 'vision_unavailable') {
      return IdentifyAttempt.fail(IdentifyFailureKind.model, error);
    }
    if (json['error'] != null || imageQuality == ImageQualityKind.notAPlant) {
      return IdentifyAttempt.fail(
        IdentifyFailureKind.invalid,
        '${json['error'] ?? 'not_a_plant'}',
      );
    }
    if (_looksLikeDiagnosisPayload(json)) {
      return IdentifyAttempt.fail(
        IdentifyFailureKind.invalid,
        'diagnosis payload',
      );
    }
    final name = _firstNonEmpty([
      json['plant_name_common'],
      json['common_name'],
      json['plant_name'],
    ]);
    if (!_isUsableSpeciesName(name)) {
      return IdentifyAttempt.fail(IdentifyFailureKind.invalid, 'unusable name');
    }
    var confidence = SpeciesConfidenceCodec.fromWire(
      json['identification_confidence'] ?? json['species_confidence'],
    );
    final evidence = _evidenceSummary(json);
    if (evidence.isEmpty && confidence == SpeciesConfidence.high) {
      confidence = SpeciesConfidence.low;
    }
    final identityStatus = IdentificationResult.statusForConfidence(confidence);
    final candidates = parseCandidates(json, primaryCommonName: name);
    final plant = Plant.fromGemini(json, imagePath).copyWith(
      speciesConfidence: SpeciesConfidenceCodec.wireName(confidence),
      alternativeNames: candidates.map((c) => c.label).toList(),
      identityStatus: IdentityStatusCodec.wireName(identityStatus),
    );
    if (!_isUsableSpeciesName(plant.name)) {
      return IdentifyAttempt.fail(IdentifyFailureKind.invalid, 'mapped unknown');
    }
    final result = IdentificationResult(
      commonName: plant.name,
      scientificName: plant.scientificName,
      confidence: confidence,
      alternatives: candidates,
      evidenceSummary: evidence,
      safety: PlantSafety.fromIdentificationJson(json),
      imageQuality: imageQuality,
      retryTips: identityStatus == IdentityStatus.confirmed
          ? const []
          : IdentificationResult.retryTipsFor(
              imageQuality == ImageQualityKind.ok
                  ? ImageQualityKind.unknown
                  : imageQuality,
            ).take(IdentificationResult.maxRetryTips).toList(),
      identityStatus: identityStatus,
      confirmationSource: 'model',
    );
    return IdentifyAttempt.ok(plant, result);
  }

  static List<IdentifyCandidate> parseCandidates(
    Map<String, dynamic> json, {
    required String primaryCommonName,
  }) {
    final raw = json['alternative_candidates'] ?? json['alternatives'];
    if (raw is! List) return const [];
    final names = <IdentifyCandidate>[];
    final primary = primaryCommonName.trim().toLowerCase();
    for (final item in raw) {
      if (names.length >= IdentificationResult.maxAlternatives) break;
      IdentifyCandidate? candidate;
      if (item is String) {
        candidate = IdentifyCandidate.tryParse(item);
      } else if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final common = _firstNonEmpty([
          map['plant_name_common'],
          map['common_name'],
          map['name'],
        ]);
        final scientific = _firstNonEmpty([
          map['plant_name_scientific'],
          map['scientific_name'],
        ]);
        if (_isUsableSpeciesName(common)) {
          candidate = IdentifyCandidate(
            commonName: common,
            scientificName: scientific,
            confidence: map['confidence'] == null &&
                    map['identification_confidence'] == null
                ? null
                : SpeciesConfidenceCodec.fromWire(
                    map['confidence'] ?? map['identification_confidence'],
                  ),
          );
        }
      }
      if (candidate == null) continue;
      if (!_isUsableSpeciesName(candidate.commonName)) continue;
      if (candidate.commonName.trim().toLowerCase() == primary) continue;
      names.add(candidate);
    }
    return names;
  }

  static String _evidenceSummary(Map<String, dynamic> json) {
    final text = _firstNonEmpty([
      json['evidence_summary'],
      json['botanical_evidence'],
    ]);
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower.contains('as an ai') ||
        lower.contains('chain of thought') ||
        lower.contains('i think') ||
        lower.contains('my reasoning')) {
      return '';
    }
    if (text.length > 160) return '${text.substring(0, 157).trim()}…';
    return text;
  }

  static bool _looksLikeDiagnosisPayload(Map<String, dynamic> json) {
    final hasSpecies = _firstNonEmpty([
      json['plant_name_common'],
      json['plant_name_scientific'],
    ]).isNotEmpty;
    return !hasSpecies &&
        (json.containsKey('overall_condition') ||
            json.containsKey('primary_issue') ||
            json.containsKey('treatment_steps'));
  }

  static bool _isUsableSpeciesName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return false;
    const rejected = {
      'unknown',
      'unknown plant',
      'n/a',
      'na',
      'none',
      'not a plant',
      'no plant',
      'unable to identify',
      'unidentified',
    };
    if (rejected.contains(n)) return false;
    if (n.contains('not a plant') || n.contains('cannot identify')) {
      return false;
    }
    return true;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String displayName(Plant plant) {
    switch (plant.identityConfirmation) {
      case IdentityStatus.likely:
        return 'Likely ${plant.name}';
      case IdentityStatus.unconfirmed:
        return 'Not sure yet';
      case IdentityStatus.confirmed:
        return plant.name;
    }
  }

  static bool isUncertain(Plant plant) {
    return plant.identityConfirmation != IdentityStatus.confirmed;
  }

  static bool mayRecordScanHistory(Plant plant) {
    return plant.identityConfirmation != IdentityStatus.unconfirmed;
  }

  static bool canCreatePlant(IdentifyAttempt attempt) => attempt.isSuccess;

  static Plant applyCandidate(Plant plant, IdentifyCandidate candidate) {
    return plant.copyWith(
      name: candidate.commonName,
      scientificName: candidate.scientificName,
      identityStatus: IdentityStatusCodec.wireName(IdentityStatus.confirmed),
      toxicity: '',
      alternativeNames: plant.alternativeNames
          .where((name) => !name.toLowerCase().startsWith(
                candidate.commonName.toLowerCase(),
              ))
          .toList(),
    );
  }

  static Map<String, dynamic> identificationEventPayload(
    Plant plant, {
    String confirmationSource = 'model',
  }) {
    return {
      'name': plant.name,
      'scientificName': plant.scientificName,
      if (plant.imagePath != null) 'imagePath': plant.imagePath,
      'confidence': plant.speciesConfidence,
      'identityStatus': plant.identityStatus.isEmpty
          ? IdentityStatusCodec.wireName(plant.identityConfirmation)
          : plant.identityStatus,
      'confirmationSource': confirmationSource,
    };
  }
}
