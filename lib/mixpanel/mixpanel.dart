import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class MixpanelService {
  static Mixpanel? _mixpanel;
  static const String _projectToken = '040708782d0ee47dc6fa10451aaca43c';

  /// Initialize Mixpanel
  static Future<void> initialize() async {
    try {
      _mixpanel = await Mixpanel.init(_projectToken, trackAutomaticEvents: true);
    } catch (e) {
      // Handle initialization error silently
      print('Mixpanel initialization error: $e');
    }
  }

  /// Get the Mixpanel instance
  static Mixpanel? get instance => _mixpanel;

  /// Track a screen view event
  static void trackScreenView(String screenName) {
    try {
      _mixpanel?.track('Screen View', properties: {
        'Screen Name': screenName,
      });
    } catch (e) {
      // Handle tracking error silently
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track Login Screen
  static void trackLoginScreen() {
    try {
      _mixpanel?.track('Login Screen');
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track Paywall Screen
  static void trackPaywallScreen() {
    try {
      _mixpanel?.track('Paywall Screen');
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track Dashboard Screen
  static void trackDashboardScreen() {
    try {
      _mixpanel?.track('Dashboard Screen');
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track Search Screen
  static void trackSearchScreen() {
    try {
      _mixpanel?.track('Search Screen');
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track Scan Screen
  static void trackScanScreen() {
    try {
      _mixpanel?.track('Scan Screen');
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track Diagnosis Screen
  static void trackDiagnosisScreen() {
    try {
      _mixpanel?.track('Diagnosis Screen');
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track AI Botanist Chat Screen
  static void trackAIBotanistChatScreen() {
    try {
      _mixpanel?.track('AI Botanist Chat Screen');
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Track custom events with properties
  static void trackEvent(String eventName, Map<String, dynamic>? properties) {
    try {
      _mixpanel?.track(eventName, properties: properties);
    } catch (e) {
      print('Mixpanel tracking error: $e');
    }
  }

  /// Set user properties
  static void setUserProperties(Map<String, dynamic> properties) {
    try {
      _mixpanel?.getPeople().set(properties['email'], properties['name']);
    } catch (e) {
      print('Mixpanel user properties error: $e');
    }
  }

  /// Identify user
  static void identify(String userId) {
    try {
      _mixpanel?.identify(userId);
    } catch (e) {
      print('Mixpanel identify error: $e');
    }
  }

  /// Reset user (on logout)
  static void reset() {
    try {
      _mixpanel?.reset();
    } catch (e) {
      print('Mixpanel reset error: $e');
    }
  }
}

