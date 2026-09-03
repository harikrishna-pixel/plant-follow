import '../model/data_model/plant_location.dart';
import 'care_weather_policy.dart';
import 'weather_service.dart';
import 'weather_snapshot.dart';

/// One weather result per Location per cache window. Not one request per plant.
class LocationWeatherCache {
  LocationWeatherCache({
    DateTime Function()? clock,
    Duration? ttl,
  })  : _clock = clock ?? DateTime.now,
        _ttl = ttl ?? CareWeatherPolicy.cacheTtl;

  static final LocationWeatherCache instance = LocationWeatherCache();

  final DateTime Function() _clock;
  final Duration _ttl;
  final Map<String, WeatherSnapshot> _snapshots = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<WeatherSnapshot?>> _inFlight = {};
  int fetchCount = 0;

  WeatherSnapshot? peek(String locationId, {DateTime? now}) {
    final fetched = _fetchedAt[locationId];
    final snapshot = _snapshots[locationId];
    if (fetched == null || snapshot == null) return null;
    final at = now ?? _clock();
    if (at.difference(fetched) > _ttl) return null;
    return snapshot;
  }

  void put(WeatherSnapshot snapshot, {DateTime? now}) {
    _snapshots[snapshot.locationId] = snapshot;
    _fetchedAt[snapshot.locationId] = now ?? _clock();
  }

  Future<WeatherSnapshot?> getOrFetch({
    required PlantLocation location,
    required Future<WeatherSnapshot?> Function(PlantLocation) loader,
    DateTime? now,
  }) {
    final at = now ?? _clock();
    final cached = peek(location.id, now: at);
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[location.id];
    if (pending != null) return pending;
    fetchCount++;
    final future = loader(location).then((snapshot) {
      if (snapshot != null) {
        put(snapshot, now: at);
      }
      return snapshot;
    }).whenComplete(() {
      _inFlight.remove(location.id);
    });
    _inFlight[location.id] = future;
    return future;
  }

  void clear() {
    _snapshots.clear();
    _fetchedAt.clear();
    _inFlight.clear();
    fetchCount = 0;
  }
}

class LocationWeatherLookup {
  LocationWeatherLookup(this._service);

  final WeatherService _service;

  Future<WeatherSnapshot?> forLocation(PlantLocation location) async {
    final lat = location.latitude;
    final lon = location.longitude;
    WeatherData current;
    try {
      if (lat != null && lon != null) {
        current = await _service.getWeatherByCoordinates(lat, lon);
      } else {
        final city = location.weatherPlaceName;
        if (city == null || city.isEmpty) return null;
        current = await _service.getWeatherByCity(city);
      }
    } catch (e) {
      print('CARE_WEATHER location=${location.id} fetch failed');
      return null;
    }

    ForecastHint? forecast;
    try {
      if (lat != null && lon != null) {
        forecast = await _service.getForecastHintByCoordinates(lat, lon);
      } else if (location.weatherPlaceName != null) {
        forecast = await _service.getForecastHintByCity(
          location.weatherPlaceName!,
        );
      }
    } catch (e) {
      forecast = null;
    }

    return WeatherSnapshot(
      locationId: location.id,
      observedAt: current.dataTime ?? DateTime.now(),
      temperatureC: current.temperature,
      rain1hMm: current.rain1hMm,
      rain3hMm: current.rain3hMm,
      condition: current.conditionMain,
      description: current.description,
      forecastTemperatureC: forecast?.maxTempC,
      forecastRainExpected: forecast?.rainExpected ?? false,
    );
  }
}
