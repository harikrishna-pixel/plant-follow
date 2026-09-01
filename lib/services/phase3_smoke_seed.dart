import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/data_model/folder_model.dart';
import '../model/data_model/plant_model.dart';
import '../model/data_model/recovery_models.dart';
import '../model/data_model/reminder_model.dart';
import 'plant_local.dart';
import 'recovery_store.dart';

/// Debug-only fixture for Phase 3 simulator smoke.
/// Compiled in only when running with `--dart-define=PHASE3_SMOKE=true`.
class Phase3SmokeSeed {
  static const enabled = bool.fromEnvironment('PHASE3_SMOKE');

  static const _seededKey = 'phase3_smoke_seeded';
  static const monsteraId = 'phase3-smoke-monstera';
  static const pothosId = 'phase3-smoke-pothos';
  static const fernId = 'phase3-smoke-fern';
  static const day3CaseId = 'phase3-smoke-case-day3';
  static const day7CaseId = 'phase3-smoke-case-day7';
  static const reminderId = 'phase3-smoke-water';
  static const folderId = 'phase3-smoke-folder';

  static String? samplePhotoPath;

  static Future<void> maybeSeed() async {
    if (!enabled) return;

    final dir = await getApplicationDocumentsDirectory();
    final photo = File('${dir.path}/phase3_smoke_plant.jpg');
    if (!photo.existsSync()) {
      final bytes = await rootBundle.load('assets/logo.png');
      await photo.writeAsBytes(bytes.buffer.asUint8List());
    }
    samplePhotoPath = photo.path;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch_complete', true);
    await prefs.setBool('first_launch', false);
    await prefs.setBool('intro_video_shown', true);
    await prefs.setBool('first_time_home', false);

    if (prefs.getBool(_seededKey) == true) return;

    final now = DateTime.now();
    await _ensurePlant(monsteraId, 'Monstera', photo.path);
    await _ensurePlant(pothosId, 'Pothos', photo.path);
    await _ensurePlant(fernId, 'Fern', photo.path);
    await _ensureFolder(prefs);
    await _ensureReminder(prefs, now);
    await _ensureDay3Case(now, photo.path);
    await _ensureDay7Case(now, photo.path);

    await prefs.setBool(_seededKey, true);
  }

  static Plant _plant(String id, String name, String imagePath) {
    return Plant(
      id: id,
      name: name,
      scientificName: name,
      description: 'Phase 3 smoke fixture. Placement unknown — indoor/outdoor not set.',
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
      imagePath: imagePath,
    );
  }

  static Future<void> _ensurePlant(String id, String name, String imagePath) async {
    final existing = await LocalStorageService.getFavorites();
    if (existing.any((p) => p.id == id)) return;
    await LocalStorageService.saveFavorite(_plant(id, name, imagePath));
  }

  static Future<void> _ensureFolder(SharedPreferences prefs) async {
    const key = 'plant_folders';
    final raw = prefs.getString(key);
    final folders = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        folders.addAll(
          decoded.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    }
    if (folders.any((f) => f['id'] == folderId)) return;
    folders.add(
      PlantFolder(
        id: folderId,
        name: 'Smoke garden',
        description: 'Phase 3 verification folder',
        createdAt: DateTime.now(),
        plantIds: const [monsteraId, pothosId, fernId],
      ).toJson(),
    );
    await prefs.setString(key, jsonEncode(folders));
  }

  static Future<void> _ensureReminder(
    SharedPreferences prefs,
    DateTime now,
  ) async {
    const key = 'plant_reminders';
    final raw = prefs.getString(key);
    final reminders = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        reminders.addAll(
          decoded.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    }
    if (reminders.any((r) => r['id'] == reminderId)) return;
    reminders.add(
      PlantReminder(
        id: reminderId,
        plantName: 'Fern',
        plantId: fernId,
        taskType: 'Water',
        dateTime: DateTime(now.year, now.month, now.day, 9),
        createdAt: now,
      ).toJson(),
    );
    await prefs.setString(key, jsonEncode(reminders));
  }

