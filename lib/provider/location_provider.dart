import 'package:flutter/material.dart';

import '../model/data_model/plant_location.dart';
import '../model/data_model/plant_model.dart';
import '../services/location_store.dart';

class LocationProvider extends ChangeNotifier {
  List<PlantLocation> _locations = [];

  List<PlantLocation> get locations => List.unmodifiable(_locations);

  PlantLocation? get home {
    for (final location in _locations) {
      if (location.id == LocationStore.defaultHomeId) return location;
    }
    return _locations.isEmpty ? null : _locations.first;
  }

  LocationProvider() {
    load();
  }

  Future<void> load() async {
    await LocationStore.ensureDefaultHome();
    _locations = LocationStore.all();
    notifyListeners();
  }

  PlantLocation? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final location in _locations) {
      if (location.id == id) return location;
    }
    return LocationStore.get(id);
  }

  PlantLocation? forPlant(Plant plant) => byId(plant.locationId);

  Future<PlantLocation> addLocation({
    required String name,
    String? city,
    String? postcode,
    double? latitude,
    double? longitude,
  }) async {
    final location = PlantLocation(
      id: Plant.generateDurableId(),
      name: name.trim().isEmpty ? 'Place' : name.trim(),
      city: city,
      postcode: postcode,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );
    await LocationStore.save(location);
    await load();
    return location;
  }

  Future<void> updateLocation(PlantLocation location) async {
    await LocationStore.save(location);
    await load();
  }
}
