import 'dart:convert';
import 'dart:html' as html;

class SessionData {
  const SessionData({
    required this.isLoggedIn,
    this.studentId,
    this.studentName = 'Student',
    this.messName = 'Mess',
    this.userId,
    this.hostelId,
  });

  final bool isLoggedIn;
  final String? studentId;
  final String studentName;
  final String messName;
  final String? userId;
  final String? hostelId;

  Map<String, dynamic> toJson() {
    return {
      'isLoggedIn': isLoggedIn,
      'studentId': studentId,
      'studentName': studentName,
      'messName': messName,
      'userId': userId,
      'hostelId': hostelId,
    };
  }

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      isLoggedIn: json['isLoggedIn'] == true,
      studentId: json['studentId']?.toString(),
      studentName: json['studentName']?.toString() ?? 'Student',
      messName: json['messName']?.toString() ?? 'Mess',
      userId: json['userId']?.toString(),
      hostelId: json['hostelId']?.toString(),
    );
  }
}

abstract final class SessionStorage {
  static const _storageKey = 'coupon_cloud_session';
  static const SessionData _empty = SessionData(isLoggedIn: false);

  static Future<SessionData> load() async {
    final encoded = html.window.localStorage[_storageKey];
    if (encoded == null || encoded.isEmpty) {
      return _empty;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return SessionData.fromJson(decoded.cast<String, dynamic>());
      }
      return _empty;
    } catch (_) {
      return _empty;
    }
  }

  static Future<void> save(SessionData session) async {
    html.window.localStorage[_storageKey] = jsonEncode(session.toJson());
  }

  static Future<void> clear() async {
    html.window.localStorage.remove(_storageKey);
  }
}
