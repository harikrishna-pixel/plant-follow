import '../model/data_model/plant_model.dart';

/// Pure helpers for Phase 1 plant-record migration. No Hive/IO here so
/// folder remapping can be unit-tested without touching user data.
class PlantRecordMigration {
  PlantRecordMigration._();

  /// Maps a stored folder plant id onto a durable [Plant.id].
  /// Legacy records stored [Plant.uniqueId] (image-path MD5).
  static String resolveDurableId(String storedId, List<Plant> plants) {
    for (final plant in plants) {
      if (plant.matchesStoredId(storedId)) {
        return plant.id;
      }
    }
    return storedId;
  }

  /// Rewrites folder `plantIds` from legacy uniqueId values to durable ids.
  /// Unknown ids are preserved. Dedupes if both keys were present.
  static List<String> remapFolderPlantIds(
    List<String> storedIds,
    List<Plant> plants,
  ) {
    final seen = <String>{};
    final remapped = <String>[];
    for (final storedId in storedIds) {
      final durable = resolveDurableId(storedId, plants);
      if (seen.add(durable)) {
        remapped.add(durable);
      }
    }
    return remapped;
  }

  static bool plantBelongsToStoredIds(Plant plant, Iterable<String> storedIds) {
    for (final storedId in storedIds) {
      if (plant.matchesStoredId(storedId)) return true;
    }
    return false;
  }
}
