import '../model/data_model/recovery_models.dart';

class Day3Decision {
  final RecoveryCaseStatus nextStatus;
  final bool useAlternativeTreatment;
  final bool rescheduleDay3Once;
  final DateTime? nextDay3DueAt;

  const Day3Decision({
    required this.nextStatus,
    this.useAlternativeTreatment = false,
    this.rescheduleDay3Once = false,
    this.nextDay3DueAt,
  });
}

class Day7Decision {
  final RecoveryCaseStatus nextStatus;
  final OutcomeResult? outcome;
  final String? closeReason;
  final bool useAlternativeTreatment;
  final bool extendOnce;
  final DateTime? nextDay7DueAt;

  const Day7Decision({
    required this.nextStatus,
    this.outcome,
    this.closeReason,
    this.useAlternativeTreatment = false,
    this.extendOnce = false,
    this.nextDay7DueAt,
  });
}

/// A due Day 3 or Day 7 check-in, derived from Recovery Case state.
/// Today reads this; it does not keep a second recovery state machine.
class RecoveryCheckDue {
  final CheckInStage stage;
  final DateTime dueAt;
  final bool isOverdue;

  const RecoveryCheckDue({
    required this.stage,
    required this.dueAt,
    required this.isOverdue,
  });
}

/// Pure recovery state transitions. No I/O.
class RecoveryLogic {
  static DateTime day3DueAt(DateTime openedAt) =>
      openedAt.add(const Duration(days: 3));

  static DateTime day7DueAt(DateTime openedAt) =>
      openedAt.add(const Duration(days: 7));

  static DateTime missedDay3ReminderAt(DateTime day3DueAt) =>
      day3DueAt.add(const Duration(days: 1));

  static DateTime deferByTwoDays(DateTime from) =>
      from.add(const Duration(days: 2));

  /// Returns a check-in that should surface on Today, or null if none is due.
  /// Uses calendar day so a morning visit still shows a same-day due.
  static RecoveryCheckDue? checkInDue(RecoveryCase recoveryCase, DateTime now) {
    if (!recoveryCase.status.isOpen) return null;

    late final CheckInStage stage;
    late DateTime dueAt;
    if (recoveryCase.status == RecoveryCaseStatus.awaitingDay7 ||
        recoveryCase.day3CompletedAt != null) {
      stage = CheckInStage.day7;
      dueAt = recoveryCase.day7DueAt;
    } else {
      stage = CheckInStage.day3;
      dueAt = recoveryCase.day3DueAt;
      final deferred = recoveryCase.deferredUntil;
      if (deferred != null && deferred.isAfter(dueAt)) {
        dueAt = deferred;
      }
    }

    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(dueDay)) return null;

    return RecoveryCheckDue(
      stage: stage,
      dueAt: dueAt,
      isOverdue: now.isAfter(dueAt),
    );
  }

  static Day3Decision onDay3({
    required RecoveryCase recoveryCase,
    required CheckInAssessment assessment,
    required DateTime now,
  }) {
    switch (assessment) {
      case CheckInAssessment.better:
        return const Day3Decision(nextStatus: RecoveryCaseStatus.awaitingDay7);
      case CheckInAssessment.same:
        if (recoveryCase.day3SameCount == 0) {
          return Day3Decision(
            nextStatus: RecoveryCaseStatus.awaitingDay3,
            rescheduleDay3Once: true,
            nextDay3DueAt: now.add(const Duration(days: 2)),
          );
        }
        return const Day3Decision(nextStatus: RecoveryCaseStatus.awaitingDay7);
      case CheckInAssessment.worse:
        return const Day3Decision(
          nextStatus: RecoveryCaseStatus.awaitingDay7,
          useAlternativeTreatment: true,
        );
    }
  }

  static Day7Decision onDay7({
    required RecoveryCase recoveryCase,
    required CheckInAssessment assessment,
    required DateTime now,
    required CheckInAssessment? day3Assessment,
  }) {
    switch (assessment) {
      case CheckInAssessment.better:
        if (day3Assessment == CheckInAssessment.better) {
          return const Day7Decision(
            nextStatus: RecoveryCaseStatus.recovered,
            outcome: OutcomeResult.recovered,
            closeReason: 'day7_better_after_day3_better',
          );
        }
        return const Day7Decision(
          nextStatus: RecoveryCaseStatus.improved,
          outcome: OutcomeResult.improved,
          closeReason: 'day7_better_not_fully_resolved',
        );
      case CheckInAssessment.same:
        if (recoveryCase.day7AdjustmentCount == 0) {
          return Day7Decision(
            nextStatus: RecoveryCaseStatus.awaitingDay7,
            extendOnce: true,
            nextDay7DueAt: now.add(const Duration(days: 3)),
          );
        }
        return const Day7Decision(
          nextStatus: RecoveryCaseStatus.unresolved,
          outcome: OutcomeResult.unresolved,
          closeReason: 'day7_same_after_adjustment',
        );
      case CheckInAssessment.worse:
        if (!recoveryCase.usedAlternativeTreatment) {
          return Day7Decision(
            nextStatus: RecoveryCaseStatus.awaitingDay7,
            useAlternativeTreatment: true,
            extendOnce: true,
            nextDay7DueAt: now.add(const Duration(days: 3)),
          );
        }
        return const Day7Decision(
          nextStatus: RecoveryCaseStatus.unresolved,
          outcome: OutcomeResult.unresolved,
          closeReason: 'day7_worse_after_alternative',
        );
    }
  }

  static bool canCloseAsUnknown(RecoveryCase recoveryCase, DateTime now) {
    if (recoveryCase.day3CompletedAt != null) return false;
    if (!recoveryCase.status.isOpen) return false;
    return now.isAfter(missedDay3ReminderAt(recoveryCase.day3DueAt));
  }

  static bool shouldMarkMissedReminderSent(
    RecoveryCase recoveryCase,
    DateTime now,
  ) {
    if (recoveryCase.missedDay3ReminderSent) return false;
    if (recoveryCase.day3CompletedAt != null) return false;
    return !now.isBefore(missedDay3ReminderAt(recoveryCase.day3DueAt));
  }

  static List<TreatmentStep> alternativeSteps(List<TreatmentStep> current) {
    return current
        .map(
          (step) => TreatmentStep(
            id: newRecoveryId(),
            order: step.order,
            title: 'Try a different approach: ${step.title}',
            timing: step.timing,
            method:
                'Do not intensify the previous method. Change the approach: ${step.method}',
            rationale:
                'The first plan did not help. A different, still gentle method is safer than repeating the same advice more aggressively.',
            irreversibleWarning: step.irreversibleWarning,
          ),
        )
        .toList();
  }
}
