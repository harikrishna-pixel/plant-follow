import 'dart:io';
import 'package:flutter/material.dart';
import 'package:plantidentifier/model/data_model/plant_model.dart';
import 'package:plantidentifier/model/data_model/plant_search_result.dart';
import 'package:plantidentifier/services/gemini_service.dart';
import 'package:plantidentifier/services/identify_logic.dart';
import 'package:plantidentifier/services/plant_local.dart';
import 'package:plantidentifier/services/search_service.dart';

class PlantProvider extends ChangeNotifier {
  PlantProvider() {
    loadFavorites();
  }

  final SearchService _searchService = SearchService();
  List<Plant> _favorites = [];
  PlantSearchResult? _searchResult;
  bool _isSearchLoading = false;
  String? _searchError;
  String? _lastCity; // Track last city to prevent unnecessary reloads

  List<Plant> get favorites => _favorites;

  PlantSearchResult? get searchResult => _searchResult;

  bool get isSearchLoading => _isSearchLoading;

  String? get searchError => _searchError;

  Future<void> loadFavorites() async {
    _favorites = await LocalStorageService.getFavorites();
    
    print('🌿 Loading favorites:');
    print('  Total loaded: ${_favorites.length}');
    
    // Remove exact duplicate records (same durable id), not same species name.
    final seenIds = <String>{};
    final uniqueFavorites = <Plant>[];
    final duplicates = <String>[];
    
    for (var plant in _favorites) {
      if (seenIds.contains(plant.id)) {
        duplicates.add(plant.name);
        print('  ⚠️ DUPLICATE: ${plant.name} (ID: ${plant.id})');
      } else {
        seenIds.add(plant.id);
        uniqueFavorites.add(plant);
        print('  - ${plant.name} (ID: ${plant.id})');
      }
    }
    
    // If duplicates found, remove them
    if (duplicates.isNotEmpty) {
      print('  🔧 Found ${duplicates.length} duplicate(s), cleaning up...');
      _favorites = uniqueFavorites;
      
      // Clean storage permanently
      await LocalStorageService.cleanDuplicateFavorites();
      print('  ✅ Cleaned! Now have ${_favorites.length} unique plants');
    }
    
    notifyListeners();
  }

  Future<IdentifyAttempt> identifyPlant(File image) async {
    return GeminiService.identifyPlant(image);
  }

  // Check if a plant is already in favorites
  bool isFavorite(Plant plant) {
    return _favorites.any((fav) =>
        fav.name == plant.name &&
        fav.scientificName == plant.scientificName &&
        fav.imagePath == plant.imagePath);
  }

  // Add plant to favorites (returns false if already exists)
  Future<bool> saveFavorite(
    Plant plant, {
    String confirmationSource = 'model',
  }) async {
    final isDuplicate = isFavorite(plant);

    if (isDuplicate) {
      return false;
    }

    await LocalStorageService.saveFavorite(
      plant,
      confirmationSource: confirmationSource,
    );
    await loadFavorites();
    return true;
  }

  // Alias for saveFavorite (for better naming consistency)
  Future<void> addToFavorites(Plant plant) async {
    await saveFavorite(plant);
  }

  Future<void> updatePlant(Plant plant) async {
    await LocalStorageService.updateFavorite(plant);
    await loadFavorites();
  }

  void removeFromFavorites(Plant plant) {
    _favorites.remove(plant);
    LocalStorageService.deleteFavorite(plant);
    loadFavorites();
  }

  Future<void> loadSearchRecommendations({bool forceRefresh = false}) async {
    debugPrint('🔍 Starting search recommendations loading (forceRefresh: $forceRefresh)...');
    
    // Check if we already have cached data and location hasn't changed
    if (!forceRefresh && _searchResult != null && _lastCity != null) {
      // Check if location changed by getting current city
      try {
        final currentCity = await _searchService.getCurrentCity();
        if (currentCity == _lastCity) {
          debugPrint('✅ Location unchanged ($currentCity), using existing results');
          return; // Don't reload if location hasn't changed
        }
      } catch (e) {
        debugPrint('⚠️ Could not check location, proceeding with load: $e');
      }
    }
    
    _isSearchLoading = true;
    _searchError = null;
    notifyListeners();

    try {
      _searchResult = await _searchService.fetchPlantRecommendations(forceRefresh: forceRefresh);
      // Store the city for future comparison
      if (_searchResult != null) {
        _lastCity = _searchResult!.city;
      }
      debugPrint('✅ Search recommendations loaded successfully');
      debugPrint('📊 Categories: ${_searchResult?.categories.length ?? 0}, Plants: ${_searchResult?.plants.length ?? 0}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading search recommendations: $e');
      debugPrint('Stack trace: $stackTrace');
      _searchError = e.toString();
    } finally {
      _isSearchLoading = false;
      notifyListeners();
    }
  }
}
