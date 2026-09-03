import '../model/data_model/plant_model.dart';

/// User-facing botanical candidate. Never fabricated locally.
class IdentifyCandidate {
  final String commonName;
  final String scientificName;
  final SpeciesConfidence? confidence;

  const IdentifyCandidate({
    required this.commonName,
    this.scientificName = '',
    this.confidence,
  });

  String get label {
    if (scientificName.trim().isEmpty) return commonName;
    return '$commonName ($scientificName)';
  }

  static IdentifyCandidate? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^(.*)\s+\((.+)\)\s*$').firstMatch(text);
    if (match != null) {
      final common = match.group(1)!.trim();
      final scientific = match.group(2)!.trim();
      if (common.isEmpty) return null;
      return IdentifyCandidate(
        commonName: common,
        scientificName: scientific,
      );
    }
    return IdentifyCandidate(commonName: text);
  }
}

enum ImageQualityKind {
  ok,
  blurry,
  dark,
  tooSmall,
  multiplePlants,
  lowDetail,
  notAPlant,
  unknown,
}

class ImageQualityCodec {
  ImageQualityCodec._();

  static ImageQualityKind fromWire(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'ok':
      case 'good':
      case 'clear':
        return ImageQualityKind.ok;
      case 'blurry':
      case 'too_blurry':
        return ImageQualityKind.blurry;
      case 'dark':
      case 'too_dark':
        return ImageQualityKind.dark;
      case 'too_small':
      case 'plant_too_small':
        return ImageQualityKind.tooSmall;
      case 'multiple_plants':
      case 'multiple':
        return ImageQualityKind.multiplePlants;
      case 'low_detail':
      case 'not_enough_detail':
        return ImageQualityKind.lowDetail;
      case 'not_a_plant':
        return ImageQualityKind.notAPlant;
      default:
        return ImageQualityKind.unknown;
    }
  }
}

enum SafetyKind { toxic, nonToxic, unknown }

class PlantSafety {
  final SafetyKind status;
  final SafetyKind cats;
  final SafetyKind dogs;
  final SafetyKind humans;
  final String summary;
  final String details;

  const PlantSafety({
    required this.status,
    this.cats = SafetyKind.unknown,
    this.dogs = SafetyKind.unknown,
    this.humans = SafetyKind.unknown,
    this.summary = '',
    this.details = '',
  });

  static const unknown = PlantSafety(status: SafetyKind.unknown);

  bool get isUnknown => status == SafetyKind.unknown;
  bool get isToxic => status == SafetyKind.toxic;
  bool get isNonToxic => status == SafetyKind.nonToxic;

  /// Missing data is unknown, never "safe".
  String get headline {
    switch (status) {
      case SafetyKind.toxic:
        return 'Toxic if ingested';
      case SafetyKind.nonToxic:
        return 'Generally non-toxic';
      case SafetyKind.unknown:
        return 'Safety information unavailable';
    }
  }

  String supportingCopy({required bool identificationUncertain}) {
    if (status == SafetyKind.unknown) {
      return '';
    }
    if (identificationUncertain) {
      if (status == SafetyKind.toxic) {
        return 'If this identification is correct, this plant may be toxic to pets.';
      }
      return 'If this identification is correct, this plant is generally considered non-toxic.';
    }
    if (status == SafetyKind.toxic) {
      return _petLine();
    }
    return summary.trim();
  }

  String _petLine() {
    final pets = <String>[];
    if (cats == SafetyKind.toxic) pets.add('cats');
    if (dogs == SafetyKind.toxic) pets.add('dogs');
    if (pets.isEmpty) {
      return 'Keep away from cats and dogs.';
    }
    return 'Keep away from ${pets.join(' and ')}.';
  }

