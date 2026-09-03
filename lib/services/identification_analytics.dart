import '../mixpanel/mixpanel.dart';
import '../model/data_model/plant_model.dart';
import 'identification_result.dart';

/// Mixpanel wrappers. Never log photos or raw model payloads.
class IdentificationAnalytics {
  IdentificationAnalytics._();

  static void started() {
    MixpanelService.trackEvent('identification_started', null);
  }

  static void succeeded(IdentificationResult result) {
    MixpanelService.trackEvent('identification_succeeded', {
      'confidence': SpeciesConfidenceCodec.wireName(result.confidence),
      'identity_status': IdentityStatusCodec.wireName(result.identityStatus),
    });
  }

  static void uncertain(IdentificationResult result) {
    MixpanelService.trackEvent('identification_uncertain', {
      'confidence': SpeciesConfidenceCodec.wireName(result.confidence),
      'identity_status': IdentityStatusCodec.wireName(result.identityStatus),
    });
  }

  static void failed(String kind) {
    MixpanelService.trackEvent('identification_failed', {
      'kind': kind,
    });
  }

  static void retry() {
    MixpanelService.trackEvent('identification_retry', null);
  }

  static void alternativeSelected() {
    MixpanelService.trackEvent('alternative_selected', null);
  }

  static void plantSaved({required IdentityStatus identityStatus}) {
    MixpanelService.trackEvent('plant_saved_after_identification', {
      'identity_status': IdentityStatusCodec.wireName(identityStatus),
    });
  }
}
