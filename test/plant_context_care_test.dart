import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/care_rule.dart';
import 'package:plantidentifier/model/data_model/plant_event.dart';
import 'package:plantidentifier/model/data_model/plant_location.dart';
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/model/data_model/reminder_model.dart';
import 'package:plantidentifier/services/care_logic.dart';
import 'package:plantidentifier/services/care_rule_store.dart';
import 'package:plantidentifier/services/recovery_logic.dart';
import 'package:plantidentifier/services/today_priority.dart';

Plant _plant({
  String? id,
  String name = 'Monstera',
  PlantWeatherContext placement = PlantWeatherContext.unknown,
  String? locationId,
}) {
  return Plant(
    id: id ?? 'plant-1',
    name: name,
    scientificName: 'Monstera deliciosa',
    description: 'A tropical climbing plant.',
    taxonomy: const {},
    nativeRegion: 'Central America',
    growthSeason: 'Year-round',
    toxicity: 'Toxic to pets',
    careGuide: const {},
    healthScan: 'Healthy',
    commonPests: 'Spider mites',
    commonDiseases: 'Root rot',
    usage: 'Decorative',
    funFact: 'Swiss cheese plant',
    imagePath: '/tmp/monstera.jpg',
    placement: placement,
    locationId: locationId,
  );
}

RecoveryCase _recoveryCase() {
  final opened = DateTime(2026, 8, 29);
  return RecoveryCase(
    id: 'case-1',
    plantId: 'plant-1',
    diagnosisId: 'diag-1',
    treatmentId: 'treat-1',
    openedAt: opened,
    status: RecoveryCaseStatus.awaitingDay3,
    day3DueAt: RecoveryLogic.day3DueAt(opened),
    day7DueAt: RecoveryLogic.day7DueAt(opened),
  );
}

CareRule _rule({
  String id = 'rule-1',
  String plantId = 'plant-1',
  DateTime? nextDueAt,
  DateTime? lastCompletedAt,
  String? reminderId,
}) {
  return CareRule(
    id: id,
    plantId: plantId,
    careType: 'Watering',
    baseIntervalDays: 7,
    lastCompletedAt: lastCompletedAt,
    nextDueAt: nextDueAt ?? DateTime(2026, 9, 1, 9),
    reminderId: reminderId,
  );
}