  static SafetyKind kindFromWire(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'toxic':
      case 'poisonous':
      case 'known_toxic':
        return SafetyKind.toxic;
      case 'non_toxic':
      case 'non-toxic':
      case 'nontoxic':
      case 'safe':
      case 'known_non_toxic':
        return SafetyKind.nonToxic;
      default:
        return SafetyKind.unknown;
    }
  }

  static SafetyKind kindFromToxicityText(String? toxicity) {
    final text = (toxicity ?? '').trim();
    if (text.isEmpty) return SafetyKind.unknown;
    final lower = text.toLowerCase();
    final nonToxic = RegExp(
      r'\bnon[-\s]?toxic\b|\bnot toxic\b|\bsafe for (cats|dogs|pets|humans|children)\b',
    );
    if (nonToxic.hasMatch(lower)) return SafetyKind.nonToxic;
    if (RegExp(r'\btoxic\b|\bpoison').hasMatch(lower)) {
      return SafetyKind.toxic;
    }
    return SafetyKind.unknown;
  }

  static PlantSafety fromIdentificationJson(Map<String, dynamic> json) {
    final structured = json['safety'];
    if (structured is Map) {
      final map = Map<String, dynamic>.from(structured);
      return PlantSafety(
        status: kindFromWire(map['status'] ?? map['toxicity']),
        cats: kindFromWire(map['cats'] ?? map['cat']),
        dogs: kindFromWire(map['dogs'] ?? map['dog']),
        humans: kindFromWire(map['humans'] ?? map['human']),
        summary: (map['summary'] ?? '').toString().trim(),
        details: (map['details'] ?? map['summary'] ?? '').toString().trim(),
      );
    }
    return fromToxicityText(json['toxicity']?.toString());
  }

  static PlantSafety fromToxicityText(String? toxicity) {
    final text = (toxicity ?? '').trim();
    return PlantSafety(
      status: kindFromToxicityText(text),
      details: text,
      summary: text,
    );
  }

  static PlantSafety fromPlant(Plant plant) =>
      fromToxicityText(plant.toxicity);
}

/// Typed identification contract. Confidence stays qualitative unless
/// an upstream system supplies a calibrated probability (this app does not).
class IdentificationResult {
  static const maxAlternatives = 3;
  static const maxRetryTips = 3;

  final String commonName;
  final String scientificName;
  final SpeciesConfidence confidence;
  final double? confidenceScore;
  final List<IdentifyCandidate> alternatives;
  final String evidenceSummary;
  final PlantSafety safety;
  final ImageQualityKind imageQuality;
  final List<String> retryTips;
  final IdentityStatus identityStatus;
  final String? confirmationSource;

  const IdentificationResult({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    this.confidenceScore,
    this.alternatives = const [],
    this.evidenceSummary = '',
    this.safety = PlantSafety.unknown,
    this.imageQuality = ImageQualityKind.unknown,
    this.retryTips = const [],
    required this.identityStatus,
    this.confirmationSource,
  });

  bool get isHigh =>
      identityStatus == IdentityStatus.confirmed &&
      confidence == SpeciesConfidence.high;

  bool get isMedium => identityStatus == IdentityStatus.likely;

  bool get isLow => identityStatus == IdentityStatus.unconfirmed;

  bool get isConfirmedIdentity =>
      identityStatus == IdentityStatus.confirmed;

  bool get allowsDirectSave =>
      identityStatus == IdentityStatus.confirmed ||
      identityStatus == IdentityStatus.likely;

  bool get allowsConfirmedSave =>
      identityStatus == IdentityStatus.confirmed;

  bool get mayRecordScanHistory => allowsDirectSave;

  bool get identificationUncertain =>
      identityStatus != IdentityStatus.confirmed;

  String get titlePrefix {
    switch (identityStatus) {
      case IdentityStatus.confirmed:
        return 'Identified as';
      case IdentityStatus.likely:
        return 'Likely';
      case IdentityStatus.unconfirmed:
        return 'Not sure yet';
    }
  }

  String get displayedName {
    switch (identityStatus) {
      case IdentityStatus.confirmed:
      case IdentityStatus.likely:
        return commonName;
      case IdentityStatus.unconfirmed:
        return 'Not sure yet';
    }
  }

  String get confidenceChipLabel {
    switch (identityStatus) {
      case IdentityStatus.confirmed:
        return 'Strong match';
      case IdentityStatus.likely:
        return 'Likely match';
      case IdentityStatus.unconfirmed:
        return 'Needs another look';
    }
  }

  String get supportingCopy {
    switch (identityStatus) {
      case IdentityStatus.confirmed:
        return '';
      case IdentityStatus.likely:
        return "We're not fully sure yet.";
      case IdentityStatus.unconfirmed:
        return 'Try another photo so we can take a closer look.';
    }
  }

  String get primaryActionLabel {
    switch (identityStatus) {
      case IdentityStatus.confirmed:
        return 'Save';
      case IdentityStatus.likely:
        return 'Save as Likely Match';
      case IdentityStatus.unconfirmed:
        return 'Try another photo';
    }
  }

  String get secondaryActionLabel {
    switch (identityStatus) {
      case IdentityStatus.confirmed:
        return '';
      case IdentityStatus.likely:
        return 'Try another photo';
      case IdentityStatus.unconfirmed:
        return alternatives.isEmpty ? '' : 'Review possible matches';
    }
  }

