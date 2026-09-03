/// Conservative, testable weather thresholds for care context.
/// Weather provides context. It is not a soil sensor.
class CareWeatherPolicy {
  CareWeatherPolicy._();

  /// Snapshot older than this is unavailable for care adjustment.
  static const freshness = Duration(hours: 6);

  /// Cache window for one weather result per Location.
  static const cacheTtl = Duration(minutes: 45);

  /// 1-hour precipitation (mm) treated as meaningful observed rain.
  static const meaningfulRain1hMm = 2.0;

  /// 3-hour precipitation (mm) treated as meaningful observed rain.
  static const meaningfulRain3hMm = 4.0;

  /// Outdoor pots get heat attention at this temperature (°C).
  static const heatAttentionPottedC = 32.0;

  /// Garden beds get heat attention at a slightly higher temperature (°C).
  static const heatAttentionGardenC = 35.0;

  /// Existing Today critical-heat card. Attention, not a watering command.
  static const criticalHeatC = 38.0;

  /// Existing Today critical-cold card.
  static const criticalColdC = 2.0;

  static String occurrenceDayKey(DateTime dueAt) {
    final day = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return day.toIso8601String();
  }

  static bool isFresh(DateTime observedAt, DateTime now) {
    return !now.difference(observedAt).isNegative &&
        now.difference(observedAt) <= freshness;
  }

  static bool isQualitativeRain(String condition) {
    final value = condition.trim().toLowerCase();
    return value == 'rain' || value == 'thunderstorm';
  }

  static bool isDrizzle(String condition) {
    return condition.trim().toLowerCase() == 'drizzle';
  }

  static bool isMeaningfulObservedRain({
    required String condition,
    double? rain1hMm,
    double? rain3hMm,
  }) {
    if (rain1hMm != null && rain1hMm >= meaningfulRain1hMm) return true;
    if (rain3hMm != null && rain3hMm >= meaningfulRain3hMm) return true;
    if (isQualitativeRain(condition)) return true;
    if (isDrizzle(condition)) return true;
    return false;
  }

  static bool isHeatAttention({
    required double? temperatureC,
    required bool outdoorPotted,
    required bool gardenBed,
  }) {
    if (temperatureC == null) return false;
    if (outdoorPotted && temperatureC >= heatAttentionPottedC) return true;
    if (gardenBed && temperatureC >= heatAttentionGardenC) return true;
    return false;
  }

  static bool isCriticalTemperature(double? temperatureC) {
    if (temperatureC == null) return false;
    return temperatureC <= criticalColdC || temperatureC >= criticalHeatC;
  }
}
