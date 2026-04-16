import 'package:http/http.dart' as http;

http.Client createHttpClient() => _CookiePersistingClient(http.Client());

class _CookiePersistingClient extends http.BaseClient {
  _CookiePersistingClient(this._inner);

  final http.Client _inner;
  final Map<String, Map<String, String>> _cookiesByOrigin = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
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
    }

    return response;
  }

  @override
  void close() {
    _inner.close();
  }

  String _originKey(Uri uri) => '${uri.scheme}://${uri.host}:${uri.port}';

  List<String> _splitSetCookieHeader(String headerValue) {
    return headerValue.split(RegExp(r',(?=\s*[^;=,\s]+=)'));
  }
}
