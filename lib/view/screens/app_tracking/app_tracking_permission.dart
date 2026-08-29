import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class TrackingPermission {
  /// Call this method to request tracking permission
  static Future<void> requestTrackingPermission() async {
    // Check current status
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    
    if (status == TrackingStatus.notDetermined) {
      // Delay to avoid conflicts with app launch (like your Swift code)
      await Future.delayed(const Duration(seconds: 2));
      
      final newStatus = await AppTrackingTransparency.requestTrackingAuthorization();
      handleTrackingStatus(newStatus);
    } else {
      handleTrackingStatus(status);
    }
  }

  static void handleTrackingStatus(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.authorized:
        print('✅ Tracking authorized');
        break;
      case TrackingStatus.denied:
        print('❌ Tracking denied');
        break;
      case TrackingStatus.restricted:
        print('⚠️ Tracking restricted');
        break;
      case TrackingStatus.notDetermined:
        print('ℹ️ Tracking not determined');
        break;
      default:
        print('🔄 Unknown tracking status');
        break;
    }
  }
}
