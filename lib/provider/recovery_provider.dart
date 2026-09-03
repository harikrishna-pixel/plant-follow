import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../model/data_model/plant_event.dart';
import '../model/data_model/plant_model.dart';
import '../model/data_model/recovery_models.dart';
import '../services/diagnosis_mapper.dart';
import '../services/notification_service.dart';
import '../services/plant_local.dart';
import '../services/recovery_logic.dart';
import '../services/recovery_store.dart';

class RecoveryProvider extends ChangeNotifier {
  List<RecoveryCase> _cases = [];
  List<RecoveryOutcome> _outcomes = [];

  List<RecoveryCase> get cases => List.unmodifiable(_cases);
  List<RecoveryOutcome> get outcomes => List.unmodifiable(_outcomes);

  RecoveryProvider() {
    reload();
  }

  void reload() {
    _cases = RecoveryStore.allCases();
    _outcomes = RecoveryStore.allOutcomes();
    notifyListeners();
  }

  RecoveryCase? activeCaseForPlant(String plantId) {
    return RecoveryStore.activeCaseForPlant(plantId);
  }

  List<RecoveryOutcome> outcomesForPlant(String plantId) {
    return _outcomes.where((o) => o.plantId == plantId).toList()
      ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
  }

  PlantDiagnosis? diagnosisById(String id) => RecoveryStore.getDiagnosis(id);

  TreatmentPlan? treatmentById(String id) => RecoveryStore.getTreatment(id);

  List<RecoveryCheckIn> checkInsForCase(String caseId) =>
      RecoveryStore.checkInsForCase(caseId);

  CheckInAssessment? day3Assessment(String caseId) {
    for (final checkIn in RecoveryStore.checkInsForCase(caseId)) {
      if (checkIn.stage == CheckInStage.day3) return checkIn.assessment;
    }
    return null;
  }

  Future<PlantDiagnosis?> tryPersistDiagnosisFromGemini({
    required Map<String, dynamic> geminiJson,
    required Plant plant,
    required String photoPath,
  }) async {
    if (!DiagnosisMapper.canPersist(geminiJson)) {
      return null;
    }
    return persistDiagnosisFromGemini(
      geminiJson: geminiJson,
      plant: plant,
      photoPath: photoPath,
    );
  }

  Future<PlantDiagnosis> persistDiagnosisFromGemini({
    required Map<String, dynamic> geminiJson,
    required Plant plant,
    required String photoPath,
  }) async {
    if (!DiagnosisMapper.canPersist(geminiJson)) {
      throw StateError('Invalid diagnosis payload cannot be persisted');
    }
    final diagnosis = DiagnosisMapper.diagnosisFromGemini(
      json: geminiJson,
      plantId: plant.id,
      photoPath: photoPath,
    );
    await RecoveryStore.saveDiagnosis(diagnosis);
    await LocalStorageService.appendPlantEvent(
      PlantEvent(
        id: newRecoveryId(),
        plantId: plant.id,
        eventType: PlantEventType.diagnosis,
        timestamp: diagnosis.createdAt,
        payload: {
          'diagnosisId': diagnosis.id,
          'confidence': diagnosis.confidence.wireName,
          'primaryIssue': diagnosis.primaryIssue.name,
        },
        source: 'gemini',
      ),
    );
    reload();
    return diagnosis;
  }

  TreatmentPlan draftTreatment({
    required Map<String, dynamic> geminiJson,
    required PlantDiagnosis diagnosis,
    bool alternative = false,
  }) {
    return DiagnosisMapper.treatmentFromGemini(
      json: geminiJson,
      diagnosis: diagnosis,
      alternative: alternative,
    );
  }

  Future<RecoveryCase> startRecovery({
    required Plant plant,
    required PlantDiagnosis diagnosis,
    required TreatmentPlan treatment,
  }) async {
    final now = DateTime.now();
    final caseId = newRecoveryId();
    var linkedTreatment = treatment.copyWith(recoveryCaseId: caseId);
    await RecoveryStore.saveTreatment(linkedTreatment);

    final recoveryCase = RecoveryCase(
      id: caseId,
      plantId: plant.id,
      diagnosisId: diagnosis.id,
      treatmentId: linkedTreatment.id,
      openedAt: now,
      status: RecoveryCaseStatus.awaitingDay3,
      day3DueAt: RecoveryLogic.day3DueAt(now),
      day7DueAt: RecoveryLogic.day7DueAt(now),
      originalPhotoPath: diagnosis.photoPath,
    );
    await RecoveryStore.saveCase(recoveryCase);
    await LocalStorageService.appendPlantEvent(
      PlantEvent(
        id: newRecoveryId(),
        plantId: plant.id,
        eventType: PlantEventType.treatment,
        timestamp: now,
        payload: {
          'action': 'started',
          'treatmentId': linkedTreatment.id,
          'recoveryCaseId': caseId,
        },
        source: 'recovery',
      ),
    );
    await _scheduleCheckBackNotifications(recoveryCase, plant.name);
    reload();
    return recoveryCase;
  }

