import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/care_rule.dart';
import 'package:plantidentifier/model/data_model/plant_context.dart';
import 'package:plantidentifier/model/data_model/plant_event.dart';
import 'package:plantidentifier/model/data_model/plant_location.dart';
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/services/care_context_resolver.dart';
import 'package:plantidentifier/services/care_logic.dart';
import 'package:plantidentifier/services/care_weather_policy.dart';
import 'package:plantidentifier/services/grow_logic.dart';
import 'package:plantidentifier/services/location_weather_cache.dart';
import 'package:plantidentifier/services/recovery_logic.dart';
import 'package:plantidentifier/services/today_priority.dart';
import 'package:plantidentifier/services/weather_snapshot.dart';

Plant _plant({
  String id = 'plant-1',
  String name = 'Basil',
  PlantWeatherContext placement = PlantWeatherContext.outdoorPotted,
  String? locationId = 'loc-home',
}) {
  return Plant(
    id: id,
    name: name,
    scientificName: 'Ocimum basilicum',
    description: 'A garden herb.',
    taxonomy: const {},
    nativeRegion: '',
    growthSeason: '',
    toxicity: '',
    careGuide: const {},
    healthScan: '',
    commonPests: '',
    commonDiseases: '',
    usage: '',
    funFact: '',
    placement: placement,
    locationId: locationId,
  );
}

CareRule _rule({
  String id = 'rule-1',
  String plantId = 'plant-1',
  DateTime? nextDueAt,
  DateTime? lastCompletedAt,
  String careType = 'Watering',
  Map<String, dynamic>? metadata,
}) {
  return CareRule(
    id: id,
    plantId: plantId,
    careType: careType,
    baseIntervalDays: 7,
    lastCompletedAt: lastCompletedAt,
    nextDueAt: nextDueAt ?? DateTime(2026, 9, 1, 9),
    metadata: metadata,
  );
}

PlantLocation _home() {
  return PlantLocation(
    id: 'loc-home',
    name: 'Home',
    city: 'Tiruppur',
    createdAt: DateTime(2026, 1, 1),
  );
}

WeatherSnapshot _weather({
  String locationId = 'loc-home',
  DateTime? observedAt,
  double temperatureC = 24,
  double? rain1hMm,
  String condition = '',
  bool forecastRain = false,
  double? forecastTemp,
}) {
  return WeatherSnapshot(
    locationId: locationId,
    observedAt: observedAt ?? DateTime(2026, 9, 1, 8),
    temperatureC: temperatureC,
    rain1hMm: rain1hMm,
    condition: condition,
    forecastRainExpected: forecastRain,
    forecastTemperatureC: forecastTemp,
  );
}

