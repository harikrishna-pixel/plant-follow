import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Helper class to manage banner display logic
class BannerHelper {
  /// Check if banner should be shown for a specific screen
  /// Returns true if:
  /// - User is not subscribed
  /// - At least one day has passed since last banner was shown for this screen
  static Future<bool> shouldShowBanner(String screenId) async {
    try {
      // Check if user is subscribed
      final customerInfo = await Purchases.getCustomerInfo();
      final isSubscribed = customerInfo.entitlements.active.isNotEmpty;
      
      if (isSubscribed) {
        return false; // Don't show banner if subscribed
      }

      // Check last banner shown date for this specific screen
      final prefs = await SharedPreferences.getInstance();
      final lastBannerDateKey = 'last_banner_shown_date_$screenId';
      final lastBannerDateStr = prefs.getString(lastBannerDateKey);
      
      if (lastBannerDateStr == null) {
        // First time showing banner for this screen
        await _saveBannerShownDate(screenId);
        return true;
      }

      final lastBannerDate = DateTime.parse(lastBannerDateStr);
      final now = DateTime.now();
      
      // Calculate difference in days
      final difference = now.difference(lastBannerDate).inDays;
      
      // Show banner if at least 1 day has passed (every other day)
      if (difference >= 1) {
        await _saveBannerShownDate(screenId);
        return true;
      }
      
      return false;
    } catch (e) {
      // On error, don't show banner
      return false;
    }
  }

  /// Save the current date as the last banner shown date for a specific screen
  static Future<void> _saveBannerShownDate(String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastBannerDateKey = 'last_banner_shown_date_$screenId';
    await prefs.setString(lastBannerDateKey, DateTime.now().toIso8601String());
  }

  /// Check if user is subscribed
  static Future<bool> isSubscribed() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