  String checkBackSentence(RecoveryCase recoveryCase) {
    final due = recoveryCase.status == RecoveryCaseStatus.awaitingDay7
        ? recoveryCase.day7DueAt
        : recoveryCase.day3DueAt;
    final day = DateFormat('EEEE').format(due);
    return "I'll check back on $day.";
  }

  Future<void> completeTreatmentStep({
    required TreatmentPlan treatment,
    required String stepId,
  }) async {
    final now = DateTime.now();
    final steps = treatment.steps.map((step) {
      if (step.id == stepId && step.completedAt == null) {
        return step.copyWith(completedAt: now);
      }
      return step;
    }).toList();
    final updated = treatment.copyWith(steps: steps);
    await RecoveryStore.saveTreatment(updated);
    await LocalStorageService.appendPlantEvent(
      PlantEvent(
        id: newRecoveryId(),
        plantId: treatment.plantId,
        eventType: PlantEventType.treatment,
        timestamp: now,
        payload: {
          'action': 'step_completed',
          'treatmentId': treatment.id,
          'stepId': stepId,
          'recoveryCaseId': treatment.recoveryCaseId,
        },
        source: 'recovery',
      ),
    );
    reload();
  }

  Future<void> deferTreatment(RecoveryCase recoveryCase) async {
    final next = RecoveryLogic.deferByTwoDays(DateTime.now());
    final updated = recoveryCase.copyWith(
      deferredUntil: next,
      day3DueAt: recoveryCase.day3CompletedAt == null
          ? next
          : recoveryCase.day3DueAt,
    );
    await RecoveryStore.saveCase(updated);
    await NotificationService.cancelNotification(_day3Id(recoveryCase.id));
    await NotificationService.cancelNotification(_missedId(recoveryCase.id));
    if (recoveryCase.day3CompletedAt == null) {
      await NotificationService.scheduleNotification(
        id: _day3Id(recoveryCase.id),
        title: 'PlantFollow check-in',
        body: "Whenever you're ready — I'll check back then.",
        scheduledDate: next,
      );
      await NotificationService.scheduleNotification(
        id: _missedId(recoveryCase.id),
        title: 'PlantFollow',
        body: 'No rush. Your plant check-in is still here when you have a moment.',
        scheduledDate: RecoveryLogic.missedDay3ReminderAt(next),
      );
    }
    reload();
  }

  Future<RecoveryCase> recordCheckIn({
    required RecoveryCase recoveryCase,
    required CheckInStage stage,
    required CheckInAssessment assessment,
    required String photoPath,
    String? note,
  }) async {
    final now = DateTime.now();
    final checkIn = RecoveryCheckIn(
      id: newRecoveryId(),
      recoveryCaseId: recoveryCase.id,
      plantId: recoveryCase.plantId,
      createdAt: now,
      stage: stage,
      photoPath: photoPath,
      assessment: assessment,
      note: note,
    );
    await RecoveryStore.saveCheckIn(checkIn);
    await LocalStorageService.appendPlantEvent(
      PlantEvent(
        id: newRecoveryId(),
        plantId: recoveryCase.plantId,
        eventType: PlantEventType.recoveryCheckIn,
        timestamp: now,
        payload: {
          'checkInId': checkIn.id,
          'recoveryCaseId': recoveryCase.id,
          'stage': stage.wireName,
          'assessment': assessment.wireName,
        },
        source: 'user',
      ),
    );
    await LocalStorageService.appendPlantEvent(
      PlantEvent(
        id: newRecoveryId(),
        plantId: recoveryCase.plantId,
        eventType: PlantEventType.plantPhoto,
        timestamp: now,
        payload: {
          'purpose': 'check-in',
          'photoPath': photoPath,
          'recoveryCaseId': recoveryCase.id,
          'stage': stage.wireName,
        },
        source: 'user',
      ),
    );

    var nextCase = recoveryCase;
    final geminiJson =
        RecoveryStore.getDiagnosis(recoveryCase.diagnosisId)?.rawPayload ?? {};
    if (stage == CheckInStage.day3) {
      nextCase = await _applyDay3(recoveryCase, assessment, now, geminiJson);
      await NotificationService.cancelNotification(_day3Id(recoveryCase.id));
      await NotificationService.cancelNotification(_missedId(recoveryCase.id));
    } else {
      nextCase = await _applyDay7(recoveryCase, assessment, now, geminiJson);
      await NotificationService.cancelNotification(_day7Id(recoveryCase.id));
    }
    reload();
    return nextCase;
  }

