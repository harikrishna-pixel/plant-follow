import 'package:in_app_review/in_app_review.dart';

class RateApp {
  static final InAppReview _inAppReview = InAppReview.instance;

  static Future<void> rateApp() async {
    try {
      // Try to check if in-app review is available
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        await _inAppReview.requestReview();
      } else {
        // Fallback: open App Store / Play Store
        await _inAppReview.openStoreListing(
          appStoreId: '6752886333',
        );
      }
    } catch (e) {
      // If any error occurs (including offline), try to open store listing directly
      // Store app can be opened offline, though content won't load without internet
      try {
        await _inAppReview.openStoreListing(
          appStoreId: '6752886333',
        );
      } catch (_) {
        // If opening store also fails, silently fail (user can try again when online)
        // No need to show error message as store will open when internet is available
      }
    }
  }
}
