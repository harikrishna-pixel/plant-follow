import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/care_rule.dart';
import 'package:plantidentifier/model/data_model/plant_event.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/services/care_logic.dart';
import 'package:plantidentifier/services/plant_health_presenter.dart';
import 'package:plantidentifier/services/plant_timeline.dart';
import 'package:plantidentifier/services/recovery_logic.dart';
import 'package:plantidentifier/services/today_priority.dart';
import 'package:plantidentifier/view/screens/favourite_screen/plant_care_tab.dart';

PlantEvent _event({
  required String id,
  required String plantId,
  required PlantEventType type,
  required DateTime timestamp,
  Map<String, dynamic>? payload,
}) {
  return PlantEvent(
    id: id,
    plantId: plantId,
    eventType: type,
    timestamp: timestamp,
    payload: payload,
  );
}

CareRule _wateringRule({DateTime? nextDueAt, DateTime? lastCompletedAt}) {
  return CareRule(
    id: 'rule-1',
    plantId: 'plant-a',
    careType: 'Watering',
    baseIntervalDays: 7,
    lastCompletedAt: lastCompletedAt,
    nextDueAt: nextDueAt ?? DateTime(2026, 9, 1, 9),
  );
}

PlantDiagnosis _diagnosis() {
  return PlantDiagnosis(
    id: 'diag-1',
    plantId: 'plant-a',
    createdAt: DateTime(2026, 8, 29),
    photoPath: '/tmp/a.jpg',
    confidence: DiagnosisConfidence.medium,
    primaryIssue: const DiagnosisIssue(
      name: 'Spider mites',
      explanation: 'Fine webbing.',
    ),
    firstAid: const FirstAidAction(action: 'Rinse leaves'),
  );
}

RecoveryCase _openCase() {
  final opened = DateTime(2026, 8, 29);
  return RecoveryCase(
    id: 'case-1',
    plantId: 'plant-a',
    diagnosisId: 'diag-1',
    treatmentId: 'treat-1',
    openedAt: opened,
    status: RecoveryCaseStatus.awaitingDay3,
    day3DueAt: RecoveryLogic.day3DueAt(opened),
    day7DueAt: RecoveryLogic.day7DueAt(opened),
  );
}

