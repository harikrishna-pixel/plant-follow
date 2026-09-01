import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/plant_event.dart';
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/model/data_model/reminder_model.dart';
import 'package:plantidentifier/services/plant_record_migration.dart';

Plant _plant({
  String? id,
  String name = 'Monstera',
  String imagePath = '/tmp/monstera.jpg',
}) {
  return Plant(
    id: id,
    name: name,
    scientificName: 'Monstera deliciosa',
    description: 'A tropical climbing plant with large fenestrated leaves.',
    taxonomy: const {},
    nativeRegion: 'Central America',
    growthSeason: 'Year-round',
    toxicity: 'Toxic to pets',
    careGuide: const {},
    healthScan: 'Healthy',
    commonPests: 'Spider mites',
    commonDiseases: 'Root rot',
    usage: 'Decorative',
    funFact: 'Also called Swiss cheese plant',
    imagePath: imagePath,
  );
}

void main() {
  group('Plant durable identity', () {
    test('assigns a UUID when id is omitted', () {
      final plant = _plant();
      expect(plant.id, isNotEmpty);
      expect(plant.id.contains('-'), isTrue);
      expect(plant.id, isNot(plant.uniqueId));
    });

    test('preserves an explicit durable id', () {
      final plant = _plant(id: 'kept-id-123');
      expect(plant.id, 'kept-id-123');
    });

    test('legacy uniqueId stays a stable 16-char hash of imagePath', () {
      final a = _plant(id: 'a');
      final b = _plant(id: 'b');
      expect(a.uniqueId, hasLength(16));
      expect(a.uniqueId, b.uniqueId);
    });

    test('matchesStoredId accepts durable id and legacy uniqueId', () {
      final plant = _plant(id: 'durable-1');
      expect(plant.matchesStoredId('durable-1'), isTrue);
      expect(plant.matchesStoredId(plant.uniqueId), isTrue);
      expect(plant.matchesStoredId('other'), isFalse);
    });

    test('fromGemini assigns a durable id', () {
      final plant = Plant.fromGemini({
        'plant_name_common': 'Pothos',
        'plant_name_scientific': 'Epipremnum aureum',
      }, '/tmp/pothos.jpg');
      expect(plant.id, isNotEmpty);
      expect(plant.name, 'Pothos');
    });
  });

  group('Folder plantId remapping', () {
    test('rewrites legacy uniqueId entries to durable ids', () {
      final plant = _plant(id: 'uuid-1', imagePath: '/tmp/leaf.png');
      final remapped = PlantRecordMigration.remapFolderPlantIds(
        [plant.uniqueId],
        [plant],
      );
      expect(remapped, ['uuid-1']);
    });

    test('keeps already-durable ids and unknown ids', () {
      final plant = _plant(id: 'uuid-1');
      final remapped = PlantRecordMigration.remapFolderPlantIds(
        ['uuid-1', 'orphan-id'],
        [plant],
      );
      expect(remapped, ['uuid-1', 'orphan-id']);
    });

    test('dedupes when both uniqueId and durable id are stored', () {
      final plant = _plant(id: 'uuid-1');
      final remapped = PlantRecordMigration.remapFolderPlantIds(
        [plant.uniqueId, 'uuid-1'],
        [plant],
      );
      expect(remapped, ['uuid-1']);
    });
  });

  group('PlantEvent', () {
    test('round-trips JSON with a plantId', () {
      final event = PlantEvent(
        id: 'evt-1',
        plantId: 'uuid-1',
        eventType: PlantEventType.identification,
        timestamp: DateTime.utc(2026, 9, 1, 6),
        payload: {'name': 'Monstera'},
        source: 'identification',
      );
      final restored = PlantEvent.fromJson(event.toJson());
      expect(restored.plantId, 'uuid-1');
      expect(restored.eventType, PlantEventType.identification);
      expect(restored.payload['name'], 'Monstera');
      expect(restored.source, 'identification');
    });

    test('encodes reserved future event types', () {
      expect(PlantEventType.recoveryCheckIn.wireName, 'recovery_check_in');
      expect(PlantEventType.careCompletion.wireName, 'care_completion');
      expect(
        PlantEventTypeCodec.fromWire('harvest'),
        PlantEventType.harvest,
      );
    });
  });

  group('PlantReminder plantId', () {
    test('loads legacy JSON without plantId', () {
      final reminder = PlantReminder.fromJson({
        'id': 'r1',
        'plantName': 'Monstera',
        'taskType': 'Watering',
        'dateTime': '2026-09-01T10:00:00.000',
        'isCompleted': false,
        'createdAt': '2026-09-01T09:00:00.000',
      });
      expect(reminder.plantId, isNull);
      expect(reminder.plantName, 'Monstera');
    });

    test('persists optional plantId', () {
      final reminder = PlantReminder(
        id: 'r2',
        plantName: 'Pothos',
        plantId: 'uuid-1',
        taskType: 'Watering',
        dateTime: DateTime.utc(2026, 9, 2),
        createdAt: DateTime.utc(2026, 9, 1),
      );
      final restored = PlantReminder.fromJson(reminder.toJson());
      expect(restored.plantId, 'uuid-1');
    });
  });
}
