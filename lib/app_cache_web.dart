import 'dart:html' as html;

abstract final class AppCacheStorage {
  static Future<String?> getString(String key) async {
    return html.window.localStorage[key];
  }

  static Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  static Future<void> remove(String key) async {
    html.window.localStorage.remove(key);
  }
}