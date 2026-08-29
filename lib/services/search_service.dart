import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../model/data_model/plant_search_result.dart';
import '../utils/constants.dart';
import 'plant_local.dart';
import 'weather_service.dart';

// 🖼️ Unsplash API Service for high-quality plant images
class UnsplashImageService {
  // Get your own free API key from: https://unsplash.com/developers
  static const String _accessKey = 'hYjjb0Q9x9sUu5B1BpIkgd1B8fvP00QmDMARhXLGprE';
  static const String _baseUrl = 'https://api.unsplash.com';
  
  /// Fetches a high-quality plant image from Unsplash
  static Future<String> getPlantImage(String plantName) async {
    try {
      final query = Uri.encodeComponent('$plantName plant nature');
      final url = '$_baseUrl/search/photos?query=$query&per_page=1&orientation=portrait';
      
      debugPrint('🖼️ Fetching image for: $plantName');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Client-ID $_accessKey'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final imageUrl = data['results'][0]['urls']['regular'] ?? '';
          if (imageUrl.isNotEmpty) {
            debugPrint('  ✅ Image found: ${imageUrl.substring(0, 50)}...');
            return imageUrl;
          }
        }
      } else {
        debugPrint('  ⚠️ Unsplash API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('  ❌ Error fetching image for $plantName: $e');
    }
    
    debugPrint('  ⚠️ Using fallback icon for $plantName');
    return '';
  }
}

class SearchService {
  SearchService({WeatherService? weatherService})
      : _weatherService = weatherService ?? WeatherService();

  final WeatherService _weatherService;

  static const _maxPlants = 10;
  static String get _endpointPath =>
      '/v1/models/${AppConstants.geminiModel}:generateContent';
  
  String? _lastKnownCity; // Cache last known city

  /// Get current city - uses cached city if available to avoid unnecessary API calls
  Future<String> getCurrentCity() async {
    // If we have a cached city and haven't forced refresh, return it
    if (_lastKnownCity != null) {
      return _lastKnownCity!;
    }
    
    // Otherwise, get current location (this is only called when needed)
    try {
      final position = await _weatherService.getCurrentLocation();
      final weather = await _weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
      var city = weather.cityName;
      if (city.trim().isEmpty || city.toLowerCase() == 'unknown') {
        city = await _weatherService.getCityName(
          position.latitude,
          position.longitude,
        );
      }
      _lastKnownCity = city; // Cache it
      return city;
    } catch (e) {
      return _lastKnownCity ?? 'Unknown';
    }
  }