  static IdentityStatus statusForConfidence(SpeciesConfidence confidence) {
    switch (confidence) {
      case SpeciesConfidence.high:
        return IdentityStatus.confirmed;
      case SpeciesConfidence.medium:
        return IdentityStatus.likely;
      case SpeciesConfidence.low:
        return IdentityStatus.unconfirmed;
      case SpeciesConfidence.unknown:
        return IdentityStatus.likely;
    }
  }

  static List<String> retryTipsFor(ImageQualityKind quality) {
    switch (quality) {
      case ImageQualityKind.blurry:
        return const [
          'Keep the plant in focus.',
          'Photograph a leaf, flower, or the whole plant.',
          'Use natural light when possible.',
        ];
      case ImageQualityKind.dark:
        return const [
          'Use natural light when possible.',
          'Fill the frame with one plant.',
          'Keep the plant in focus.',
        ];
      case ImageQualityKind.tooSmall:
        return const [
          'Fill the frame with one plant.',
          'Photograph a leaf, flower, or the whole plant.',
          'Keep the plant in focus.',
        ];
      case ImageQualityKind.multiplePlants:
        return const [
          'Fill the frame with one plant.',
          'Photograph a leaf, flower, or the whole plant.',
          'Keep the plant in focus.',
        ];
      case ImageQualityKind.lowDetail:
        return const [
          'Photograph a leaf, flower, or the whole plant.',
          'Fill the frame with one plant.',
          'Use natural light when possible.',
        ];
      case ImageQualityKind.notAPlant:
        return const [
          'Photograph a leaf, flower, or the whole plant.',
          'Fill the frame with one plant.',
          'Use natural light when possible.',
        ];
      case ImageQualityKind.ok:
        return const [];
      case ImageQualityKind.unknown:
        return const [
          'Fill the frame with one plant.',
          'Photograph a leaf, flower, or the whole plant.',
          'Keep the plant in focus.',
        ];
    }
  }

  static String imageQualityCopy(ImageQualityKind quality) {
    switch (quality) {
      case ImageQualityKind.blurry:
        return 'This photo looks a bit blurry.';
      case ImageQualityKind.dark:
        return 'This photo looks a bit dark.';
      case ImageQualityKind.tooSmall:
        return 'The plant is a bit small in the frame.';
      case ImageQualityKind.multiplePlants:
        return 'Several plants are sharing this photo.';
      case ImageQualityKind.lowDetail:
        return 'We need a clearer view.';
      case ImageQualityKind.notAPlant:
        return 'We couldn\'t find enough plant detail.';
      case ImageQualityKind.ok:
        return '';
      case ImageQualityKind.unknown:
        return 'We need a clearer view.';
    }
  }

  static IdentificationResult fromPlant(Plant plant) {
    final alternatives = plant.alternativeNames
        .map(IdentifyCandidate.tryParse)
        .whereType<IdentifyCandidate>()
        .take(maxAlternatives)
        .toList();
    return IdentificationResult(
      commonName: plant.name,
      scientificName: plant.scientificName,
      confidence: plant.identificationConfidence,
      alternatives: alternatives,
      safety: PlantSafety.fromPlant(plant),
      identityStatus: plant.identityConfirmation,
      retryTips: plant.identityConfirmation == IdentityStatus.confirmed
          ? const []
          : retryTipsFor(ImageQualityKind.unknown),
    );
  }

  IdentificationResult withSelectedCandidate(IdentifyCandidate candidate) {
    return IdentificationResult(
      commonName: candidate.commonName,
      scientificName: candidate.scientificName,
      confidence: confidence,
      confidenceScore: null,
      alternatives: alternatives
          .where((item) => item.commonName != candidate.commonName)
          .take(maxAlternatives)
          .toList(),
      evidenceSummary: evidenceSummary,
      safety: PlantSafety.unknown,
      imageQuality: imageQuality,
      retryTips: const [],
      identityStatus: IdentityStatus.confirmed,
      confirmationSource: 'user_selected',
    );
  }
}

/// Prevents duplicate Analyze requests from repeated taps.
class IdentifyRequestGuard {
  bool _inFlight = false;

  bool get isInFlight => _inFlight;

  bool tryStart() {
    if (_inFlight) return false;
    _inFlight = true;
    return true;
  }

  void finish() {
    _inFlight = false;
  }
}