  Future<RecoveryOutcome> closeCase({
    required RecoveryCase recoveryCase,
    required OutcomeResult result,
    required String closeReason,
    String? note,
  }) async {
    final now = DateTime.now();
    final outcome = RecoveryOutcome(
      id: newRecoveryId(),
      plantId: recoveryCase.plantId,
      recoveryCaseId: recoveryCase.id,
      result: result,
      closedAt: now,
      closeReason: closeReason,
      note: note,
    );
    await RecoveryStore.saveOutcome(outcome);

    RecoveryCaseStatus status;
    switch (result) {
      case OutcomeResult.recovered:
        status = RecoveryCaseStatus.recovered;
        break;
      case OutcomeResult.improved:
        status = RecoveryCaseStatus.improved;
        break;
      case OutcomeResult.lost:
        status = RecoveryCaseStatus.lost;
        break;
      case OutcomeResult.unknown:
        status = RecoveryCaseStatus.unknown;
        break;
      case OutcomeResult.unresolved:
        status = RecoveryCaseStatus.unresolved;
        break;
    }

    final closed = recoveryCase.copyWith(
      status: status,
      closedAt: now,
      outcomeId: outcome.id,
    );
    await RecoveryStore.saveCase(closed);
    await LocalStorageService.appendPlantEvent(
      PlantEvent(
        id: newRecoveryId(),
        plantId: recoveryCase.plantId,
        eventType: PlantEventType.outcome,
        timestamp: now,
        payload: {
          'outcomeId': outcome.id,
          'recoveryCaseId': recoveryCase.id,
          'result': result.wireName,
          'closeReason': closeReason,
        },
        source: 'recovery',
      ),
    );
    await _cancelCaseNotifications(recoveryCase.id);
    reload();
    return outcome;
  }

  Future<void> markMissedReminderIfNeeded(RecoveryCase recoveryCase) async {
    final now = DateTime.now();
    if (!RecoveryLogic.shouldMarkMissedReminderSent(recoveryCase, now)) {
      return;
    }
    await RecoveryStore.saveCase(
      recoveryCase.copyWith(missedDay3ReminderSent: true),
    );
    reload();
  }

  Future<RecoveryCase> _applyDay3(
    RecoveryCase recoveryCase,
    CheckInAssessment assessment,
    DateTime now,
    Map<String, dynamic> geminiJson,
  ) async {
    final decision = RecoveryLogic.onDay3(
      recoveryCase: recoveryCase,
      assessment: assessment,
      now: now,
    );
    var treatmentId = recoveryCase.treatmentId;
    var usedAlternative = recoveryCase.usedAlternativeTreatment;
    if (decision.useAlternativeTreatment && !usedAlternative) {
      treatmentId = await _switchToAlternative(recoveryCase, geminiJson);
      usedAlternative = true;
    }
    var next = recoveryCase.copyWith(
      treatmentId: treatmentId,
      status: decision.nextStatus,
      day3CompletedAt: now,
      day3SameCount: decision.rescheduleDay3Once
          ? recoveryCase.day3SameCount + 1
          : recoveryCase.day3SameCount,
      day3DueAt: decision.nextDay3DueAt ?? recoveryCase.day3DueAt,
      usedAlternativeTreatment: usedAlternative,
    );
    await RecoveryStore.saveCase(next);
    if (decision.rescheduleDay3Once && decision.nextDay3DueAt != null) {
      await NotificationService.scheduleNotification(
        id: _day3Id(recoveryCase.id),
        title: 'PlantFollow check-in',
        body: checkBackSentence(next),
        scheduledDate: decision.nextDay3DueAt!,
      );
    }
    return next;
  }