void main() {
  final now = DateTime(2026, 9, 1, 10);

  group('Placement eligibility', () {
    test('indoor plant ignores observed rain for care completion', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(placement: PlantWeatherContext.indoor),
        rule: _rule(),
        location: _home(),
        weather: _weather(rain1hMm: 5, condition: 'Rain'),
        now: now,
      );
      expect(decision.state, CareContextState.due);
      expect(decision.weatherApplied, isFalse);
      expect(decision.requiresUserConfirmation, isFalse);
    });

    test('unknown placement ignores weather adjustment', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(placement: PlantWeatherContext.unknown),
        rule: _rule(),
        location: _home(),
        weather: _weather(rain1hMm: 8, condition: 'Rain'),
        now: now,
      );
      expect(decision.weatherApplied, isFalse);
      expect(decision.state, CareContextState.due);
    });

    test('greenhouse-covered plant does not assume outside rain reached it', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(placement: PlantWeatherContext.greenhouseCovered),
        rule: _rule(),
        location: _home(),
        weather: _weather(rain1hMm: 12, condition: 'Rain'),
        now: now,
      );
      expect(decision.weatherApplied, isFalse);
      expect(decision.state, isNot(CareContextState.maybeHandledByRain));
    });
  });

  group('Observed rain', () {
    test('outdoor-potted due watering + rain produces check state', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(placement: PlantWeatherContext.outdoorPotted),
        rule: _rule(),
        location: _home(),
        weather: _weather(rain1hMm: 3, condition: 'Rain'),
        now: now,
      );
      expect(decision.state, CareContextState.maybeHandledByRain);
      expect(decision.requiresUserConfirmation, isTrue);
      expect(decision.reason, 'Rain may have handled this.');
      expect(decision.suggestedAction, contains('Check the soil'));
    });

    test('garden-bed due watering + rain produces check state', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(placement: PlantWeatherContext.gardenBed),
        rule: _rule(),
        location: _home(),
        weather: _weather(condition: 'Rain'),
        now: now,
      );
      expect(decision.state, CareContextState.maybeHandledByRain);
      expect(decision.weatherApplied, isTrue);
    });

    test('observed rain never automatically appends care_completion', () {
      final rule = _rule();
      CareContextResolver.evaluate(
        plant: _plant(),
        rule: rule,
        location: _home(),
        weather: _weather(rain1hMm: 6),
        now: now,
      );
      expect(rule.lastCompletedAt, isNull);
      expect(rule.nextDueAt, DateTime(2026, 9, 1, 9));
    });
  });

  group('Forecast rain', () {
    test('forecast rain never marks care complete or handled', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(),
        rule: _rule(),
        location: _home(),
        weather: _weather(forecastRain: true, temperatureC: 22),
        now: now,
      );
      expect(decision.state, isNot(CareContextState.maybeHandledByRain));
      expect(decision.forecastRain, isTrue);
      expect(decision.reason, contains('Rain expected later'));
      expect(decision.requiresUserConfirmation, isFalse);
    });
  });

  group('User confirmation', () {
    test('Rain Handled It completes via existing next-due calculation', () {
      final rule = _rule(lastCompletedAt: DateTime(2026, 8, 25, 10));
      final applied = CareLogic.completeWithEvent(
        rule,
        now,
        extraPayload: CareContextResolver.rainConfirmedPayload(
          location: _home(),
          weather: _weather(rain1hMm: 4, condition: 'Rain'),
        ),
      );
      expect(applied.rule.nextDueAt, DateTime(2026, 9, 8));
      expect(applied.rule.lastCompletedAt, now);
      expect(applied.event.eventType, PlantEventType.careCompletion);
      expect(
        applied.event.payload['completionSource'],
        'observed_rain_user_confirmed',
      );
      expect(applied.event.payload['weatherContext'], 'rain');
      expect(applied.event.payload['locationId'], 'loc-home');
    });

    test('rain-confirmed completion appends one event only', () {
      final applied = CareLogic.completeWithEvent(
        _rule(),
        now,
        extraPayload: CareContextResolver.rainConfirmedPayload(),
      );
      expect(applied.event.eventType, PlantEventType.careCompletion);
      expect(applied.event.payload['careRuleId'], 'rule-1');
    });

    test('Still Needs Water keeps care actionable and stops rain nag', () {
      final rule = _rule();
      final rejected = CareContextResolver.withRainSuggestionRejected(rule);
      final again = CareContextResolver.evaluate(
        plant: _plant(),
        rule: rejected,
        location: _home(),
        weather: _weather(rain1hMm: 5, condition: 'Rain'),
        now: now,
      );
      expect(CareLogic.isDue(rejected, now), isTrue);
      expect(again.state, isNot(CareContextState.maybeHandledByRain));
      expect(again.isActionable, isTrue);
      expect(rejected.lastCompletedAt, isNull);
    });
  });

  group('Heat', () {
    test('hot weather does not automatically complete watering', () {
      final rule = _rule();
      final decision = CareContextResolver.evaluate(
        plant: _plant(),
        rule: rule,
        location: _home(),
        weather: _weather(temperatureC: 36),
        now: now,
      );
      expect(rule.lastCompletedAt, isNull);
      expect(decision.state, isNot(CareContextState.maybeHandledByRain));
    });

    test('hot outdoor pot can produce heat attention', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(placement: PlantWeatherContext.outdoorPotted),
        rule: _rule(),
        location: _home(),
        weather: _weather(temperatureC: 33),
        now: now,
      );
      expect(decision.heatAttention, isTrue);
      expect(decision.weatherApplied, isTrue);
      expect(decision.reason, contains('check soil'));
      expect(decision.suggestedAction.toLowerCase(), contains('check the soil'));
    });

    test('indoor plant does not get external heat-based watering modification',
        () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(placement: PlantWeatherContext.indoor),
        rule: _rule(),
        location: _home(),
        weather: _weather(temperatureC: 40),
        now: now,
      );
      expect(decision.weatherApplied, isFalse);
      expect(decision.heatAttention, isFalse);
    });
  });

  group('Fallback', () {
    test('weather failure falls back to normal CareRule', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(),
        rule: _rule(),
        location: _home(),
        weather: null,
        now: now,
      );
      expect(decision.state, CareContextState.due);
      expect(decision.weatherApplied, isFalse);
    });

    test('missing Location falls back to normal CareRule', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(locationId: null),
        rule: _rule(),
        location: null,
        weather: _weather(rain1hMm: 9, condition: 'Rain'),
        now: now,
      );
      expect(decision.weatherApplied, isFalse);
      expect(decision.state, CareContextState.due);
    });

    test('stale weather does not affect care', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(),
        rule: _rule(),
        location: _home(),
        weather: _weather(
          observedAt: DateTime(2026, 8, 31, 10),
          rain1hMm: 10,
          condition: 'Rain',
        ),
        now: now,
      );
      expect(CareWeatherPolicy.isFresh(DateTime(2026, 8, 31, 10), now), isFalse);
      expect(decision.weatherApplied, isFalse);
    });
  });

  group('Locations and cache', () {
    test('multiple plant Locations resolve weather independently', () {
      final home = _weather(locationId: 'loc-home', rain1hMm: 5, condition: 'Rain');
      final farm = _weather(
        locationId: 'loc-farm',
        temperatureC: 22,
        condition: 'Clear',
      );
      final homeDecision = CareContextResolver.evaluate(
        plant: _plant(id: 'p-home', locationId: 'loc-home'),
        rule: _rule(id: 'r-home', plantId: 'p-home'),
        location: _home(),
        weather: home,
        now: now,
      );
      final farmDecision = CareContextResolver.evaluate(
        plant: _plant(
          id: 'p-farm',
          locationId: 'loc-farm',
          placement: PlantWeatherContext.gardenBed,
        ),
        rule: _rule(id: 'r-farm', plantId: 'p-farm'),
        location: PlantLocation(
          id: 'loc-farm',
          name: 'Farm',
          createdAt: DateTime(2026, 1, 1),
        ),
        weather: farm,
        now: now,
      );
      expect(homeDecision.state, CareContextState.maybeHandledByRain);
      expect(farmDecision.state, isNot(CareContextState.maybeHandledByRain));
    });

    test('weather cache does not fetch twice for a shared Location', () async {
      final cache = LocationWeatherCache(
        clock: () => now,
        ttl: CareWeatherPolicy.cacheTtl,
      );
      var loads = 0;
      Future<WeatherSnapshot?> loader(PlantLocation location) async {
        loads++;
        return _weather(locationId: location.id);
      }

      final location = _home();
      await cache.getOrFetch(location: location, loader: loader, now: now);
      await cache.getOrFetch(location: location, loader: loader, now: now);
      expect(loads, 1);
      expect(cache.fetchCount, 1);
    });
  });

  group('Today integration', () {
    test('Today remains max 3 cards with weather-adjusted care', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: [
          RecoveryCase(
            id: 'c1',
            plantId: 'p1',
            diagnosisId: 'd1',
            treatmentId: 't1',
            openedAt: DateTime(2026, 8, 29),
            status: RecoveryCaseStatus.awaitingDay3,
            day3DueAt: RecoveryLogic.day3DueAt(DateTime(2026, 8, 29)),
            day7DueAt: RecoveryLogic.day7DueAt(DateTime(2026, 8, 29)),
          ),
        ],
        plantNames: {'p1': 'Basil', 'p2': 'Rose', 'p3': 'Mint'},
        careRules: [
          _rule(id: 'r1', plantId: 'p1'),
          _rule(id: 'r2', plantId: 'p2'),
          _rule(id: 'r3', plantId: 'p3'),
        ],
        plants: [
          _plant(id: 'p1'),
          _plant(id: 'p2', name: 'Rose'),
          _plant(id: 'p3', name: 'Mint'),
        ],
        locationsById: {'loc-home': _home()},
        weatherByLocationId: {
          'loc-home': _weather(rain1hMm: 4, condition: 'Rain'),
        },
        weather: const TodayWeatherSnapshot(temperatureC: 40),
        plantWeatherContexts: const [PlantWeatherContext.outdoorPotted],
      );
      expect(result.cards.length, lessThanOrEqualTo(3));
      expect(result.cards.first.kind, TodayActionKind.recovery);
    });

    test('recovery still outranks care/weather', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: [
          RecoveryCase(
            id: 'c1',
            plantId: 'plant-1',
            diagnosisId: 'd1',
            treatmentId: 't1',
            openedAt: DateTime(2026, 8, 29),
            status: RecoveryCaseStatus.awaitingDay3,
            day3DueAt: RecoveryLogic.day3DueAt(DateTime(2026, 8, 29)),
            day7DueAt: RecoveryLogic.day7DueAt(DateTime(2026, 8, 29)),
          ),
        ],
        plantNames: {'plant-1': 'Basil'},
        careRules: [_rule()],
        plants: [_plant()],
        locationsById: {'loc-home': _home()},
        weatherByLocationId: {
          'loc-home': _weather(rain1hMm: 5, condition: 'Rain'),
        },
      );
      expect(result.cards.first.kind, TodayActionKind.recovery);
    });

    test('weather does not create duplicate Today cards for the same care', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: const [],
        plantNames: {'plant-1': 'Basil'},
        careRules: [_rule()],
        plants: [_plant()],
        locationsById: {'loc-home': _home()},
        weatherByLocationId: {
          'loc-home': _weather(
            rain1hMm: 5,
            condition: 'Rain',
            temperatureC: 40,
          ),
        },
        weather: const TodayWeatherSnapshot(temperatureC: 40),
        plantWeatherContexts: const [PlantWeatherContext.outdoorPotted],
      );
      expect(result.cards.where((c) => c.kind == TodayActionKind.care).length, 1);
      expect(
        result.cards.any((c) => c.kind == TodayActionKind.weather),
        isFalse,
      );
      expect(result.cards.single.careContext, CareContextState.maybeHandledByRain);
    });

    test('Today empty state remains valid when nothing needs action', () {
      final result = TodayPriorityResolver.resolve(
        now: now,
        cases: const [],
        plantNames: {'plant-1': 'Basil'},
        careRules: [_rule(nextDueAt: DateTime(2026, 9, 8))],
        plants: [_plant()],
        weather: const TodayWeatherSnapshot(temperatureC: 22),
        plantWeatherContexts: const [PlantWeatherContext.outdoorPotted],
      );
      expect(result.isEmpty, isTrue);
      expect(TodayPriorityResult.emptyTitle, 'Nothing needed today');
    });
  });

  group('Boundaries', () {
    test('manual Mark Done remains unchanged without extra payload', () {
      final applied = CareLogic.completeWithEvent(_rule(), now);
      expect(applied.event.payload.containsKey('completionSource'), isFalse);
      expect(applied.rule.nextDueAt, DateTime(2026, 9, 8));
    });

    test('weather confirmation reuses reminder id on the rule', () {
      final rule = _rule();
      final withReminder = rule.copyWith(reminderId: 'rem-1');
      final applied = CareLogic.completeWithEvent(
        withReminder,
        now,
        extraPayload: CareContextResolver.rainConfirmedPayload(),
      );
      expect(applied.event.payload['reminderId'], 'rem-1');
      expect(applied.rule.reminderId, 'rem-1');
    });

    test('weather context does not modify recovery due calculation', () {
      final opened = DateTime(2026, 8, 29);
      final recovery = RecoveryCase(
        id: 'c1',
        plantId: 'plant-1',
        diagnosisId: 'd1',
        treatmentId: 't1',
        openedAt: opened,
        status: RecoveryCaseStatus.awaitingDay3,
        day3DueAt: RecoveryLogic.day3DueAt(opened),
        day7DueAt: RecoveryLogic.day7DueAt(opened),
      );
      expect(RecoveryLogic.checkInDue(recovery, now)?.stage, CheckInStage.day3);
    });

    test('weather context does not modify Grow Plan anchors', () {
      final actions = GrowLogic.dueActions(
        now: now,
        plants: [_plant()],
        plans: const [],
        harvests: const [],
      );
      expect(actions, isEmpty);
    });

    test('no soil-moisture value is fabricated', () {
      final decision = CareContextResolver.evaluate(
        plant: _plant(),
        rule: _rule(),
        location: _home(),
        weather: _weather(rain1hMm: 5, condition: 'Rain'),
        now: now,
      );
      expect(decision.reason.contains('%'), isFalse);
      expect(decision.explanation.toLowerCase().contains('soil moisture'), isFalse);
      expect(decision.explanation.toLowerCase().contains('soil is wet'), isFalse);
      expect(decision.suggestedAction.toLowerCase().contains('soil is dry'), isFalse);
    });
  });
}
