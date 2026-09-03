import '../model/data_model/plant_event.dart';
import '../model/data_model/recovery_models.dart';

/// Projection over existing recovery + event data. Not a second timeline.
class ProgressSnapshot {
  final List<RecoveryCase> activeRecoveries;
  final List<RecoveryOutcome> recentOutcomes;
  final List<PlantEvent> recentProgress;

  const ProgressSnapshot({
    required this.activeRecoveries,
    required this.recentOutcomes,
    required this.recentProgress,
  });

  bool get isEmpty =>
      activeRecoveries.isEmpty &&
      recentOutcomes.isEmpty &&
      recentProgress.isEmpty;

  static const emptyTitle = 'Your progress starts here';
  static const emptySubtitle =
      'As you care for your plants, check-backs and milestones will appear here.';
  static const identifyCta = 'Identify a plant';
  static const plantsCta = 'View your plants';
}

class ProgressLogic {
  ProgressLogic._();

  static const recentLimit = 8;

  static const _progressTypes = {
    PlantEventType.careCompletion,
    PlantEventType.milestone,
    PlantEventType.harvest,
    PlantEventType.outcome,
    PlantEventType.recoveryCheckIn,
  };

  static ProgressSnapshot from({
    required List<RecoveryCase> cases,
    required List<RecoveryOutcome> outcomes,
    required List<PlantEvent> events,
  }) {
    final active = cases.where((c) => c.status.isOpen).toList()
      ..sort((a, b) {
        final aDue = a.day3CompletedAt == null ? a.day3DueAt : a.day7DueAt;
        final bDue = b.day3CompletedAt == null ? b.day3DueAt : b.day7DueAt;
        return aDue.compareTo(bDue);
      });
    final recentOutcomes = List<RecoveryOutcome>.from(outcomes)
      ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
    final recentProgress = events.where((e) => _progressTypes.contains(e.eventType)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ProgressSnapshot(
      activeRecoveries: active,
      recentOutcomes: recentOutcomes.take(recentLimit).toList(),
      recentProgress: recentProgress.take(recentLimit).toList(),
    );
  }
}
