/// V1 primary destinations. Camera is an action, not a selected tab.
class V1Nav {
  static const todayIndex = 0;
  static const plantsIndex = 1;
  static const cameraActionIndex = 2;
  static const meIndex = 3;

  static const todayLabel = 'Today';
  static const plantsLabel = 'Plants';
  static const meLabel = 'Me';

  static const primaryLabels = [todayLabel, plantsLabel, meLabel];

  static const cameraIsPersistentTab = false;
  static const askMeIsPrimaryDestination = false;

  /// Restore Purchase must replace the stack with the tab shell, not HomeScreen.
  static const restorePurchaseUsesTabShell = true;

  static bool isPrimaryDestination(String label) =>
      primaryLabels.contains(label);
}

enum CameraEntryMode { identify, diagnose }

class CameraEntryRoutes {
  static const lastModePrefsKey = 'camera_last_mode';

  static String wireName(CameraEntryMode mode) =>
      mode == CameraEntryMode.identify ? 'identify' : 'diagnose';

  static CameraEntryMode fromWire(String? value) {
    return value == 'diagnose'
        ? CameraEntryMode.diagnose
        : CameraEntryMode.identify;
  }
}

/// Secondary tools kept off the V1 tab bar. AI Botanist stays reachable from Me.
class MeSecondaryTools {
  static const aiBotanist = 'AI Botanist';
  static const search = 'Search';
  static const lightMeter = 'Light Meter';
  static const weather = 'Weather';
  static const scanHistory = 'Scan History';
  static const reminders = 'Reminders';

  static const titles = [
    aiBotanist,
    search,
    lightMeter,
    weather,
    scanHistory,
    reminders,
  ];
}