void main() {
  group('Context migration', () {
    test('legacy Plant without context defaults to unknown', () {
      expect(
        PlantWeatherContextEligibility.fromStored(null),
        PlantWeatherContext.unknown,
      );
      expect(
        PlantWeatherContextEligibility.fromStored(''),
        PlantWeatherContext.unknown,
      );
      final plant = Plant(
        name: 'Fern',
        scientificName: '',
        description: 'Legacy record',
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
      );
      expect(plant.placement, PlantWeatherContext.unknown);
      expect(plant.locationId, isNull);
    });
  });

  group('Context persistence', () {
    test('Plant context survives copy/reload-shaped construction', () {
      final original = _plant(placement: PlantWeatherContext.indoor);
      final restored = original.copyWith();
      expect(restored.placement, PlantWeatherContext.indoor);
      expect(restored.id, original.id);
      expect(
        restored.copyWith(placement: PlantWeatherContext.gardenBed).placement,
        PlantWeatherContext.gardenBed,
      );
    });
  });

  group('Location linking', () {
    test('Plant can safely reference a Location', () {
      final home = PlantLocation(
        id: 'location-home',
        name: 'Home',
        city: 'Tiruppur',
        createdAt: DateTime(2026, 9, 1),
      );
      final encoded = PlantLocation.fromJson(home.toJson());
      expect(encoded.id, 'location-home');
      expect(encoded.weatherPlaceName, 'Tiruppur');

      final indoor = _plant(
        id: 'p-in',
        placement: PlantWeatherContext.indoor,
        locationId: home.id,
      );
      final outdoor = _plant(
        id: 'p-out',
        name: 'Tomato',
        placement: PlantWeatherContext.outdoorPotted,
        locationId: home.id,
      );
      expect(indoor.locationId, outdoor.locationId);
      expect(indoor.placement, isNot(outdoor.placement));
    });
  });

  group('Care rule linkage', () {
    test('Care rule uses durable plantId', () {
      final reminder = PlantReminder(
        id: 'rem-1',
        plantName: 'Monstera',
        plantId: 'durable-plant-id',
        taskType: 'Watering💧',
        dateTime: DateTime(2026, 9, 8, 9),
        createdAt: DateTime(2026, 9, 1, 9),
      );
      final rule = CareLogic.fromReminder(reminder);
      expect(rule.plantId, 'durable-plant-id');
      expect(rule.plantId, isNot(reminder.plantName));
      expect(rule.reminderId, 'rem-1');
      expect(rule.baseIntervalDays, 7);
    });

    test('fromReminder requires a durable plantId', () {
      final reminder = PlantReminder(
        id: 'rem-legacy',
        plantName: 'Monstera',
        taskType: 'Watering',
        dateTime: DateTime(2026, 9, 2),
        createdAt: DateTime(2026, 9, 1),
      );
      expect(() => CareLogic.fromReminder(reminder), throwsArgumentError);
    });
  });

  group('Care completion', () {
    test('Completion updates rule and appends a care_completion event', () {
      final now = DateTime(2026, 9, 1, 10);
      final rule = _rule(
        nextDueAt: DateTime(2026, 9, 1, 9),
        lastCompletedAt: DateTime(2026, 8, 24, 10),
      );
      final updated = CareLogic.complete(rule, now);
      expect(updated.lastCompletedAt, now);
      expect(updated.nextDueAt, DateTime(2026, 9, 8));
      expect(updated.plantId, 'plant-1');

      final event = CareLogic.completionEvent(rule: updated, now: now);
      expect(event.eventType, PlantEventType.careCompletion);
      expect(event.eventType.wireName, 'care_completion');
      expect(event.plantId, 'plant-1');
      expect(event.payload['careRuleId'], 'rule-1');
      expect(event.payload['careType'], 'Watering');
    });

    test('watering why-copy uses known days since last care', () {
      final rule = _rule(lastCompletedAt: DateTime(2026, 8, 24, 10));
      expect(
        CareLogic.whyDue(rule, DateTime(2026, 9, 1, 10)),
        'Dry for 8 days.',
      );
    });
  });

  group('Today priority with care rules', () {
    test('recovery still outranks care', () {
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: [_recoveryCase()],
        plantNames: {'plant-1': 'Monstera'},
        careRules: [_rule()],
        reminders: [
          PlantReminder(
            id: 'rem-1',
            plantName: 'Pothos',
            plantId: 'plant-2',
            taskType: 'Watering',
            dateTime: DateTime(2026, 9, 1, 8),
            createdAt: DateTime(2026, 8, 20),
          ),
        ],
      );
      expect(result.cards.first.kind, TodayActionKind.recovery);
      expect(result.cards.any((c) => c.kind == TodayActionKind.care), isTrue);
    });

    test('care rule and linked reminder do not duplicate Today cards', () {
      final result = TodayPriorityResolver.resolve(
        now: DateTime(2026, 9, 1, 10),
        cases: const [],
        plantNames: {'plant-1': 'Monstera'},
        careRules: [_rule(reminderId: 'rem-1')],
        reminders: [
          PlantReminder(
            id: 'rem-1',
            plantName: 'Monstera',
            plantId: 'plant-1',
            taskType: 'Watering💧',
            dateTime: DateTime(2026, 9, 1, 8),
            createdAt: DateTime(2026, 8, 20),
          ),
        ],
      );
      expect(result.cards.where((c) => c.kind == TodayActionKind.care).length, 1);
      expect(result.cards.first.careRuleId, 'rule-1');
    });
  });

  group('Weather safety', () {
    test('indoor, unknown, and greenhouse-covered are not outdoor-eligible', () {
      const heat = TodayWeatherSnapshot(temperatureC: 40);
      expect(
        TodayPriorityResolver.shouldShowCriticalWeather(
          weather: heat,
          plantContexts: const [
            PlantWeatherContext.unknown,
            PlantWeatherContext.indoor,
            PlantWeatherContext.greenhouseCovered,
          ],
        ),
        isFalse,
      );
      expect(
        TodayPriorityResolver.contextForPlant(_plant()),
        PlantWeatherContext.unknown,
      );
      expect(
        TodayPriorityResolver.contextForPlant(
          _plant(placement: PlantWeatherContext.indoor),
        ).isAffectedByOutdoorConditions,
        isFalse,
      );
    });

    test('outdoor-potted and garden-bed are weather eligible', () {
      expect(
        PlantWeatherContext.outdoorPotted.isAffectedByOutdoorConditions,
        isTrue,
      );
      expect(
        PlantWeatherContext.gardenBed.isAffectedByOutdoorConditions,
        isTrue,
      );
      expect(
        TodayPriorityResolver.shouldShowCriticalWeather(
          weather: const TodayWeatherSnapshot(temperatureC: 1),
          plantContexts: const [PlantWeatherContext.outdoorPotted],
        ),
        isTrue,
      );
      expect(
        TodayPriorityResolver.contextForPlant(
          _plant(placement: PlantWeatherContext.gardenBed),
        ),
        PlantWeatherContext.gardenBed,
      );
    });
  });

  group('Care type matching', () {
    test('normalizes reminder task labels onto the same care type', () {
      expect(
        CareTypeNormalizer.normalize('Watering💧'),
        CareTypeNormalizer.normalize('Watering'),
      );
      expect(CareTypeNormalizer.isWatering('Misting💦'), isTrue);
    });
  });
}
