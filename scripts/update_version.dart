import 'dart:io';

/// Script to update app_version.dart from pubspec.yaml
/// Run this script: dart scripts/update_version.dart
void main() async {
  try {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      print('Error: pubspec.yaml not found');
      exit(1);
    }

    final content = await pubspecFile.readAsString();
    final versionMatch = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
    
    if (versionMatch == null) {
      print('Error: Could not find version in pubspec.yaml');
      exit(1);
    }

    final versionString = versionMatch.group(1)?.trim() ?? '1.0.2+2';
    final parts = versionString.split('+');
    final version = parts[0];
    final buildNumber = parts.length > 1 ? parts[1] : '';

    final versionFile = File('lib/utils/app_version.dart');
    final newContent = '''/// App version information
/// This file is auto-generated from pubspec.yaml
/// To update: Run "dart scripts/update_version.dart" or update pubspec.yaml and rebuild
class AppVersion {
  static const String _versionString = '$versionString';
  
  /// Get version number (e.g., "$version")
  static String get version {
    final parts = _versionString.split('+');
    return parts[0];
  }
  
  /// Get build number (e.g., "$buildNumber")
  static String get buildNumber {
    final parts = _versionString.split('+');
    return parts.length > 1 ? parts[1] : '';
  }
  
  /// Get full version string
  static String get fullVersion => _versionString;
}
''';

    await versionFile.writeAsString(newContent);
    print('✅ Updated app_version.dart with version: $versionString');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

