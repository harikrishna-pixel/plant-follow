import 'package:hive_flutter/hive_flutter.dart';

import '../model/data_model/care_rule.dart';

class CareRuleStore {
  static const boxName = 'plant_care_rules_box';

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  static Future<void> save(CareRule rule) async {
    await Hive.box(boxName).put(rule.id, rule.toJson());
  }

  static CareRule? get(String id) {
    final raw = Hive.box(boxName).get(id);
    if (raw is! Map) return null;
    return CareRule.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<CareRule> all() {
    final items = <CareRule>[];
    for (final raw in Hive.box(boxName).values) {
      if (raw is! Map) continue;
      try {
        items.add(CareRule.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    return items;
  }

  static List<CareRule> forPlant(String plantId) {
    return all().where((r) => r.plantId == plantId).toList();
  }

  static CareRule? findByPlantAndType(String plantId, String careType) {
    final needle = CareTypeNormalizer.normalize(careType);
    for (final rule in all()) {
      if (rule.plantId == plantId &&
          CareTypeNormalizer.normalize(rule.careType) == needle) {
        return rule;
      }
    }
    return null;
  }

  static Future<void> clearAll() async {
    await Hive.box(boxName).clear();
  }
}

class CareTypeNormalizer {
  CareTypeNormalizer._();

  static String normalize(String raw) {
    return raw
        .replaceFirst('PlantFollow: ', '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .toLowerCase();
  }

  static bool isWatering(String careType) {
    final n = normalize(careType);
    return n.contains('water') || n.contains('mist');
  }
}
