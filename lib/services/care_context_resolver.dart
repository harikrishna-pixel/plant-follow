import '../model/data_model/care_rule.dart';
import '../model/data_model/plant_context.dart';
import '../model/data_model/plant_location.dart';
import '../model/data_model/plant_model.dart';
import 'care_logic.dart';
import 'care_rule_store.dart';
import 'care_weather_policy.dart';
import 'weather_snapshot.dart';

enum CareContextState {
  due,
  overdue,
  maybeHandledByRain,
  weatherAttention,
  normal,
}

/// Deterministic care context. Derived, not persisted.
class CareContextDecision {
  final CareContextState state;
  final DateTime originalDueAt;
  final String reason;
  final String explanation;
  final String suggestedAction;
  final bool weatherApplied;
  final bool requiresUserConfirmation;
  final bool observedRain;
  final bool forecastRain;
  final bool heatAttention;

  const CareContextDecision({
    required this.state,
    required this.originalDueAt,
    required this.reason,
    required this.explanation,
    required this.suggestedAction,
    required this.weatherApplied,
    required this.requiresUserConfirmation,
    this.observedRain = false,
    this.forecastRain = false,
    this.heatAttention = false,
  });

  bool get isActionable =>
      state == CareContextState.due ||
      state == CareContextState.overdue ||
      state == CareContextState.maybeHandledByRain ||
      state == CareContextState.weatherAttention;

  String todayTitle({
    required String plantName,
    required String careType,
  }) {
    final task = CareLogic.displayType(careType);
    switch (state) {
      case CareContextState.maybeHandledByRain:
        return 'Check $plantName before watering';
      case CareContextState.weatherAttention:
        return 'Check $plantName';
      case CareContextState.overdue:
        return '$task — $plantName';
      case CareContextState.due:
      case CareContextState.normal:
        return '$task — $plantName';
    }
  }

  String get todaySubtitle {
    if (reason.isNotEmpty) return reason;
    return suggestedAction;
  }

  String get primaryCtaLabel {
    if (state == CareContextState.maybeHandledByRain) {
      return 'Rain handled it';
    }
    return 'Done';
  }

  String? get secondaryCtaLabel {
    if (state == CareContextState.maybeHandledByRain) {
      return 'Still needs water';
    }
    return null;
  }
}

/// Pure weather-aware care evaluation. UI-independent.
class CareContextResolver {
  CareContextResolver._();

  static const rainRejectedMetadataKey = 'rainSuggestionRejectedDueAt';

  static CareContextDecision evaluate({
    required Plant plant,
    required CareRule rule,
    PlantLocation? location,
    WeatherSnapshot? weather,
    required DateTime now,
  }) {
    final due = CareLogic.isDue(rule, now);
    final overdue = CareLogic.isOverdue(rule, now);
    final watering = CareTypeNormalizer.isWatering(rule.careType);
    final base = _baseDecision(rule: rule, due: due, overdue: overdue, now: now);

    if (!watering) return base;

    final placement = plant.placement;
    if (!_weatherMayAdjustCare(placement)) {
      return base;
    }

    if (location == null) {
      return base;
    }

    if (weather == null || !weather.isFreshAt(now)) {
      return base;
    }

    if (weather.locationId.isNotEmpty && weather.locationId != location.id) {
      return base;
    }

    final rejected = _rainRejectedFor(rule);
    final observedRain = weather.hasMeaningfulObservedRain;
    final forecastRain = weather.forecastRainExpected;
    final heat = CareWeatherPolicy.isHeatAttention(
      temperatureC: weather.temperatureC,
      outdoorPotted: placement == PlantWeatherContext.outdoorPotted,
      gardenBed: placement == PlantWeatherContext.gardenBed,
    );

    if (due && observedRain && !rejected) {
      final locationName = location.name.trim();
      final place = locationName.isEmpty ? 'this location' : locationName;
      return CareContextDecision(
        state: CareContextState.maybeHandledByRain,
        originalDueAt: rule.nextDueAt,
        reason: 'Rain may have handled this.',
        explanation:
            'Rain was recorded near $place. Because this plant is outdoors, we\'re asking you to check before watering.',
        suggestedAction: 'Check the soil before watering.',
        weatherApplied: true,
        requiresUserConfirmation: true,
        observedRain: true,
        forecastRain: forecastRain,
        heatAttention: heat,
      );
    }

    if (!due) {
      if (heat && _dueSoon(rule.nextDueAt, now)) {
        return CareContextDecision(
          state: CareContextState.normal,
          originalDueAt: rule.nextDueAt,
          reason: placement == PlantWeatherContext.outdoorPotted
              ? 'Hot weather may dry this outdoor pot sooner.'
              : 'Hot weather may dry this garden bed sooner.',
          explanation:
              'It\'s hot near this plant\'s location. Containers and beds can dry faster — check the soil, don\'t assume it needs water.',
          suggestedAction: 'Check the soil',
          weatherApplied: true,
          requiresUserConfirmation: false,
          heatAttention: true,
          forecastRain: forecastRain,
        );
      }
      return base;
    }

    if (heat) {
      return CareContextDecision(
        state: CareContextState.weatherAttention,
        originalDueAt: rule.nextDueAt,
        reason: 'Hot day — check soil',
        explanation: placement == PlantWeatherContext.outdoorPotted
            ? 'Your outdoor pot may dry faster today. Check the soil before watering.'
            : 'Hot weather may dry this garden bed faster. Check the soil before watering.',
        suggestedAction: 'Check the soil',
        weatherApplied: true,
        requiresUserConfirmation: false,
        heatAttention: true,
        forecastRain: forecastRain,
        observedRain: false,
      );
    }

    if (forecastRain) {
      return CareContextDecision(
        state: overdue ? CareContextState.overdue : CareContextState.due,
        originalDueAt: rule.nextDueAt,
        reason: 'Rain expected later. Check before watering.',
        explanation:
            'Rain is in the forecast. That is only a prediction — watering is still yours to decide.',
        suggestedAction: 'Check before watering.',
        weatherApplied: true,
        requiresUserConfirmation: false,
        forecastRain: true,
      );
    }

    return base;
  }

