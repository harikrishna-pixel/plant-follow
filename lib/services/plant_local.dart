import 'package:hive_flutter/hive_flutter.dart';

import '../model/data_model/plant_model.dart';

class LocalStorageService {
  static const _favoritesBox = 'favorites_box';
  static const _searchCacheBox = 'search_cache_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PlantAdapter());
    await Hive.openBox<Plant>(_favoritesBox);
    await Hive.openBox(_searchCacheBox);
  }

  static Future<List<Plant>> getFavorites() async {
    final box = Hive.box<Plant>(_favoritesBox);
    final all = box.values.toList();
    // Only last 10
    return all.reversed.take(10).toList();
  }

  static Future<void> saveFavorite(Plant plant) async {
    final box = Hive.box<Plant>(_favoritesBox);
    await box.add(plant);
    // Keep only last 10 items
    if (box.length > 10) {
      await box.deleteAt(0);
    }
  }

  /// ✅ Delete a favorite plant
  static Future<void> deleteFavorite(Plant plant) async {
    final box = Hive.box<Plant>(_favoritesBox);
    final keyToDelete = box.keys.firstWhere(
      (key) => box.get(key) == plant,
      orElse: () => null,
    );

    if (keyToDelete != null) {
      await box.delete(keyToDelete);
    }
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

  /// Clear search cache for a specific city
  static Future<void> clearSearchCache(String city) async {
    final key = _normalizedCity(city);
    if (key == null) return;

    final box = Hive.box(_searchCacheBox);
    await box.delete(key);
  }

  /// Clear all search cache
  static Future<void> clearAllSearchCache() async {
    final box = Hive.box(_searchCacheBox);
    await box.clear();
  }

  /// Clean duplicate favorites from storage
  static Future<void> cleanDuplicateFavorites() async {
    final box = Hive.box<Plant>(_favoritesBox);
    final allPlants = box.values.toList();
    
    // Find unique plants based on name hashCode
    final seenIds = <int>{};
    final uniquePlants = <Plant>[];
    
    for (var plant in allPlants) {
      final plantId = plant.name.hashCode;
      if (!seenIds.contains(plantId)) {
        seenIds.add(plantId);
        uniquePlants.add(plant);
      }
    }
    
    // If duplicates found, clear and re-save
    if (uniquePlants.length < allPlants.length) {
      await box.clear();
      for (var plant in uniquePlants) {
        await box.add(plant);
      }
    }
  }

  static Future<void> clearAllData() async {
    await Hive.box<Plant>(_favoritesBox).clear();
    await Hive.box(_searchCacheBox).clear();
  }

  static String? _normalizedCity(String city) {
    final normalized = city.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') {
      return null;
    }
    return normalized;
  }
}
