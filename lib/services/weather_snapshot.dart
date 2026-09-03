import 'care_weather_policy.dart';

/// Normalized weather inputs for care context. Only fields the provider
/// can actually supply. Never fabricate soil moisture.
class WeatherSnapshot {
  final String locationId;
  final DateTime observedAt;
  final double? temperatureC;
  final double? rain1hMm;
  final double? rain3hMm;
  final String condition;
  final String description;
  final double? forecastTemperatureC;
  final bool forecastRainExpected;

  const WeatherSnapshot({
    required this.locationId,
    required this.observedAt,
    this.temperatureC,
    this.rain1hMm,
    this.rain3hMm,
    this.condition = '',
    this.description = '',
    this.forecastTemperatureC,
    this.forecastRainExpected = false,
  });

  bool isFreshAt(DateTime now) =>
      CareWeatherPolicy.isFresh(observedAt, now);

  bool get hasMeaningfulObservedRain =>
      CareWeatherPolicy.isMeaningfulObservedRain(
        condition: condition,
        rain1hMm: rain1hMm,
        rain3hMm: rain3hMm,
      );

  double? get precipitationMm => rain1hMm ?? rain3hMm;
}