  static bool _weatherMayAdjustCare(PlantWeatherContext placement) {
    return placement == PlantWeatherContext.outdoorPotted ||
        placement == PlantWeatherContext.gardenBed;
  }

  static bool _dueSoon(DateTime nextDueAt, DateTime now) {
    final dueDay = DateTime(nextDueAt.year, nextDueAt.month, nextDueAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return !dueDay.isAfter(today.add(const Duration(days: 2)));
  }

  static bool _rainRejectedFor(CareRule rule) {
    final stored = rule.metadata[rainRejectedMetadataKey];
    if (stored is! String || stored.isEmpty) return false;
    return stored == CareWeatherPolicy.occurrenceDayKey(rule.nextDueAt);
  }

  static CareRule withRainSuggestionRejected(CareRule rule) {
    final metadata = Map<String, dynamic>.from(rule.metadata);
    metadata[rainRejectedMetadataKey] =
        CareWeatherPolicy.occurrenceDayKey(rule.nextDueAt);
    return rule.copyWith(metadata: metadata);
  }

  static Map<String, dynamic> rainConfirmedPayload({
    PlantLocation? location,
    WeatherSnapshot? weather,
  }) {
    return {
      'completionSource': 'observed_rain_user_confirmed',
      'weatherContext': 'rain',
      if (location != null) 'locationId': location.id,
      if (weather?.precipitationMm != null)
        'observedPrecipitation': weather!.precipitationMm,
      if (weather != null)
        'weatherObservedAt': weather.observedAt.toIso8601String(),
      if (weather != null && weather.condition.isNotEmpty)
        'weatherCondition': weather.condition,
    };
  }

  static CareContextDecision _baseDecision({
    required CareRule rule,
    required bool due,
    required bool overdue,
    required DateTime now,
  }) {
    if (overdue) {
      return CareContextDecision(
        state: CareContextState.overdue,
        originalDueAt: rule.nextDueAt,
        reason: CareLogic.whyDue(rule, now),
        explanation: CareLogic.whyDue(rule, now),
        suggestedAction: 'Mark done when you can.',
        weatherApplied: false,
        requiresUserConfirmation: false,
      );
    }
    if (due) {
      return CareContextDecision(
        state: CareContextState.due,
        originalDueAt: rule.nextDueAt,
        reason: CareLogic.whyDue(rule, now),
        explanation: CareLogic.whyDue(rule, now),
        suggestedAction: 'Mark done when you can.',
        weatherApplied: false,
        requiresUserConfirmation: false,
      );
    }
    return CareContextDecision(
      state: CareContextState.normal,
      originalDueAt: rule.nextDueAt,
      reason: '',
      explanation: '',
      suggestedAction: '',
      weatherApplied: false,
      requiresUserConfirmation: false,
    );
  }
}
