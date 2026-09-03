import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/folder_model.dart';
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/navigation/v1_nav.dart';
import 'package:plantidentifier/services/gemini_service.dart';
import 'package:plantidentifier/services/identify_logic.dart';
import 'package:plantidentifier/services/plant_chat_logic.dart';
import 'package:plantidentifier/services/weather_service.dart';

void main() {
  group('AI Plant Expert image lifecycle', () {
    test('follow-up question still declares the attached photo', () {
      const first = 'what is this plant';
      final prompt = PlantChatLogic.botanistPrompt(
        question: first,
        hasImage: true,
      );
      expect(prompt, contains('photo is included'));
      expect(PlantChatLogic.hasUsableImage([1, 2, 3]), isTrue);

      final followUp = PlantChatLogic.botanistPrompt(
        question: 'is it toxic to cats?',
        hasImage: true,
        previousQuestion: first,
      );
      expect(followUp, contains('photo is included'));
      expect(followUp, contains('what is this plant'));
    });

    test('does not claim vision when no bytes are held', () {
      final prompt = PlantChatLogic.botanistPrompt(
        question: 'what is this plant',
        hasImage: false,
      );
      expect(prompt, contains('No photo is included'));
      expect(PlantChatLogic.hasUsableImage(null), isFalse);
      expect(PlantChatLogic.attachedCopy, isNot(contains('I can see')));
    });
  });

  group('Identification must not become a confident guess', () {
    test('no_image_received cannot create a plant', () {
      final attempt = IdentifyLogic.fromJson({
        'error': 'no_image_received',
        'plant_name_common': 'Peace Lily',
      }, '/tmp/current.jpg');
      expect(attempt.isSuccess, isFalse);
      expect(attempt.plant, isNull);
      expect(attempt.failure, IdentifyFailureKind.model);
    });

    test('high confidence without visible evidence is unconfirmed', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Peace Lily',
        'plant_name_scientific': 'Spathiphyllum',
        'identification_confidence': 'high',
      }, '/tmp/current.jpg');
      expect(attempt.isSuccess, isTrue);
      expect(attempt.result!.identityStatus, IdentityStatus.unconfirmed);
      expect(attempt.result!.allowsConfirmedSave, isFalse);
      expect(IdentifyLogic.mayRecordScanHistory(attempt.plant!), isFalse);
    });

    test('binds the current photo path, not a previous plant', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Snake Plant',
        'identification_confidence': 'high',
        'evidence_summary': 'Upright sword-shaped leaves with yellow margins.',
      }, '/tmp/scan-current.jpg');
      expect(attempt.plant!.imagePath, '/tmp/scan-current.jpg');
    });
  });

  group('Diagnosis does not treat saved identity as truth', () {
    test('saved species is a hint that the photo can override', () {
      final plant = Plant(
        name: 'Peace Lily',
        scientificName: 'Spathiphyllum',
        description: '',
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
      final prompt = GeminiService.diagnosePromptFor(plant);
      expect(prompt, contains('Peace Lily'));
      expect(prompt, contains('That name may be wrong'));
      expect(prompt, contains('trust the photo'));
    });

    test('camera diagnose without a plant has no species hint', () {
      final prompt = GeminiService.diagnosePromptFor(null);
      expect(prompt, isNot(contains('saved garden record')));
    });
  });

  group('Garden stays distinct from Location', () {
    test('folder count grammar and no location field', () {
      final empty = PlantFolder(
        id: 'g1',
        name: 'balcony',
        createdAt: DateTime(2026, 9, 2),
      );
      expect(empty.plantCountLabel, '0 plants');
      expect(empty.toJson().containsKey('locationId'), isFalse);

      final one = empty.copyWith(plantIds: ['plant-1']);
      expect(one.plantCountLabel, '1 plant');
      expect(one.copyWith(plantIds: ['a', 'b']).plantCountLabel, '2 plants');
    });
  });

  group('Weather mapping stays honest', () {
    test('tiny current-endpoint spread is not a daily range', () {
      expect(WeatherCopy.hasCredibleDailyRange(35.7, 35.7), isFalse);
      expect(WeatherCopy.hasCredibleDailyRange(22, 31), isTrue);
    });

    test('hot weather copy does not prescribe misting every plant', () {
      final note = WeatherCopy.environmentNote(
        temperatureC: 36,
        humidity: 40,
      );
      expect(note.toLowerCase(), isNot(contains('mist')));
      expect(note, contains('each plant'));
    });
  });

  group('V1 navigation', () {
    test('camera remains an action, not a persistent tab', () {
      expect(V1Nav.cameraIsPersistentTab, isFalse);
      expect(V1Nav.cameraActionIndex, 2);
      expect(V1Nav.progressIndex, 3);
    });
  });
}
