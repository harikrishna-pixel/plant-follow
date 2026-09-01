import '../model/data_model/care_rule.dart';
import '../model/data_model/plant_event.dart';
import '../model/data_model/plant_model.dart';
import '../model/data_model/reminder_model.dart';
import 'care_rule_store.dart';

/// Pure care-rule helpers. No Hive here so Phase 4 tests stay IO-free.
class CareLogic {
  static const defaultIntervalDays = 7;

  static bool isDue(CareRule rule, DateTime now) {
    if (!rule.enabled) return false;
    final dueDay = DateTime(
      rule.nextDueAt.year,
      rule.nextDueAt.month,
      rule.nextDueAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return !dueDay.isAfter(today);
  }

  static CareRule complete(CareRule rule, DateTime now) {
    final interval = rule.baseIntervalDays < 1
        ? defaultIntervalDays
        : rule.baseIntervalDays;
    final today = DateTime(now.year, now.month, now.day);
    return rule.copyWith(
      lastCompletedAt: now,
      nextDueAt: today.add(Duration(days: interval)),
    );
  }

  /// Shared next-due + event pair used by Plant Detail, Today, and CareRuleProvider.
  static ({CareRule rule, PlantEvent event}) completeWithEvent(
    CareRule rule,
    DateTime now,
  ) {
    final updated = complete(rule, now);
    return (rule: updated, event: completionEvent(rule: updated, now: now));
  }

  static PlantEvent completionEvent({
    required CareRule rule,
    required DateTime now,
  }) {
    return PlantEvent(
      id: Plant.generateDurableId(),
      plantId: rule.plantId,
      eventType: PlantEventType.careCompletion,
      timestamp: now,
      payload: {
        'careRuleId': rule.id,
        'careType': rule.careType,
        'baseIntervalDays': rule.baseIntervalDays,
        if (rule.reminderId != null) 'reminderId': rule.reminderId,
      },
      source: 'care',
    );
  }

  /// Short, known-fact copy only. No invented weather/soil reasoning.
  static String whyDue(CareRule rule, DateTime now) {
    final last = rule.lastCompletedAt;
    if (last != null) {
      final days = now.difference(last).inDays;
      if (days >= 1 && CareTypeNormalizer.isWatering(rule.careType)) {
        return 'Dry for $days day${days == 1 ? '' : 's'}.';
      }
      if (days >= 1) {
        return 'Last done $days day${days == 1 ? '' : 's'} ago.';
      }
    }
    final dueDay = DateTime(
      rule.nextDueAt.year,
      rule.nextDueAt.month,
      rule.nextDueAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    if (dueDay.isBefore(today)) {
      return 'Still on the list — mark it when you can.';
    }
    return 'On today’s care list.';
  }

  static bool isOverdue(CareRule rule, DateTime now) {
    if (!rule.enabled) return false;
    final dueDay = DateTime(
      rule.nextDueAt.year,
      rule.nextDueAt.month,
      rule.nextDueAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return dueDay.isBefore(today);
  }

  static String displayType(String careType) {
    final trimmed = careType.replaceFirst('PlantFollow: ', '').trim();
    return trimmed.replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }

  static int intervalDaysFromReminder(PlantReminder reminder) {
    final days = reminder.dateTime.difference(reminder.createdAt).inDays;
    if (days < 1) return defaultIntervalDays;
    return days;
  }

  static CareRule fromReminder(PlantReminder reminder, {String? existingId}) {
    final plantId = reminder.plantId;
    if (plantId == null || plantId.isEmpty) {
      throw ArgumentError('Care rules must use durable plant.id');
    }
    return CareRule(
      id: existingId ?? Plant.generateDurableId(),
      plantId: plantId,
      careType: reminder.taskType,
      baseIntervalDays: intervalDaysFromReminder(reminder),
      nextDueAt: reminder.dateTime,
      reminderId: reminder.id,
    );
  }

  /// True when this reminder is already represented by [rule].
  static bool reminderCoveredByRule(PlantReminder reminder, CareRule rule) {
    if (reminder.id == rule.reminderId) return true;
    if (reminder.plantId == null || reminder.plantId!.isEmpty) return false;
    if (reminder.plantId != rule.plantId) return false;
    return CareTypeNormalizer.normalize(reminder.taskType) ==
        CareTypeNormalizer.normalize(rule.careType);
  }
}
