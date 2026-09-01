import 'package:hive_flutter/hive_flutter.dart';

import '../model/data_model/recovery_models.dart';

/// Local-first recovery persistence. JSON maps in Hive boxes, same pattern
/// as plant_events_box. No backend.
class RecoveryStore {
  static const diagnosesBox = 'plant_diagnoses_box';
  static const treatmentsBox = 'plant_treatments_box';
  static const casesBox = 'plant_recovery_cases_box';
  static const checkInsBox = 'plant_recovery_checkins_box';
  static const outcomesBox = 'plant_recovery_outcomes_box';

  static Future<void> init() async {
    await Hive.openBox(diagnosesBox);
    await Hive.openBox(treatmentsBox);
    await Hive.openBox(casesBox);
    await Hive.openBox(checkInsBox);
    await Hive.openBox(outcomesBox);
  }

  static Future<void> clearAll() async {
    await Hive.box(diagnosesBox).clear();
    await Hive.box(treatmentsBox).clear();
    await Hive.box(casesBox).clear();
    await Hive.box(checkInsBox).clear();
    await Hive.box(outcomesBox).clear();
  }

  static Future<void> saveDiagnosis(PlantDiagnosis diagnosis) async {
    await Hive.box(diagnosesBox).put(diagnosis.id, diagnosis.toJson());
  }

  static PlantDiagnosis? getDiagnosis(String id) {
    final raw = Hive.box(diagnosesBox).get(id);
    if (raw is! Map) return null;
    return PlantDiagnosis.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<PlantDiagnosis> diagnosesForPlant(String plantId) {
    return _readAll(diagnosesBox, PlantDiagnosis.fromJson)
        .where((d) => d.plantId == plantId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveTreatment(TreatmentPlan treatment) async {
    await Hive.box(treatmentsBox).put(treatment.id, treatment.toJson());
  }

  static TreatmentPlan? getTreatment(String id) {
    final raw = Hive.box(treatmentsBox).get(id);
    if (raw is! Map) return null;
    return TreatmentPlan.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<void> saveCase(RecoveryCase recoveryCase) async {
    await Hive.box(casesBox).put(recoveryCase.id, recoveryCase.toJson());
  }

  static RecoveryCase? getCase(String id) {
    final raw = Hive.box(casesBox).get(id);
    if (raw is! Map) return null;
    return RecoveryCase.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<RecoveryCase> allCases() {
    return _readAll(casesBox, RecoveryCase.fromJson)
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
  }

  static RecoveryCase? activeCaseForPlant(String plantId) {
    for (final recoveryCase in allCases()) {
      if (recoveryCase.plantId == plantId && recoveryCase.status.isOpen) {
        return recoveryCase;
      }
    }
    return null;
  }

  static Future<void> saveCheckIn(RecoveryCheckIn checkIn) async {
    await Hive.box(checkInsBox).put(checkIn.id, checkIn.toJson());
  }

  static List<RecoveryCheckIn> checkInsForCase(String recoveryCaseId) {
    return _readAll(checkInsBox, RecoveryCheckIn.fromJson)
        .where((c) => c.recoveryCaseId == recoveryCaseId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static Future<void> saveOutcome(RecoveryOutcome outcome) async {
    await Hive.box(outcomesBox).put(outcome.id, outcome.toJson());
  }

  static RecoveryOutcome? getOutcome(String id) {
    final raw = Hive.box(outcomesBox).get(id);
    if (raw is! Map) return null;
    return RecoveryOutcome.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<RecoveryOutcome> allOutcomes() {
    return _readAll(outcomesBox, RecoveryOutcome.fromJson)
      ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
  }

  static List<RecoveryOutcome> outcomesForPlant(String plantId) {
    return allOutcomes().where((o) => o.plantId == plantId).toList();
  }

  static List<T> _readAll<T>(
    String boxName,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = <T>[];
    for (final raw in Hive.box(boxName).values) {
      if (raw is! Map) continue;
      try {
        items.add(fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    return items;
  }
}
