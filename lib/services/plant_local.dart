import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/data_model/folder_model.dart';
import '../model/data_model/plant_event.dart';
import '../model/data_model/plant_model.dart';
import 'plant_record_migration.dart';
import 'recovery_store.dart';
import 'location_store.dart';
import 'care_rule_store.dart';
import 'grow_plan_store.dart';

class LocalStorageService {
  static const _favoritesBox = 'favorites_box';
  static const _searchCacheBox = 'search_cache_box';
  static const _eventsBox = 'plant_events_box';
  static const _folderKey = 'plant_folders';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PlantAdapter());
    }
    await Hive.openBox<Plant>(_favoritesBox);
    await Hive.openBox(_searchCacheBox);
    await Hive.openBox(_eventsBox);
    await RecoveryStore.init();
    await LocationStore.init();
    await CareRuleStore.init();
    await GrowPlanStore.init();
    await HarvestStore.init();
    await migratePlantRecordFoundation();
  }

  /// Backfill durable ids, persist field 14, remap folder plantIds.
  /// Additive and idempotent. Does not delete plants.
  static Future<void> migratePlantRecordFoundation() async {
    final box = Hive.box<Plant>(_favoritesBox);
    final plants = <Plant>[];

    for (final key in box.keys.toList()) {
      final plant = box.get(key);
      if (plant == null) continue;
      // Re-writing persists HiveField(14) for legacy 14-field records.
      await box.put(key, plant);
      plants.add(plant);
    }

    await _remapFolderPlantIds(plants);
  }

  static Future<void> _remapFolderPlantIds(List<Plant> plants) async {
    if (plants.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = prefs.getString(_folderKey);
      if (foldersJson == null || foldersJson.isEmpty) return;

      final decoded = jsonDecode(foldersJson);
      if (decoded is! List) return;

      var changed = false;
      final remapped = decoded.map((raw) {
        final folder = PlantFolder.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        final nextIds = PlantRecordMigration.remapFolderPlantIds(
          folder.plantIds,
          plants,
        );
        if (nextIds.length != folder.plantIds.length ||
            !_sameIds(nextIds, folder.plantIds)) {
          changed = true;
        }
        return folder.copyWith(plantIds: nextIds).toJson();
      }).toList();

      if (changed) {
        await prefs.setString(_folderKey, jsonEncode(remapped));
      }
    } catch (e) {
      print('Plant folder id remap skipped: $e');
    }
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<List<Plant>> getFavorites() async {
    final box = Hive.box<Plant>(_favoritesBox);
    return box.values.toList();
  }

  static Future<void> saveFavorite(Plant plant) async {
    final box = Hive.box<Plant>(_favoritesBox);
    await box.add(plant);
    await appendPlantEvent(
      PlantEvent(
        id: Plant.generateDurableId(),
        plantId: plant.id,
        eventType: PlantEventType.identification,
        timestamp: DateTime.now(),
        payload: {
          'name': plant.name,
          'scientificName': plant.scientificName,
          if (plant.imagePath != null) 'imagePath': plant.imagePath,
        },
        source: 'identification',
      ),
    );
  }

  static Future<void> deleteFavorite(Plant plant) async {
    final box = Hive.box<Plant>(_favoritesBox);
    dynamic keyToDelete;
    for (final key in box.keys) {
      final stored = box.get(key);
      if (stored != null && stored.matchesStoredId(plant.id)) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      await box.delete(keyToDelete);
    }
  }

  static Future<void> updateFavorite(Plant plant) async {
    final box = Hive.box<Plant>(_favoritesBox);
    dynamic keyToUpdate;
    for (final key in box.keys) {
      final stored = box.get(key);
      if (stored != null && stored.matchesStoredId(plant.id)) {
        keyToUpdate = key;
        break;
      }
    }
    if (keyToUpdate != null) {
      await box.put(keyToUpdate, plant);
    } else {
      await box.add(plant);
    }
  }

  static Future<void> appendPlantEvent(PlantEvent event) async {
    final box = Hive.box(_eventsBox);
    await box.put(event.id, event.toJson());
  }

  static List<PlantEvent> getPlantEvents(String plantId) {
    final box = Hive.box(_eventsBox);
    final events = <PlantEvent>[];
    for (final raw in box.values) {
      if (raw is! Map) continue;
      final event = PlantEvent.tryFromJson(Map<String, dynamic>.from(raw));
      if (event == null) continue;
      if (event.plantId == plantId) {
        events.add(event);
      }
    }
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  static List<PlantEvent> getAllPlantEvents() {
    final box = Hive.box(_eventsBox);
    final events = <PlantEvent>[];
    for (final raw in box.values) {
      if (raw is! Map) continue;
      final event = PlantEvent.tryFromJson(Map<String, dynamic>.from(raw));
      if (event == null) continue;
      events.add(event);
    }
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  static Map<String, dynamic>? getCachedSearchResult(String city) {
    final key = _normalizedCity(city);
    if (key == null) return null;

    final box = Hive.box(_searchCacheBox);
    final cached = box.get(key);
    if (cached is Map) {
      return Map<String, dynamic>.from(cached.cast<String, dynamic>());
    }
    return null;
  }

  static Future<void> saveSearchResult(
    String city,
    Map<String, dynamic> data,
  ) async {
    final key = _normalizedCity(city);
    if (key == null) return;

    final box = Hive.box(_searchCacheBox);
    await box.put(key, data);
  }

  static Future<void> clearSearchCache(String city) async {
    final key = _normalizedCity(city);
    if (key == null) return;

    final box = Hive.box(_searchCacheBox);
    await box.delete(key);
  }

  static Future<void> clearAllSearchCache() async {
    final box = Hive.box(_searchCacheBox);
    await box.clear();
  }

  /// Removes exact duplicate records (same durable id), not same species name.
  static Future<void> cleanDuplicateFavorites() async {
    final box = Hive.box<Plant>(_favoritesBox);
    final allPlants = box.values.toList();

    final seenIds = <String>{};
    final uniquePlants = <Plant>[];

    for (final plant in allPlants) {
      if (seenIds.add(plant.id)) {
        uniquePlants.add(plant);
      }
    }

    if (uniquePlants.length < allPlants.length) {
      await box.clear();
      for (final plant in uniquePlants) {
        await box.add(plant);
      }
    }
  }

  static Future<void> clearAllData() async {
    await Hive.box<Plant>(_favoritesBox).clear();
    await Hive.box(_searchCacheBox).clear();
    await Hive.box(_eventsBox).clear();
    await RecoveryStore.clearAll();
    await LocationStore.clearAll();
    await CareRuleStore.clearAll();
    await GrowPlanStore.clearAll();
    await HarvestStore.clearAll();
  }

  static String? _normalizedCity(String city) {
    final normalized = city.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') {
      return null;
    }
    return normalized;
  }
}
