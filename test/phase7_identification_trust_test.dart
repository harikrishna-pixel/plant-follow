import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantidentifier/model/data_model/plant_event.dart';
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/services/identification_policy.dart';
import 'package:plantidentifier/services/identification_result.dart';
import 'package:plantidentifier/services/identify_logic.dart';
import 'package:plantidentifier/view/screens/result_screens/identify_trust_card.dart';

Plant _plant({
  String name = 'Swiss Cheese Plant',
  String scientific = 'Monstera deliciosa',
  String confidence = '',
  String identityStatus = '',
  String toxicity = '',
  List<String> alternatives = const [],
}) {
  return Plant(
    id: 'plant-1',
    name: name,
    scientificName: scientific,
    description: 'A tropical plant.',
    taxonomy: const {},
    nativeRegion: '',
    growthSeason: '',
    toxicity: toxicity,
    careGuide: const {},
    healthScan: '',
    commonPests: '',
    commonDiseases: '',
    usage: '',
    funFact: '',
    imagePath: '/tmp/plant.jpg',
    speciesConfidence: confidence,
    alternativeNames: alternatives,
    identityStatus: identityStatus,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Hive identity field', () {
    test('legacy plants without identityStatus still load as confirmed', () {
      final plant = _plant();
      expect(plant.identityStatus, isEmpty);
      expect(plant.identityConfirmation, IdentityStatus.confirmed);
      expect(IdentifyLogic.displayName(plant), 'Swiss Cheese Plant');
    });

    test('field 21 is additive and unused numbers stay unused', () {
      expect(IdentityStatusCodec.wireName(IdentityStatus.likely), 'likely');
      expect(IdentityStatusCodec.tryFromWire(''), isNull);
    });
  });

  group('Identification result contract', () {
    test('high-confidence result is a strong confirmed match', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Swiss Cheese Plant',
        'plant_name_scientific': 'Monstera deliciosa',
        'identification_confidence': 'high',
        'evidence_summary': 'Leaf shape and vein pattern match this species.',
        'toxicity': 'Toxic to pets',
      }, '/tmp/a.jpg');
      expect(attempt.isSuccess, isTrue);
      expect(attempt.result!.identityStatus, IdentityStatus.confirmed);
      expect(attempt.result!.titlePrefix, 'Identified as');
      expect(attempt.result!.confidenceChipLabel, 'Strong match');
      expect(attempt.result!.allowsDirectSave, isTrue);
      expect(attempt.result!.allowsConfirmedSave, isTrue);
      expect(IdentifyLogic.displayName(attempt.plant!), 'Swiss Cheese Plant');
      expect(IdentifyLogic.isUncertain(attempt.plant!), isFalse);
    });

    test('flower-only identification is a valid plant result', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Rose',
        'plant_name_scientific': 'Rosa',
        'identification_confidence': 'high',
        'evidence_summary': 'The bloom shape and petal arrangement match a rose.',
        'image_quality': 'ok',
      }, '/tmp/rose.jpg');
      expect(attempt.isSuccess, isTrue);
      expect(attempt.plant!.name, 'Rose');
      expect(attempt.failure, isNull);
    });

    test('medium confidence renders Likely state', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Swiss Cheese Plant',
        'plant_name_scientific': 'Monstera deliciosa',
        'identification_confidence': 'medium',
      }, '/tmp/a.jpg');
      expect(attempt.result!.identityStatus, IdentityStatus.likely);
      expect(attempt.result!.titlePrefix, 'Likely');
      expect(attempt.result!.confidenceChipLabel, 'Likely match');
      expect(attempt.result!.supportingCopy, "We're not fully sure yet.");
      expect(attempt.result!.primaryActionLabel, 'Save as Likely Match');
      expect(IdentifyLogic.displayName(attempt.plant!), 'Likely Swiss Cheese Plant');
      expect(IdentifyLogic.isUncertain(attempt.plant!), isTrue);
    });

    test('low confidence does not masquerade as confirmed and offers retry', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Swiss Cheese Plant',
        'identification_confidence': 'low',
      }, '/tmp/a.jpg');
      expect(attempt.isSuccess, isTrue);
      expect(attempt.result!.identityStatus, IdentityStatus.unconfirmed);
      expect(attempt.result!.displayedName, 'Not sure yet');
      expect(attempt.result!.confidenceChipLabel, 'Needs another look');
      expect(attempt.result!.allowsDirectSave, isFalse);
      expect(attempt.result!.allowsConfirmedSave, isFalse);
      expect(attempt.result!.primaryActionLabel, 'Try another photo');
      expect(IdentifyLogic.displayName(attempt.plant!), 'Not sure yet');
      expect(IdentifyLogic.mayRecordScanHistory(attempt.plant!), isFalse);
    });

    test('missing model confidence is not treated as a confirmed species', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
      }, '/tmp/a.jpg');
      expect(attempt.result!.identityStatus, IdentityStatus.likely);
      expect(attempt.result!.allowsConfirmedSave, isFalse);
    });

    test('does not use a fake percentage as calibrated confidence', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'identification_confidence': 'high',
        'confidence_score': 93.7,
      }, '/tmp/a.jpg');
      expect(attempt.result!.confidenceScore, isNull);
    });

    test('mixed Identify JSON still creates a plant instead of failing', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Monstera',
        'plant_name_scientific': 'Monstera deliciosa',
        'identification_confidence': 'high',
        'evidence_summary': 'Fenestrated leaves with trailing vines.',
        'taxonomy': {'kingdom': 'Plantae', 'family': 'Araceae'},
        'care_guide': {'watering': 'When dry'},
        'health_scan': {'notes': 'Looks healthy'},
        'common_pests': ['spider mites'],
      }, '/tmp/a.jpg');
      expect(attempt.isSuccess, isTrue);
      expect(attempt.failure, isNull);
      expect(attempt.plant!.name, 'Monstera');
      expect(attempt.plant!.healthScan, 'Looks healthy');
      expect(attempt.plant!.commonPests, 'spider mites');
    });
  });

  group('Parser and invalid results', () {
    test('invalid result cannot create Plant', () {
      final attempt = IdentifyLogic.fromJson({
        'error': 'not_a_plant',
      }, '/tmp/a.jpg');
      expect(IdentifyLogic.canCreatePlant(attempt), isFalse);
      expect(attempt.plant, isNull);
      expect(attempt.failure, IdentifyFailureKind.invalid);
    });

    test('parser rejects diagnosis JSON as identification', () {
      final attempt = IdentifyLogic.fromJson({
        'overall_condition': 'looking_okay',
        'primary_issue': {'name': 'thrips'},
        'treatment_steps': [],
      }, '/tmp/a.jpg');
      expect(attempt.isSuccess, isFalse);
      expect(attempt.plant, isNull);
    });

    test('unknown plant name cannot create Plant', () {
      expect(
        IdentifyLogic.fromJson({
          'plant_name_common': 'Unknown',
        }, '/tmp/a.jpg').plant,
        isNull,
      );
      expect(
        IdentifyLogic.fromJson({
          'plant_name_common': 'unable to identify',
        }, '/tmp/a.jpg').isSuccess,
        isFalse,
      );
    });

    test('not_a_plant image quality cannot create Plant', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Monstera',
        'image_quality': 'not_a_plant',
      }, '/tmp/a.jpg');
      expect(attempt.isSuccess, isFalse);
      expect(attempt.plant, isNull);
    });
  });

  group('Safety', () {
    test('missing safety data does not become safe', () {
      final safety = PlantSafety.fromToxicityText('');
      expect(safety.isUnknown, isTrue);
      expect(safety.isNonToxic, isFalse);
      expect(safety.headline, 'Safety information unavailable');
      expect(safety.headline, isNot('Safe'));
    });

    test('toxicity is displayed only when supplied', () {
      final toxic = PlantSafety.fromToxicityText('Toxic to cats and dogs');
      expect(toxic.isToxic, isTrue);
      expect(toxic.headline, 'Toxic if ingested');
      final unclear = PlantSafety.fromToxicityText('See local guidance');
      expect(unclear.isUnknown, isTrue);
    });

    test('uncertain identification qualifies safety language', () {
      final safety = PlantSafety.fromToxicityText('Toxic to pets');
      expect(
        safety.supportingCopy(identificationUncertain: true),
        'If this identification is correct, this plant may be toxic to pets.',
      );
      expect(
        safety.supportingCopy(identificationUncertain: false),
        isNot(contains('If this identification is correct')),
      );
    });

    test('structured unknown safety is not non-toxic', () {
      final safety = PlantSafety.fromIdentificationJson({
        'safety': {'status': 'unknown'},
      });
      expect(safety.isUnknown, isTrue);
      expect(safety.isNonToxic, isFalse);
    });
  });

  group('Alternatives', () {
    test('alternatives render only when supplied and never invented', () {
      final none = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'identification_confidence': 'medium',
      }, '/tmp/a.jpg');
      expect(none.result!.alternatives, isEmpty);

      final some = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'identification_confidence': 'low',
        'alternative_candidates': [
          {'common_name': 'Philodendron', 'scientific_name': 'Philodendron hederaceum'},
        ],
      }, '/tmp/a.jpg');
      expect(some.result!.alternatives.single.commonName, 'Philodendron');
    });

    test('maximum alternatives displayed is 3', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'identification_confidence': 'low',
        'alternative_candidates': [
          {'common_name': 'One'},
          {'common_name': 'Two'},
          {'common_name': 'Three'},
          {'common_name': 'Four'},
          {'common_name': 'Five'},
        ],
      }, '/tmp/a.jpg');
      expect(attempt.result!.alternatives, hasLength(3));
      expect(attempt.plant!.alternativeNames, hasLength(3));
    });

    test('alternative selection becomes selected identity', () {
      final attempt = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'identification_confidence': 'low',
        'alternative_candidates': [
          {'common_name': 'Philodendron', 'scientific_name': 'Philodendron hederaceum'},
        ],
      }, '/tmp/a.jpg');
      final selected = IdentifyLogic.applyCandidate(
        attempt.plant!,
        attempt.result!.alternatives.single,
      );
      expect(selected.name, 'Philodendron');
      expect(selected.scientificName, 'Philodendron hederaceum');
      expect(selected.identityConfirmation, IdentityStatus.confirmed);
      expect(IdentifyLogic.displayName(selected), 'Philodendron');
      expect(selected.toxicity, isEmpty);
    });
  });

  group('Events, history, and save rules', () {
    test('identification event stores confidence metadata', () {
      final plant = _plant(
        confidence: 'medium',
        identityStatus: 'likely',
      );
      final payload = IdentifyLogic.identificationEventPayload(
        plant,
        confirmationSource: 'user_selected',
      );
      expect(payload['confidence'], 'medium');
      expect(payload['identityStatus'], 'likely');
      expect(payload['confirmationSource'], 'user_selected');
    });

    test('failed identification cannot create a successful history record', () {
      final attempt = IdentifyLogic.fromJson({
        'error': 'unable_to_identify',
      }, '/tmp/a.jpg');
      expect(attempt.plant, isNull);
      expect(IdentifyLogic.canCreatePlant(attempt), isFalse);
    });

    test('low confidence is not recorded as a successful scan', () {
      final plant = IdentifyLogic.fromJson({
        'plant_name_common': 'Pothos',
        'identification_confidence': 'low',
      }, '/tmp/a.jpg').plant!;
      expect(IdentifyLogic.mayRecordScanHistory(plant), isFalse);
    });
  });

  group('Unlimited Identify', () {
    test('unlimited Identify path does not use wallet remaining as a gate', () {
      expect(
        IdentificationPolicy.canStartIdentification(
          isSubscribed: false,
          freeScansRemaining: 0,
        ),
        isTrue,
      );
    });

    test('no scan-counter UI policy on Identify', () {
      expect(IdentificationPolicy.showFreeScanCounter, isFalse);
      expect(IdentificationPolicy.visibleRemainingLabel(3), isNull);
    });
  });

  group('Failure copy stays human', () {
    test('does not expose internal failure labels', () {
      expect(IdentifyFailureCopy.title(IdentifyFailureKind.network),
          "We couldn't connect.");
      expect(IdentifyFailureCopy.title(IdentifyFailureKind.api),
          "We couldn't identify this plant right now.");
      expect(IdentifyFailureCopy.title(IdentifyFailureKind.parser),
          "We couldn't read the result.");
      expect(IdentifyFailureCopy.title(IdentifyFailureKind.invalid),
          "We couldn't find enough plant detail.");
      for (final kind in IdentifyFailureKind.values) {
        expect(IdentifyFailureCopy.title(kind), isNot(contains('API_KEY')));
        expect(IdentifyFailureCopy.body(kind), isNot(contains('HTTP')));
      }
    });
  });

  group('Duplicate analyze protection', () {
    test('duplicate Analyze taps do not start a second request', () {
      final guard = IdentifyRequestGuard();
      expect(guard.tryStart(), isTrue);
      expect(guard.tryStart(), isFalse);
      expect(guard.isInFlight, isTrue);
      guard.finish();
      expect(guard.tryStart(), isTrue);
    });
  });

  group('Retry guidance', () {
    test('retry tips are short and capped at 3', () {
      final tips = IdentificationResult.retryTipsFor(ImageQualityKind.blurry);
      expect(tips, hasLength(lessThanOrEqualTo(3)));
      expect(tips, isNot(contains('Try again.')));
      expect(tips.first, contains('focus'));
      expect(
        IdentificationResult.retryTipsFor(ImageQualityKind.unknown),
        contains('Photograph a leaf, flower, or the whole plant.'),
      );
    });
  });

  group('Identify trust UI', () {
    testWidgets('high-confidence result renders confirmed/strong state',
        (tester) async {
      final result = IdentificationResult(
        commonName: 'Swiss Cheese Plant',
        scientificName: 'Monstera deliciosa',
        confidence: SpeciesConfidence.high,
        identityStatus: IdentityStatus.confirmed,
        evidenceSummary: 'Leaf shape and vein pattern match this species.',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentifyTrustCard(
              plant: _plant(confidence: 'high', identityStatus: 'confirmed'),
              result: result,
            ),
          ),
        ),
      );
      expect(find.text('Identified as'), findsOneWidget);
      expect(find.text('Swiss Cheese Plant'), findsOneWidget);
      expect(find.text('Strong match'), findsOneWidget);
      expect(find.text('Not sure yet'), findsNothing);
    });

    testWidgets('medium confidence renders Likely state', (tester) async {
      final result = IdentificationResult.fromPlant(
        _plant(confidence: 'medium', identityStatus: 'likely'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentifyTrustCard(
              plant: _plant(confidence: 'medium', identityStatus: 'likely'),
              result: result,
            ),
          ),
        ),
      );
      expect(find.text('Likely'), findsOneWidget);
      expect(find.text('Likely match'), findsOneWidget);
      expect(find.text("We're not fully sure yet."), findsOneWidget);
    });

    testWidgets('low confidence does not look confirmed and offers retry',
        (tester) async {
      final plant = _plant(
        confidence: 'low',
        identityStatus: 'unconfirmed',
        alternatives: const ['Philodendron (Philodendron hederaceum)'],
      );
      final result = IdentificationResult.fromPlant(plant);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                IdentifyTrustCard(plant: plant, result: result),
                IdentifyTrustExtras(
                  result: result,
                  onRetry: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Not sure yet'), findsWidgets);
      expect(find.text('Needs another look'), findsOneWidget);
      expect(find.text('Identified as'), findsNothing);
      expect(find.text('Strong match'), findsNothing);
      expect(find.text('Try another photo'), findsOneWidget);
      expect(find.text('Other possible matches'), findsOneWidget);
      expect(find.text('Philodendron'), findsOneWidget);
    });

    testWidgets('alternatives hide when none are supplied', (tester) async {
      final result = IdentificationResult.fromPlant(
        _plant(confidence: 'medium', identityStatus: 'likely'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: IdentifyTrustExtras(result: result)),
        ),
      );
      expect(find.text('Other possible matches'), findsNothing);
    });

    testWidgets('unknown safety is not called safe', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IdentifySafetySummary(
              safety: PlantSafety.unknown,
              identificationUncertain: false,
            ),
          ),
        ),
      );
      expect(find.text('Safety information unavailable'), findsOneWidget);
      expect(find.text('Safe'), findsNothing);
      expect(find.text('Generally non-toxic'), findsNothing);
    });

    testWidgets('toxicity copy is qualified when identification is uncertain',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentifySafetySummary(
              safety: PlantSafety.fromToxicityText('Toxic to cats and dogs'),
              identificationUncertain: true,
            ),
          ),
        ),
      );
      expect(find.text('Toxic if ingested'), findsOneWidget);
      expect(
        find.text(
          'If this identification is correct, this plant may be toxic to pets.',
        ),
        findsOneWidget,
      );
    });
  });

  group('PlantEvent payload remains additive', () {
    test('existing identification events without new keys still parse', () {
      final event = PlantEvent.tryFromJson({
        'id': 'evt-1',
        'plantId': 'plant-1',
        'eventType': 'identification',
        'timestamp': DateTime.utc(2026, 9, 1).toIso8601String(),
        'payload': {'name': 'Monstera'},
        'source': 'identification',
      });
      expect(event, isNotNull);
      expect(event!.payload['name'], 'Monstera');
      expect(event.payload['confidence'], isNull);
    });
  });
}
