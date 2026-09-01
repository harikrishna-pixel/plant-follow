import '../model/data_model/care_rule.dart';
import '../model/data_model/recovery_models.dart';
import 'care_logic.dart';
import 'recovery_logic.dart';

class PlantHealthView {
  final bool hasActiveRecovery;
  final String headline;
  final String body;
  final String? issueName;
  final String? confidenceLabel;
  final String? stageLabel;
  final String? nextCheckInLabel;
  final int treatmentDone;
  final int treatmentTotal;
  final OutcomeResult? latestOutcome;

  const PlantHealthView({
    required this.hasActiveRecovery,
    required this.headline,
    required this.body,
    this.issueName,
    this.confidenceLabel,
    this.stageLabel,
    this.nextCheckInLabel,
    this.treatmentDone = 0,
    this.treatmentTotal = 0,
    this.latestOutcome,
  });

  static const emptyHeadline = 'No active recovery';
  static const emptyBody = 'Nothing needs treatment right now.';
}

class PlantHealthPresenter {
  PlantHealthPresenter._();

  static PlantHealthView fromState({
    required DateTime now,
    RecoveryCase? activeCase,
    PlantDiagnosis? diagnosis,
    TreatmentPlan? treatment,
    List<RecoveryOutcome> outcomes = const [],
  }) {
    if (activeCase == null || !activeCase.status.isOpen) {
      final latest = outcomes.isEmpty ? null : outcomes.first;
      return PlantHealthView(
        hasActiveRecovery: false,
        headline: PlantHealthView.emptyHeadline,
        body: latest == null
            ? PlantHealthView.emptyBody
            : 'Last outcome: ${latest.result.label}.',
        latestOutcome: latest?.result,
        issueName: diagnosis?.primaryIssue.name.trim().isNotEmpty == true
            ? diagnosis!.primaryIssue.name.trim()
            : null,
      );
    }

    final issue = diagnosis?.primaryIssue.name.trim() ?? '';
    final due = RecoveryLogic.checkInDue(activeCase, now);
    final done = treatment?.steps.where((s) => s.isCompleted).length ?? 0;
    final total = treatment?.steps.length ?? 0;
    return PlantHealthView(
      hasActiveRecovery: true,
      headline: issue.isEmpty ? 'Recovery in progress' : issue,
      body: due == null
          ? 'Recovery is underway.'
          : due.isOverdue
          ? 'Check-in is waiting whenever you are ready.'
          : 'A check-in is due.',
      issueName: issue.isEmpty ? null : issue,
      confidenceLabel: diagnosis == null
          ? null
          : '${diagnosis.confidence.wireName[0].toUpperCase()}${diagnosis.confidence.wireName.substring(1)} confidence',
      stageLabel:
          activeCase.status == RecoveryCaseStatus.awaitingDay7 ||
              activeCase.day3CompletedAt != null
          ? 'Day 7 check-in'
          : 'Day 3 check-in',
      nextCheckInLabel: due == null
          ? null
          : due.stage == CheckInStage.day3
          ? 'Day 3'
          : 'Day 7',
      treatmentDone: done,
      treatmentTotal: total,
    );
  }
}

class PlantDetailStatus {
  PlantDetailStatus._();

  /// One-line answer to “How is this plant doing?”
  static String howIsItDoing({
    required DateTime now,
    RecoveryCase? activeCase,
    List<CareRule> careRules = const [],
  }) {
    if (activeCase != null && activeCase.status.isOpen) {
      final due = RecoveryLogic.checkInDue(activeCase, now);
      if (due != null) {
        final stage = due.stage == CheckInStage.day3 ? 'Day 3' : 'Day 7';
        return due.isOverdue
            ? '$stage check-in is still waiting.'
            : '$stage check-in is due.';
      }
      return 'Recovery in progress.';
    }
    final dueCare = careRules.where((r) => CareLogic.isDue(r, now)).toList();
    if (dueCare.isNotEmpty) {
      final label = CareLogic.displayType(dueCare.first.careType);
      return label.isEmpty ? 'Care is due.' : '$label is due.';
    }
    return PlantHealthView.emptyHeadline;
  }
}
