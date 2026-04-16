import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppEnv {
  static const String _fallbackApiBaseUrl =
      'https://couponcloud-backend.onrender.com';

  static String get apiBaseUrl {
    final configured = dotenv.env['API_BASE_URL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return _fallbackApiBaseUrl;
  }

  static Uri get apiBaseUri => Uri.parse(apiBaseUrl);

  static Uri uri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return apiBaseUri.resolve(normalizedPath);
  }
}
