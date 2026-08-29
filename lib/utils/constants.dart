import 'env.dart';

class AppConstants {
  // API Configuration
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com';

  static String get geminiApiKey => AppEnv.geminiApiKey;
  static String get geminiModel => AppEnv.geminiModel;

  // API Endpoints
  static String get geminiGenerateContentEndpoint =>
      '$geminiBaseUrl/v1/models/$geminiModel:generateContent?key=$geminiApiKey';

  // Add other app-wide constants here
  static const String appName = 'Plant Identifier';
  static const String defaultLocale = 'en_US';
}
