/// App version information
/// This file is auto-generated from pubspec.yaml
/// To update: Run "dart scripts/update_version.dart" or update pubspec.yaml and rebuild
class AppVersion {
  static const String _versionString = '1.0.2+2';
  
  /// Get version number (e.g., "1.0.2")
  static String get version {
    final parts = _versionString.split('+');
    return parts[0];
  }
  
  /// Get build number (e.g., "2")
  static String get buildNumber {
    final parts = _versionString.split('+');
    return parts.length > 1 ? parts[1] : '';
  }
  
  /// Get full version string
  static String get fullVersion => _versionString;
}