  Future<RecoveryCase> _applyDay7(
    RecoveryCase recoveryCase,
    CheckInAssessment assessment,
    DateTime now,
    Map<String, dynamic> geminiJson,
  ) async {
    final decision = RecoveryLogic.onDay7(
      recoveryCase: recoveryCase,
      assessment: assessment,
      now: now,
      day3Assessment: day3Assessment(recoveryCase.id),
    );
    var treatmentId = recoveryCase.treatmentId;
    var usedAlternative = recoveryCase.usedAlternativeTreatment;
    if (decision.useAlternativeTreatment && !usedAlternative) {
      treatmentId = await _switchToAlternative(recoveryCase, geminiJson);
      usedAlternative = true;
    }
    var next = recoveryCase.copyWith(
      treatmentId: treatmentId,
      status: decision.nextStatus,
      day7CompletedAt: decision.outcome == null ? null : now,
      day7AdjustmentCount: decision.extendOnce
          ? recoveryCase.day7AdjustmentCount + 1
          : recoveryCase.day7AdjustmentCount,
      day7DueAt: decision.nextDay7DueAt ?? recoveryCase.day7DueAt,
      usedAlternativeTreatment: usedAlternative,
    );
    if (decision.extendOnce && decision.outcome == null) {
      next = next.copyWith(day7CompletedAt: null);
    } else {
      next = next.copyWith(day7CompletedAt: now);
    }
    await RecoveryStore.saveCase(next);
    if (decision.outcome != null && decision.closeReason != null) {
      await closeCase(
        recoveryCase: next,
        result: decision.outcome!,
        closeReason: decision.closeReason!,
      );
      return RecoveryStore.getCase(recoveryCase.id) ?? next;
    }
    if (decision.extendOnce && decision.nextDay7DueAt != null) {
      await NotificationService.scheduleNotification(
        id: _day7Id(recoveryCase.id),
        title: 'PlantFollow check-in',
        body: checkBackSentence(next),
        scheduledDate: decision.nextDay7DueAt!,
      );
    }
    return next;
  }

  Future<String> _switchToAlternative(
    RecoveryCase recoveryCase,
    Map<String, dynamic> geminiJson,
  ) async {
    final diagnosis = RecoveryStore.getDiagnosis(recoveryCase.diagnosisId);
    final current = RecoveryStore.getTreatment(recoveryCase.treatmentId);
    late TreatmentPlan next;
    if (diagnosis != null) {
      next = DiagnosisMapper.treatmentFromGemini(
        json: geminiJson,
        diagnosis: diagnosis,
        alternative: true,
      );
    } else if (current != null) {
      next = current.copyWith(
        steps: RecoveryLogic.alternativeSteps(current.steps),
        adjustedFromTreatmentId: current.id,
      );
    } else {
      return recoveryCase.treatmentId;
    }
    next = next.copyWith(
      recoveryCaseId: recoveryCase.id,
      adjustedFromTreatmentId: recoveryCase.treatmentId,
    );
    await RecoveryStore.saveTreatment(next);
    await LocalStorageService.appendPlantEvent(
      PlantEvent(
        id: newRecoveryId(),
        plantId: recoveryCase.plantId,
        eventType: PlantEventType.treatment,
        timestamp: DateTime.now(),
        payload: {
          'action': 'started',
          'treatmentId': next.id,
          'recoveryCaseId': recoveryCase.id,
          'alternative': true,
        },
        source: 'recovery',
      ),
    );
    return next.id;
  }

  Future<void> _scheduleCheckBackNotifications(
    RecoveryCase recoveryCase,
    String plantName,
  ) async {
    final plantLabel = plantName.isEmpty ? 'your plant' : plantName;
    await NotificationService.scheduleNotification(
      id: _day3Id(recoveryCase.id),
      title: 'PlantFollow',
      body: "${checkBackSentence(recoveryCase)} How is $plantLabel looking?",
      scheduledDate: recoveryCase.day3DueAt,
    );
    await NotificationService.scheduleNotification(
      id: _missedId(recoveryCase.id),
      title: 'PlantFollow',
        body: 'No rush — $plantLabel check-in is still waiting when you have a moment.',
      scheduledDate: RecoveryLogic.missedDay3ReminderAt(recoveryCase.day3DueAt),
    );
    await NotificationService.scheduleNotification(
      id: _day7Id(recoveryCase.id),
      title: 'PlantFollow',
      body: 'Time for a follow-up look at $plantLabel.',
      scheduledDate: recoveryCase.day7DueAt,
    );
  }

  Future<void> _cancelCaseNotifications(String caseId) async {
    await NotificationService.cancelNotification(_day3Id(caseId));
    await NotificationService.cancelNotification(_day7Id(caseId));
    await NotificationService.cancelNotification(_missedId(caseId));
  }

  int _day3Id(String caseId) => _stableId('d3-$caseId');
  int _day7Id(String caseId) => _stableId('d7-$caseId');
  int _missedId(String caseId) => _stableId('dm-$caseId');

  int _stableId(String key) => key.hashCode & 0x7fffffff;
}
