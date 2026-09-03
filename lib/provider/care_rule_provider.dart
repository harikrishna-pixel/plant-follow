import 'package:flutter/material.dart';

import '../model/data_model/care_rule.dart';
import '../model/data_model/reminder_model.dart';
import '../services/care_logic.dart';
import '../services/care_rule_store.dart';
import '../services/care_context_resolver.dart';
import '../services/plant_local.dart';

class CareRuleProvider extends ChangeNotifier {
  List<CareRule> _rules = [];

  List<CareRule> get rules => List.unmodifiable(_rules);

  CareRuleProvider() {
    load();
  }

  Future<void> load() async {
    _rules = CareRuleStore.all();
    notifyListeners();
  }

  CareRule? byId(String? id) {
    if (id == null) return null;
    for (final rule in _rules) {
      if (rule.id == id) return rule;
    }
    return CareRuleStore.get(id);
  }

  /// Attach or create a plant-linked rule for a reminder that has plant.id.
  /// Does not schedule a second notification.
  Future<CareRule?> upsertFromReminder(PlantReminder reminder) async {
    final plantId = reminder.plantId;
    if (plantId == null || plantId.isEmpty) return null;

    final existing = CareRuleStore.findByPlantAndType(
      plantId,
      reminder.taskType,
    );
    final rule = existing == null
        ? CareLogic.fromReminder(reminder)
        : existing.copyWith(
            reminderId: existing.reminderId ?? reminder.id,
            nextDueAt: reminder.dateTime,
            careType: reminder.taskType,
          );
    await CareRuleStore.save(rule);
    await load();
    return rule;
  }

  Future<CareRule> completeRule(
    CareRule rule, {
    DateTime? now,
    Map<String, dynamic>? extraPayload,
  }) async {
    final at = now ?? DateTime.now();
    final applied = CareLogic.completeWithEvent(
      rule,
      at,
      extraPayload: extraPayload,
    );
    await CareRuleStore.save(applied.rule);
    await LocalStorageService.appendPlantEvent(applied.event);
    await load();
    return applied.rule;
  }

  Future<CareRule> rejectRainSuggestion(CareRule rule) async {
    final updated = CareContextResolver.withRainSuggestionRejected(rule);
    await CareRuleStore.save(updated);
    await load();
    return updated;
  }
}
