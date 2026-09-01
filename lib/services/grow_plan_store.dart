import 'package:hive_flutter/hive_flutter.dart';

import '../model/data_model/grow_plan.dart';

class GrowPlanStore {
  static const boxName = 'plant_grow_plans_box';

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  static Future<void> save(GrowPlan plan) async {
    await Hive.box(boxName).put(plan.id, plan.toJson());
  }

  static GrowPlan? get(String id) {
    final raw = Hive.box(boxName).get(id);
    if (raw is! Map) return null;
    return GrowPlan.fromJson(Map<String, dynamic>.from(raw));
  }

  static GrowPlan? forPlant(String plantId) {
    for (final plan in all()) {
      if (plan.plantId == plantId) return plan;
    }
    return null;
  }

  static List<GrowPlan> all() {
    final items = <GrowPlan>[];
    for (final raw in Hive.box(boxName).values) {
      if (raw is! Map) continue;
      try {
        items.add(GrowPlan.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    return items;
  }

  static Future<void> clearAll() async {
    await Hive.box(boxName).clear();
  }
}

class HarvestStore {
  static const boxName = 'plant_harvests_box';

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  static Future<void> save(HarvestRecord harvest) async {
    await Hive.box(boxName).put(harvest.id, harvest.toJson());
  }

  static List<HarvestRecord> forPlant(String plantId) {
    return all().where((h) => h.plantId == plantId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static List<HarvestRecord> all() {
    final items = <HarvestRecord>[];
    for (final raw in Hive.box(boxName).values) {
      if (raw is! Map) continue;
      try {
        items.add(HarvestRecord.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    return items;
  }

  static Future<void> clearAll() async {
    await Hive.box(boxName).clear();
  }
}