  Future<PlantSearchResult> fetchPlantRecommendations({bool forceRefresh = false}) async {
    debugPrint('🌍 fetchPlantRecommendations called (forceRefresh: $forceRefresh)');
    
    debugPrint('📍 Getting current location...');
    final position = await _weatherService.getCurrentLocation();
    debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
    
    debugPrint('🌤️ Fetching weather data...');
    final weather = await _weatherService.getWeatherByCoordinates(
      position.latitude,
      position.longitude,
    );

    var city = weather.cityName;
    if (city.trim().isEmpty || city.toLowerCase() == 'unknown') {
      city = await _weatherService.getCityName(
        position.latitude,
        position.longitude,
      );
    }
    debugPrint('🏙️ City detected: $city');
    _lastKnownCity = city; // Store for future reference

    // Check if location changed - if same city and we have cache, use it
    if (!forceRefresh) {
      debugPrint('💾 Checking cache for $city...');
      final cached = LocalStorageService.getCachedSearchResult(city);
      if (cached != null) {
        debugPrint('✅ Using cached data for $city (location unchanged)');
        final result = PlantSearchResult.fromJson(cached);
        debugPrint('📸 Cached categories: ${result.categories.length}, plants: ${result.plants.length}');
        return result;
      }
    }

    // Clear cache if force refresh requested
    if (forceRefresh) {
      debugPrint('🧹 Force refresh - clearing cache for $city...');
      await LocalStorageService.clearSearchCache(city);
    }
    debugPrint('❌ No cache found, fetching from Gemini API...');
    final prompt = _buildPrompt(
      city: city,
      weather: weather,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}$_endpointPath?key=${AppConstants.geminiApiKey}',
    );

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(prompt),
    );

    if (response.statusCode != 200) {
      debugPrint('❌ Gemini API error: ${response.statusCode}');
      debugPrint('Response: ${response.body}');
      throw Exception('Failed to fetch recommendations: ${response.statusCode}');
    }

    debugPrint('✅ Gemini API response received for $city');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (text is! String) {
      debugPrint('❌ Invalid response structure from Gemini');
      throw Exception('Invalid response structure from Gemini');
    }

    debugPrint('📝 Parsing Gemini response...');
    // Gemini responses may include narrative text; extract JSON block
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
    if (match == null) {
      debugPrint('❌ Could not extract JSON from Gemini response');
      debugPrint('Raw text: ${text.substring(0, text.length > 200 ? 200 : text.length)}...');
      throw Exception('Could not parse Gemini response');
    }

    final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    var result = PlantSearchResult.fromJson(decoded);

    debugPrint('✅ Parsed ${result.categories.length} categories and ${result.plants.length} plants');
    
    // 🖼️ Fetch real high-quality images from Unsplash
    debugPrint('🖼️ Fetching real images from Unsplash API...');
    
    // Fetch category images (limit to first 5 for performance)
    final updatedCategories = <PlantCategory>[];
    for (var i = 0; i < result.categories.length && i < 5; i++) {
      final cat = result.categories[i];
      final imageUrl = await UnsplashImageService.getPlantImage(cat.name);
      updatedCategories.add(PlantCategory(
        name: cat.name,
        imageUrl: imageUrl,
        description: cat.description,
      ));
    }
    
    // Fetch plant images
    final updatedPlants = <PlantSummary>[];
    for (var i = 0; i < result.plants.length; i++) {
      final plant = result.plants[i];
      final imageUrl = await UnsplashImageService.getPlantImage(plant.name);
      updatedPlants.add(PlantSummary(
        name: plant.name,
        scientificName: plant.scientificName,
        category: plant.category,
        imageUrl: imageUrl,
        description: plant.description,
      ));
    }
    
    // Update result with fetched images
    result = PlantSearchResult(
      city: result.city,
      temperature: result.temperature,
      categories: updatedCategories,
      plants: updatedPlants,
    );
    
    debugPrint('✅ Images fetched successfully!');
    debugPrint('📊 Categories with images: ${updatedCategories.where((c) => c.imageUrl.isNotEmpty).length}/${updatedCategories.length}');
    debugPrint('📊 Plants with images: ${updatedPlants.where((p) => p.imageUrl.isNotEmpty).length}/${updatedPlants.length}');
    
    // Save results to cache with images
    debugPrint('💾 Saving to cache with Unsplash images...');
    LocalStorageService.saveSearchResult(city, result.toJson());

    return result;
  }

  Map<String, dynamic> _buildPrompt({
    required String city,
    required WeatherData weather,
    required double latitude,
    required double longitude,
  }) {
    final temperature = weather.temperature.toStringAsFixed(1);
    final humidity = weather.humidity;
    final description = weather.description;
    final wind = weather.windSpeed.toStringAsFixed(1);

    return {
      'contents': [
        {
          'parts': [
            {
              'text': """
You are a botany expert assistant. The user is currently in $city (lat: $latitude, lon: $longitude).
Current weather summary: $description, temperature $temperature°C, humidity $humidity%, wind speed $wind m/s.

Recommend up to $_maxPlants plant categories and specific plants that thrive in these conditions and are commonly cultivated locally.

Return pure JSON (no markdown) with the following structure:
{
  "city": string,
  "temperature": number,
  "categories": [
    {
      "name": string,
      "description": string,
      "image_url": ""
    }
  ],
  "plants": [
    {
      "name": string,
      "scientific_name": string,
      "category": string,
      "description": string,
      "image_url": ""
    }
  ]
}

IMPORTANT RULES:
- Provide unique categories and plants relevant to the specified climate
- ALWAYS leave image_url as empty string "" - images will be fetched separately
- Focus on accurate plant names, scientific names, and descriptions
- Do not include markdown, explanations, or trailing text
- Return only valid JSON

Example response:
{
  "city": "Chennai",
  "temperature": 28.5,
  "categories": [
    {"name": "Tropical Plants", "description": "Plants that thrive in warm climates", "image_url": ""},
    {"name": "Succulents", "description": "Drought-tolerant plants", "image_url": ""}
  ],
  "plants": [
    {"name": "Jasmine", "scientific_name": "Jasminum", "category": "Flowering", "description": "Fragrant tropical flower", "image_url": ""},
    {"name": "Aloe Vera", "scientific_name": "Aloe barbadensis", "category": "Succulents", "description": "Medicinal succulent", "image_url": ""}
  ]
}
"""
            }
          ]
        }
      ]
    };
  }
}
