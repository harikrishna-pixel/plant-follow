import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Helper class to manage banner display logic.
///
/// Phase 6.5: customer-facing Premium/scan-quota banners are dormant.
/// Date-tracking helpers remain so older installs keep their keys.
class BannerHelper {
  static Future<bool> shouldShowBanner(String screenId) async {
    return false;
  }

  static Future<void> _saveBannerShownDate(String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastBannerDateKey = 'last_banner_shown_date_$screenId';
    await prefs.setString(lastBannerDateKey, DateTime.now().toIso8601String());
  }

  /// Unused by Phase 6.5 UI; kept so the dormant helper still compiles.
  // ignore: unused_element
  static Future<void> preserveLegacyBannerKey(String screenId) =>
      _saveBannerShownDate(screenId);

  static Future<bool> isSubscribed() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
