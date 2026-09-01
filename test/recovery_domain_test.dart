import 'package:flutter_test/flutter_test.dart';
import 'package:plantidentifier/model/data_model/recovery_models.dart';
import 'package:plantidentifier/services/diagnosis_mapper.dart';
import 'package:plantidentifier/services/recovery_logic.dart';

void main() {
  group('DiagnosisMapper', () {
    test('maps high confidence primary issue and first aid', () {
      final diagnosis = DiagnosisMapper.diagnosisFromGemini(
        json: {
          'plant_name': 'Pothos',
          'confidence': 'high',
          'overall_condition': 'needs_attention',
          'primary_issue': {
            'name': 'Spider mites',
            'explanation': 'Fine webbing on the underside of leaves.',
            'evidence': 'stippled leaves',
          },
          'first_aid': {
            'action': 'Rinse the leaves with lukewarm water',
            'method': 'Support the pot and spray the undersides today.',
          },
        },
        plantId: 'plant-1',
        photoPath: '/tmp/a.jpg',
      );
      expect(diagnosis.plantId, 'plant-1');
      expect(diagnosis.confidence, DiagnosisConfidence.high);
      expect(diagnosis.primaryIssue.name, 'Spider mites');
      expect(diagnosis.firstAid.action, contains('Rinse'));
      expect(diagnosis.followUpRequired, isFalse);
    });

    test('maps medium confidence with alternative', () {
      final diagnosis = DiagnosisMapper.diagnosisFromGemini(
        json: {
          'confidence': 'medium',
          'primary_issue': {'name': 'Overwatering', 'explanation': 'Yellow lower leaves'},
          'alternative_issue': {'name': 'Low light', 'explanation': 'Leggy growth'},
        },
        plantId: 'p',
        photoPath: '/tmp/a.jpg',
      );
      expect(diagnosis.confidence, DiagnosisConfidence.medium);
      expect(diagnosis.alternativeIssue?.name, 'Low light');
    });

    test('low confidence requires follow-up', () {
      final diagnosis = DiagnosisMapper.diagnosisFromGemini(
        json: {
          'confidence': 'low',
          'primary_issue': {'name': 'Thrips', 'explanation': 'a'},
          'second_explanation': {'name': 'Nutrient drop', 'explanation': 'b'},
        },
        plantId: 'p',
        photoPath: '/tmp/a.jpg',
      );
      expect(diagnosis.followUpRequired, isTrue);
      expect(diagnosis.secondExplanation?.name, 'Nutrient drop');
    });

    test('builds up to three treatment steps from Gemini', () {
      final diagnosis = DiagnosisMapper.diagnosisFromGemini(
        json: {
          'confidence': 'high',
          'primary_issue': {'name': 'Dry soil', 'explanation': 'crispy tips'},
          'treatment_steps': [
            {'title': 'Water slowly', 'timing': 'Today', 'method': 'Soak', 'rationale': 'Rehydrate'},
            {'title': 'Move from direct sun', 'timing': 'Today', 'method': 'Shift', 'rationale': 'Reduce stress'},
          ],
        },
        plantId: 'p',
        photoPath: '/tmp/a.jpg',
      );
      final treatment = DiagnosisMapper.treatmentFromGemini(
        json: {
          'treatment_steps': [
            {'title': 'Water slowly', 'timing': 'Today', 'method': 'Soak', 'rationale': 'Rehydrate'},
            {'title': 'Move from direct sun', 'timing': 'Today', 'method': 'Shift', 'rationale': 'Reduce stress'},
          ],
        },
        diagnosis: diagnosis,
      );
      expect(treatment.steps.length, 2);
      expect(treatment.plantId, 'p');
      expect(treatment.diagnosisId, diagnosis.id);
    });
  });

  group('RecoveryLogic', () {
    RecoveryCase _case({
      RecoveryCaseStatus status = RecoveryCaseStatus.awaitingDay3,
      int day3SameCount = 0,
      int day7AdjustmentCount = 0,
      bool usedAlternative = false,
      DateTime? day3CompletedAt,
    }) {
      final opened = DateTime(2026, 9, 1);
      return RecoveryCase(
        id: 'c1',
        plantId: 'p1',
        diagnosisId: 'd1',
        treatmentId: 't1',
        openedAt: opened,
        status: status,
        day3DueAt: RecoveryLogic.day3DueAt(opened),
        day7DueAt: RecoveryLogic.day7DueAt(opened),
        day3SameCount: day3SameCount,
        day7AdjustmentCount: day7AdjustmentCount,
        usedAlternativeTreatment: usedAlternative,
        day3CompletedAt: day3CompletedAt,
      );
    }

    test('day 3 better continues to day 7', () {
      final decision = RecoveryLogic.onDay3(
        recoveryCase: _case(),
        assessment: CheckInAssessment.better,
        now: DateTime(2026, 9, 4),
      );
      expect(decision.nextStatus, RecoveryCaseStatus.awaitingDay7);
      expect(decision.useAlternativeTreatment, isFalse);
    });

    test('day 3 same allows one extra check then day 7', () {
      final first = RecoveryLogic.onDay3(
        recoveryCase: _case(),
        assessment: CheckInAssessment.same,
        now: DateTime(2026, 9, 4),
      );
      expect(first.rescheduleDay3Once, isTrue);
      final second = RecoveryLogic.onDay3(
        recoveryCase: _case(day3SameCount: 1),
        assessment: CheckInAssessment.same,
        now: DateTime(2026, 9, 6),
      );
      expect(second.nextStatus, RecoveryCaseStatus.awaitingDay7);
    });

    test('day 3 worse changes treatment instead of repeating it', () {
      final decision = RecoveryLogic.onDay3(
        recoveryCase: _case(),
        assessment: CheckInAssessment.worse,
        now: DateTime(2026, 9, 4),
      );
      expect(decision.useAlternativeTreatment, isTrue);
      expect(decision.nextStatus, RecoveryCaseStatus.awaitingDay7);
    });

    test('day 7 better after day 3 better closes recovered', () {
      final decision = RecoveryLogic.onDay7(
        recoveryCase: _case(day3CompletedAt: DateTime(2026, 9, 4)),
        assessment: CheckInAssessment.better,
        now: DateTime(2026, 9, 8),
        day3Assessment: CheckInAssessment.better,
      );
      expect(decision.outcome, OutcomeResult.recovered);
    });

    test('day 7 same extends once then unresolved', () {
      final first = RecoveryLogic.onDay7(
        recoveryCase: _case(day3CompletedAt: DateTime(2026, 9, 4)),
        assessment: CheckInAssessment.same,
        now: DateTime(2026, 9, 8),
        day3Assessment: CheckInAssessment.better,
      );
      expect(first.extendOnce, isTrue);
      expect(first.outcome, isNull);
      final second = RecoveryLogic.onDay7(
        recoveryCase: _case(
          day3CompletedAt: DateTime(2026, 9, 4),
          day7AdjustmentCount: 1,
        ),
        assessment: CheckInAssessment.same,
        now: DateTime(2026, 9, 11),
        day3Assessment: CheckInAssessment.better,
      );
      expect(second.outcome, OutcomeResult.unresolved);
    });

    test('missed day 3 can close as unknown and never as recovered', () {
      final opened = DateTime(2026, 9, 1);
      final recoveryCase = RecoveryCase(
        id: 'c1',
        plantId: 'p1',
        diagnosisId: 'd1',
        treatmentId: 't1',
        openedAt: opened,
        status: RecoveryCaseStatus.awaitingDay3,
        day3DueAt: RecoveryLogic.day3DueAt(opened),
        day7DueAt: RecoveryLogic.day7DueAt(opened),
      );
      expect(
        RecoveryLogic.canCloseAsUnknown(recoveryCase, DateTime(2026, 9, 3)),
        isFalse,
      );
      expect(
        RecoveryLogic.canCloseAsUnknown(recoveryCase, DateTime(2026, 9, 6)),
        isTrue,
      );
    });
  });

  group('Outcome record', () {
    test('round-trips all result states', () {
      for (final result in OutcomeResult.values) {
        final outcome = RecoveryOutcome(
          id: 'o1',
          plantId: 'p1',
          recoveryCaseId: 'c1',
          result: result,
          closedAt: DateTime.utc(2026, 9, 10),
          closeReason: 'test',
        );
        final restored = RecoveryOutcome.fromJson(outcome.toJson());
        expect(restored.result, result);
        expect(restored.plantId, 'p1');
      }
    });
  });
}