void main() {
  group('Timeline isolation', () {
    test('only selected plant events render', () {
      final events = [
        _event(
          id: 'a1',
          plantId: 'plant-a',
          type: PlantEventType.identification,
          timestamp: DateTime(2026, 9, 1, 8),
          payload: {'name': 'Monstera'},
        ),
        _event(
          id: 'b1',
          plantId: 'plant-b',
          type: PlantEventType.careCompletion,
          timestamp: DateTime(2026, 9, 1, 9),
          payload: {'careType': 'Watering'},
        ),
        _event(
          id: 'a2',
          plantId: 'plant-a',
          type: PlantEventType.diagnosis,
          timestamp: DateTime(2026, 9, 1, 10),
          payload: {'primaryIssue': 'Spider mites'},
        ),
      ];

      final items = PlantTimelineMapper.itemsForPlant(
        plantId: 'plant-a',
        events: events,
      );
      expect(items.map((e) => e.id), ['a2', 'a1']);
      expect(items.every((e) => e.plantId == 'plant-a'), isTrue);
      expect(items.any((e) => e.id == 'b1'), isFalse);
    });

    test('events for Plant A never appear on Plant B', () {
      final events = [
        _event(
          id: 'a1',
          plantId: 'plant-a',
          type: PlantEventType.identification,
          timestamp: DateTime(2026, 9, 1),
          payload: {'name': 'Monstera'},
        ),
        _event(
          id: 'b1',
          plantId: 'plant-b',
          type: PlantEventType.outcome,
          timestamp: DateTime(2026, 9, 2),
          payload: {'result': 'recovered'},
        ),
      ];

      final plantB = PlantTimelineMapper.itemsForPlant(
        plantId: 'plant-b',
        events: events,
      );
      expect(plantB, hasLength(1));
      expect(plantB.single.id, 'b1');
      expect(plantB.single.plantId, 'plant-b');
      expect(plantB.any((e) => e.plantId == 'plant-a'), isFalse);
    });
  });

  group('Timeline ordering', () {
    test('newest events appear first', () {
      final events = [
        _event(
          id: 'old',
          plantId: 'plant-a',
          type: PlantEventType.identification,
          timestamp: DateTime(2026, 8, 1),
        ),
        _event(
          id: 'mid',
          plantId: 'plant-a',
          type: PlantEventType.diagnosis,
          timestamp: DateTime(2026, 8, 15),
        ),
        _event(
          id: 'new',
          plantId: 'plant-a',
          type: PlantEventType.careCompletion,
          timestamp: DateTime(2026, 9, 1),
          payload: {'careType': 'Watering'},
        ),
      ];

      final items = PlantTimelineMapper.itemsForPlant(
        plantId: 'plant-a',
        events: events,
      );
      expect(items.map((e) => e.id), ['new', 'mid', 'old']);
    });
  });

  group('Event to UI mapping', () {
    test('event types map to readable labels', () {
      final now = DateTime(2026, 9, 1, 12);
      final cases = <PlantEventType, String>{
        PlantEventType.identification: 'Identified',
        PlantEventType.diagnosis: 'Diagnosis recorded',
        PlantEventType.treatment: 'Treatment started',
        PlantEventType.careCompletion: 'Watered',
        PlantEventType.recoveryCheckIn: 'Recovery check-in',
        PlantEventType.plantPhoto: 'Photo added',
        PlantEventType.outcome: 'Recovery completed',
        PlantEventType.milestone: 'Milestone',
        PlantEventType.harvest: 'Harvest recorded',
      };

      for (final entry in cases.entries) {
        final item = PlantTimelineMapper.fromEvent(
          _event(
            id: entry.key.wireName,
            plantId: 'plant-a',
            type: entry.key,
            timestamp: now,
            payload: {
              'careType': 'Watering',
              'action': 'started',
              'result': 'recovered',
            },
          ),
        );
        expect(item.title, entry.value, reason: entry.key.wireName);
        expect(item.title.contains('_'), isFalse);
      }
    });

    test('unknown future event type fails gracefully', () {
      expect(PlantEventTypeCodec.tryFromWire('future_crop_stage'), isNull);
      expect(
        PlantTimelineMapper.tryMapJson({
          'id': 'future-1',
          'plantId': 'plant-a',
          'eventType': 'future_crop_stage',
          'timestamp': '2026-09-01T12:00:00.000',
          'payload': {'raw': true},
        }),
        isNull,
      );
      expect(
        PlantEvent.tryFromJson({
          'id': 'future-1',
          'plantId': 'plant-a',
          'eventType': 'future_crop_stage',
          'timestamp': '2026-09-01T12:00:00.000',
          'payload': {},
        }),
        isNull,
      );
    });
  });

  group('Care from Plant Detail', () {
    test('completion uses shared CareLogic and updates next due', () {
      final now = DateTime(2026, 9, 1, 10);
      final rule = _wateringRule(lastCompletedAt: DateTime(2026, 8, 24, 10));
      final applied = CareLogic.completeWithEvent(rule, now);

      expect(applied.rule.lastCompletedAt, now);
      expect(applied.rule.nextDueAt, DateTime(2026, 9, 8));
      expect(applied.event.eventType, PlantEventType.careCompletion);
      expect(applied.event.eventType.wireName, 'care_completion');
      expect(applied.event.plantId, 'plant-a');
    });

    test('care_completion event renders as Watered on the timeline', () {
      final now = DateTime(2026, 9, 1, 10);
      final applied = CareLogic.completeWithEvent(_wateringRule(), now);
      final item = PlantTimelineMapper.fromEvent(applied.event);
      expect(item.title, 'Watered');
      expect(item.category, TimelineCategory.care);
    });

    test('Today no longer shows due care after shared completion', () {
      final now = DateTime(2026, 9, 1, 10);
      final due = _wateringRule();
      expect(CareLogic.isDue(due, now), isTrue);

      final before = TodayPriorityResolver.resolve(
        now: now,
        cases: const [],
        plantNames: {'plant-a': 'Monstera'},
        careRules: [due],
        reminders: const [],
      );
      expect(before.cards.any((c) => c.kind == TodayActionKind.care), isTrue);

      final applied = CareLogic.completeWithEvent(due, now);
      expect(CareLogic.isDue(applied.rule, now), isFalse);

      final after = TodayPriorityResolver.resolve(
        now: now,
        cases: const [],
        plantNames: {'plant-a': 'Monstera'},
        careRules: [applied.rule],
        reminders: const [],
      );
      expect(after.cards.any((c) => c.kind == TodayActionKind.care), isFalse);
    });

    test('care empty copy is accurate', () {
      expect(PlantCareTab.emptyTitle, 'No care schedule yet');
    });
  });

  group('Health surface', () {
    test('active recovery is surfaced', () {
      final view = PlantHealthPresenter.fromState(
        now: DateTime(2026, 9, 1, 10),
        activeCase: _openCase(),
        diagnosis: _diagnosis(),
      );
      expect(view.hasActiveRecovery, isTrue);
      expect(view.issueName, 'Spider mites');
      expect(view.confidenceLabel, 'Medium confidence');
      expect(view.stageLabel, 'Day 3 check-in');
      expect(view.headline, isNot(PlantHealthView.emptyHeadline));
    });

    test('closed recovery exposes outcome', () {
      final view = PlantHealthPresenter.fromState(
        now: DateTime(2026, 9, 10),
        activeCase: null,
        outcomes: [
          RecoveryOutcome(
            id: 'out-1',
            plantId: 'plant-a',
            recoveryCaseId: 'case-1',
            result: OutcomeResult.recovered,
            closedAt: DateTime(2026, 9, 8),
            closeReason: 'day7',
          ),
        ],
      );
      expect(view.hasActiveRecovery, isFalse);
      expect(view.latestOutcome, OutcomeResult.recovered);
      expect(view.latestOutcome!.label, 'Recovered');
      expect(view.body, contains('Recovered'));
    });

    test('no recovery produces a neutral empty state', () {
      final view = PlantHealthPresenter.fromState(
        now: DateTime(2026, 9, 1),
        activeCase: null,
      );
      expect(view.hasActiveRecovery, isFalse);
      expect(view.headline, 'No active recovery');
      expect(view.latestOutcome, isNull);
      expect(
        PlantDetailStatus.howIsItDoing(now: DateTime(2026, 9, 1)),
        'No active recovery',
      );
    });
  });

  group('Empty states', () {
    test('timeline empty copy is calm', () {
      expect(PlantTimelineMapper.emptyTitle, 'Your plant story starts here');
    });
  });
}
