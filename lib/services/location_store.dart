import 'package:hive_flutter/hive_flutter.dart';

import '../model/data_model/plant_location.dart';
import '../model/data_model/plant_model.dart';

/// Local-first Location persistence. JSON maps in Hive, same pattern as events.
class LocationStore {
  static const boxName = 'plant_locations_box';
  static const defaultHomeId = 'location-home';

  static Future<void> init() async {
    await Hive.openBox(boxName);
    await ensureDefaultHome();
  }

  static Future<void> ensureDefaultHome() async {
    final box = Hive.box(boxName);
    if (box.containsKey(defaultHomeId)) return;
    final home = PlantLocation(
      id: defaultHomeId,
      name: 'Home',
      createdAt: DateTime.now(),
    );
    await box.put(home.id, home.toJson());
  }

  static Future<void> save(PlantLocation location) async {
    await Hive.box(boxName).put(location.id, location.toJson());
  }

  static PlantLocation? get(String id) {
    final raw = Hive.box(boxName).get(id);
    if (raw is! Map) return null;
    return PlantLocation.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<PlantLocation> all() {
    final items = <PlantLocation>[];
    for (final raw in Hive.box(boxName).values) {
      if (raw is! Map) continue;
      try {
        items.add(PlantLocation.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  static PlantLocation? locationForPlant(Plant plant) {
    final id = plant.locationId;
    if (id == null || id.isEmpty) return null;
    return get(id);
  }

  static Future<void> clearAll() async {
    await Hive.box(boxName).clear();
  }
}
