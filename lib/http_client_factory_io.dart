import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final http.Client _sharedClient = _CookiePersistingClient(http.Client());

http.Client createHttpClient() => _sharedClient;

class _CookiePersistingClient extends http.BaseClient {
  _CookiePersistingClient(this._inner);

  final http.Client _inner;
  final Map<String, Map<String, String>> _cookiesByOrigin = {};
  bool _cookiesLoaded = false;

  static const _storageKey = 'coupon_cloud_http_cookies';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _ensureCookiesLoaded();

    final originKey = _originKey(request.url);
    final cookieJar = _cookiesByOrigin[originKey];
    if (cookieJar != null && cookieJar.isNotEmpty) {
      request.headers['Cookie'] = cookieJar.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }

    final response = await _inner.send(request);
    final setCookieHeader = response.headers['set-cookie'];
    if (setCookieHeader != null && setCookieHeader.isNotEmpty) {
      final targetJar = _cookiesByOrigin.putIfAbsent(originKey, () => {});
      for (final rawCookie in _splitSetCookieHeader(setCookieHeader)) {
        final cookiePair = rawCookie.split(';').first.trim();
        final separatorIndex = cookiePair.indexOf('=');
        if (separatorIndex <= 0) {
          continue;
        }

        final name = cookiePair.substring(0, separatorIndex).trim();
        final value = cookiePair.substring(separatorIndex + 1).trim();
        if (name.isEmpty) {
          continue;
        }

        if (value.isEmpty) {
          targetJar.remove(name);
        } else {
          targetJar[name] = value;
        }
      }
      await _persistCookies();
    }

    return response;
  }

  @override
  void close() {
    _inner.close();
  }

  Future<void> _ensureCookiesLoaded() async {
    if (_cookiesLoaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final jar = <String, String>{};
            final rawJar = entry.value;
            if (rawJar is Map<String, dynamic>) {
              for (final cookie in rawJar.entries) {
                final value = cookie.value?.toString();
                if (value != null && value.isNotEmpty) {
                  jar[cookie.key] = value;
                }
              }
            }
            if (jar.isNotEmpty) {
              _cookiesByOrigin[entry.key] = jar;
            }
          }
        }
      } catch (_) {
        // Ignore malformed persisted cookies and start fresh.
      }
    }

    _cookiesLoaded = true;
  }

  Future<void> _persistCookies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_cookiesByOrigin));
  }

  String _originKey(Uri uri) => '${uri.scheme}://${uri.host}:${uri.port}';

  List<String> _splitSetCookieHeader(String headerValue) {
    return headerValue.split(RegExp(r',(?=\s*[^;=,\s]+=)'));
  }
}
