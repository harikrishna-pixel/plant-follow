import '../mixpanel/mixpanel.dart';
import '../model/data_model/plant_context.dart';

/// Mixpanel wrappers. Never log coordinates or weather API payloads.
class CareWeatherAnalytics {
  CareWeatherAnalytics._();

  static void contextShown({
    required PlantWeatherContext placement,
    required String careType,
    required String weatherContextType,
  }) {
    MixpanelService.trackEvent('weather_context_shown', {
      'placement': placement.wireName,
      'careType': careType,
      'weatherContextType': weatherContextType,
    });
  }

  static void rainConfirmed({required PlantWeatherContext placement}) {
    MixpanelService.trackEvent('rain_care_confirmed', {
      'placement': placement.wireName,
      'careType': 'watering',
      'weatherContextType': 'observed_rain',
    });
  }

  static void rainRejected({required PlantWeatherContext placement}) {
    MixpanelService.trackEvent('rain_care_rejected', {
      'placement': placement.wireName,
      'careType': 'watering',
      'weatherContextType': 'observed_rain',
    });
  }

  static void contextUnavailable() {
    MixpanelService.trackEvent('weather_context_unavailable', {
      'weatherContextType': 'unavailable',
    });
  }
}