  static Future<void> _ensureDay3Case(DateTime now, String photoPath) async {
    if (RecoveryStore.getCase(day3CaseId) != null) return;
    const diagnosisId = 'phase3-smoke-diag-day3';
    const treatmentId = 'phase3-smoke-treat-day3';
    await RecoveryStore.saveDiagnosis(
      PlantDiagnosis(
        id: diagnosisId,
        plantId: monsteraId,
        createdAt: now.subtract(const Duration(days: 3)),
        photoPath: photoPath,
        confidence: DiagnosisConfidence.medium,
        primaryIssue: const DiagnosisIssue(
          name: 'dry leaf edges',
          explanation: 'Leaf margins look dry.',
        ),
        firstAid: const FirstAidAction(action: 'Water slowly today'),
        plantName: 'Monstera',
      ),
    );
    await RecoveryStore.saveTreatment(
      TreatmentPlan(
        id: treatmentId,
        plantId: monsteraId,
        diagnosisId: diagnosisId,
        recoveryCaseId: day3CaseId,
        createdAt: now.subtract(const Duration(days: 3)),
        steps: [
          TreatmentStep(
            id: 'phase3-smoke-step-1',
            order: 1,
            title: 'Water slowly',
            timing: 'Today',
            method: 'Soak the soil, then drain.',
            rationale: 'Gentle first step.',
          ),
        ],
      ),
    );
    final opened = now.subtract(const Duration(days: 3));
    await RecoveryStore.saveCase(
      RecoveryCase(
        id: day3CaseId,
        plantId: monsteraId,
        diagnosisId: diagnosisId,
        treatmentId: treatmentId,
        openedAt: opened,
        status: RecoveryCaseStatus.awaitingDay3,
        day3DueAt: now.subtract(const Duration(hours: 1)),
        day7DueAt: opened.add(const Duration(days: 7)),
        originalPhotoPath: photoPath,
      ),
    );
  }

  static Future<void> _ensureDay7Case(DateTime now, String photoPath) async {
    if (RecoveryStore.getCase(day7CaseId) != null) return;
    const diagnosisId = 'phase3-smoke-diag-day7';
    const treatmentId = 'phase3-smoke-treat-day7';
    await RecoveryStore.saveDiagnosis(
      PlantDiagnosis(
        id: diagnosisId,
        plantId: pothosId,
        createdAt: now.subtract(const Duration(days: 7)),
        photoPath: photoPath,
        confidence: DiagnosisConfidence.high,
        primaryIssue: const DiagnosisIssue(
          name: 'yellowing leaves',
          explanation: 'Lower leaves have yellowed.',
        ),
        firstAid: const FirstAidAction(action: 'Check the soil moisture'),
        plantName: 'Pothos',
      ),
    );
    await RecoveryStore.saveTreatment(
      TreatmentPlan(
        id: treatmentId,
        plantId: pothosId,
        diagnosisId: diagnosisId,
        recoveryCaseId: day7CaseId,
        createdAt: now.subtract(const Duration(days: 7)),
        steps: [
          TreatmentStep(
            id: 'phase3-smoke-step-day7',
            order: 1,
            title: 'Let the soil dry a little',
            timing: 'This week',
            method: 'Wait until the top feels dry.',
            rationale: 'Gentle first step.',
          ),
        ],
      ),
    );
    final opened = now.subtract(const Duration(days: 7));
    await RecoveryStore.saveCase(
      RecoveryCase(
        id: day7CaseId,
        plantId: pothosId,
        diagnosisId: diagnosisId,
        treatmentId: treatmentId,
        openedAt: opened,
        status: RecoveryCaseStatus.awaitingDay7,
        day3DueAt: opened.add(const Duration(days: 3)),
        day7DueAt: now.subtract(const Duration(hours: 1)),
        day3CompletedAt: opened.add(const Duration(days: 3)),
        originalPhotoPath: photoPath,
      ),
    );
  }
}
