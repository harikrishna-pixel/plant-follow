/// Placement of a saved plant. Independent of [PlantLocation].
/// Weather eligibility uses [isAffectedByOutdoorConditions] only.
enum PlantWeatherContext {
  unknown,
  indoor,
  outdoorPotted,
  gardenBed,
  greenhouseCovered,
}

extension PlantWeatherContextEligibility on PlantWeatherContext {
  /// Outdoor frost/heat advice only when the plant is known to sit in open air.
  bool get isAffectedByOutdoorConditions {
    switch (this) {
      case PlantWeatherContext.outdoorPotted:
      case PlantWeatherContext.gardenBed:
        return true;
      case PlantWeatherContext.unknown:
      case PlantWeatherContext.indoor:
      case PlantWeatherContext.greenhouseCovered:
        return false;
    }
  }

  String get wireName {
    switch (this) {
      case PlantWeatherContext.unknown:
        return 'unknown';
      case PlantWeatherContext.indoor:
        return 'indoor';
      case PlantWeatherContext.outdoorPotted:
        return 'outdoor_potted';
      case PlantWeatherContext.gardenBed:
        return 'garden_bed';
      case PlantWeatherContext.greenhouseCovered:
        return 'greenhouse_covered';
    }
  }

  String get label {
    switch (this) {
      case PlantWeatherContext.unknown:
        return 'Not set';
      case PlantWeatherContext.indoor:
        return 'Indoor';
      case PlantWeatherContext.outdoorPotted:
        return 'Outdoor pot';
      case PlantWeatherContext.gardenBed:
        return 'Garden bed';
      case PlantWeatherContext.greenhouseCovered:
        return 'Greenhouse / covered';
    }
  }

  String get shortPrompt {
    switch (this) {
      case PlantWeatherContext.unknown:
        return 'Where does this one live?';
      default:
        return label;
    }
  }

  /// Missing or unrecognised stored values default to unknown.
  /// Do not infer indoor/outdoor from species or folders.
  static PlantWeatherContext fromStored(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return PlantWeatherContext.unknown;
    }
    switch (raw.trim()) {
      case 'indoor':
        return PlantWeatherContext.indoor;
      case 'outdoor_potted':
      case 'outdoorPotted':
        return PlantWeatherContext.outdoorPotted;
      case 'garden_bed':
      case 'gardenBed':
        return PlantWeatherContext.gardenBed;
      case 'greenhouse_covered':
      case 'greenhouseCovered':
      case 'greenhouse':
        return PlantWeatherContext.greenhouseCovered;
      case 'unknown':
      default:
        return PlantWeatherContext.unknown;
    }
  }
}
