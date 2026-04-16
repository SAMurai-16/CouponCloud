import 'dart:async';

abstract final class ApiRequestPolicy {
  static const Duration readTimeout = Duration(seconds: 20);
  static const Duration writeTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);

  static Future<T> runGetWithRetry<T>(
    Future<T> Function() request, {
    Duration timeout = readTimeout,
    int retries = 1,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await request().timeout(timeout);
      } on TimeoutException {
        if (attempt > retries) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
  }
}
