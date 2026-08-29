import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class WeatherService {
  // Replace with your OpenWeatherMap API key
  static const String _apiKey = 'b409bff824ff2f011933e5c2caaeff08';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  // Get current location with better error handling
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Please enable location services in Settings');
    }

    permission = await Geolocator.checkPermission();
    print('Current permission status: $permission'); // Debug log

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print('Permission after request: $permission'); // Debug log

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied. Please allow location access in Settings.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable it in Settings > App > Location');
    }

    // Get position with timeout
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print('Got location: ${position.latitude}, ${position.longitude}'); // Debug log
      return position;
    } catch (e) {
      print('Error getting position: $e'); // Debug log
      // Fallback to last known position
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        print('Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
        return lastPosition;
      }
      throw Exception('Could not determine your location. Please try again.');
    }
  }

  // Get city name from coordinates
  Future<String> getCityName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        return placemarks[0].locality ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Fetch weather by coordinates with debug logging
  Future<WeatherData> getWeatherByCoordinates(
      double latitude,
      double longitude,
      ) async {
    print('Fetching weather for: $latitude, $longitude'); // Debug log

    final url = Uri.parse(
      '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
    );

    print('API URL: $url'); // Debug log (remove apiKey from production logs)

    final response = await http.get(url);

    print('Response status: ${response.statusCode}'); // Debug log
    print('Response body: ${response.body}'); // Debug log

    if (response.statusCode == 200) {
      final weatherData = WeatherData.fromJson(jsonDecode(response.body));
      print('City detected: ${weatherData.cityName}'); // Debug log
      return weatherData;
    } else {
      throw Exception('Failed to load weather data: ${response.statusCode}');
    }
  }

  // Fetch weather by city name
  Future<WeatherData> getWeatherByCity(String city) async {
    final url = Uri.parse(
      '$_baseUrl/weather?q=$city&appid=$_apiKey&units=metric',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return WeatherData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  // Get current weather for user's location
  Future<WeatherData> getCurrentWeather() async {
    try {
      final position = await getCurrentLocation();

      // Check if location is valid (not default simulator location)
      // San Francisco default coordinates: 37.785834, -122.406417
      if ((position.latitude - 37.785834).abs() < 0.001 &&
          (position.longitude - (-122.406417)).abs() < 0.001) {
        print('⚠️ WARNING: Using simulator default location. Setting to Tiruppur, India');
        // Override with Tiruppur coordinates
        return await getWeatherByCoordinates(11.1085, 77.3411);
      }

      return await getWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      print('❌ Error getting weather: $e');
      throw Exception('Error getting weather: $e');
    }
  }

  // Get weather for Tiruppur specifically (fallback method)
  Future<WeatherData> getWeatherForTiruppur() async {
    return await getWeatherByCoordinates(11.1085, 77.3411);
  }
}

// Weather Data Model
class WeatherData {
  final String cityName;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String description;
  final String icon;
  final int pressure;
  final double tempMin;
  final double tempMax;

  WeatherData({
    required this.cityName,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.icon,
    required this.pressure,
    required this.tempMin,
    required this.tempMax,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['name'] ?? 'Unknown',
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '',
      icon: json['weather'][0]['icon'] ?? '',
      pressure: json['main']['pressure'] as int,
      tempMin: (json['main']['temp_min'] as num).toDouble(),
      tempMax: (json['main']['temp_max'] as num).toDouble(),
    );
  }

  // Get weather icon URL
  String getIconUrl() {
    return 'https://openweathermap.org/img/wn/$icon@2x.png';
  }
}