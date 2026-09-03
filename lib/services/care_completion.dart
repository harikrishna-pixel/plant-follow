import '../model/data_model/care_rule.dart';
import '../provider/care_rule_provider.dart';
import '../provider/reminder_provider.dart';
import 'care_logic.dart';

/// Shared Care / Today / Plant Detail completion path.
/// Always goes through [CareLogic] via [CareRuleProvider.completeRule].
class CareCompletion {
  static Future<CareRule> complete({
    required CareRule rule,
    required CareRuleProvider careRules,
    required ReminderProvider reminders,
    DateTime? now,
    Map<String, dynamic>? extraPayload,
  }) async {
    final updated = await careRules.completeRule(
      rule,
      now: now,
      extraPayload: extraPayload,
    );
    final reminderId = updated.reminderId;
    if (reminderId != null && reminderId.isNotEmpty) {
      await reminders.rescheduleReminder(reminderId, updated.nextDueAt);
    }
    return updated;
  }
}
