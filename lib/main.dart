import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'app_cache.dart';
import 'api_http.dart';
import 'api_request_policy.dart';
import 'app_env.dart';
import 'exchange_requests_page.dart';
import 'session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const CouponCloudApp());
}

class CouponCloudApp extends StatelessWidget {
  const CouponCloudApp({super.key});

  static const cream = Color(0xFFFFFBF6);
  static const navy = Color(0xFF011627);
  static const orange = Color(0xFFFF8C00);
  static const gold = Color(0xFFFFB703);
  static const danger = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CouponCloud',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFE5E5E5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          brightness: Brightness.light,
          surface: cream,
        ).copyWith(primary: orange, secondary: gold, error: danger),
      ),
      home: const CouponCloudHome(),
    );
  }
}

abstract final class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const swap = '/swap';
  static const guest = '/guest';
  static const menus = '/menus';
  static const rate = '/rate';
  static const complaint = '/complaint';
  static const profile = '/profile';
  static const exchangeRequests = '/exchange-requests';
}

typedef _SignupAction =
    Future<void> Function(BuildContext context, _SignupPayload payload);
typedef _LoginAction =
    Future<void> Function(BuildContext context, _LoginPayload payload);
typedef _RateFeedbackAction =
    Future<_ApiResult> Function(_RateFeedbackInput input);
typedef _ComplaintAction = Future<_ApiResult> Function(_ComplaintInput input);
typedef _CouponExchangeAction =
    Future<_ApiResult> Function(_CouponExchangeRequestInput input);

class _SignupPayload {
  const _SignupPayload({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.hostelId,
    this.studentId,
    this.staffId,
  });

  final String name;
  final String email;
  final String password;
  final String role;
  final String hostelId;
  final String? studentId;
  final String? staffId;
}

class _LoginPayload {
  const _LoginPayload({required this.password, required this.studentId});

  final String password;
  final String studentId;
}

class _ApiResult {
  const _ApiResult({
    required this.isSuccess,
    required this.statusCode,
    this.body = '',
    this.error,
  });

  final bool isSuccess;
  final int statusCode;
  final String body;
  final String? error;
}

class _RateFeedbackInput {
  const _RateFeedbackInput({
    required this.couponMeal,
    required this.rating,
    required this.description,
  });

  final String couponMeal;
  final int rating;
  final String description;
}

class _ComplaintInput {
  const _ComplaintInput({
    required this.couponMeal,
    required this.complaintType,
    required this.photoFile,
    required this.description,
    this.photo = '',
  });

  final String couponMeal;
  final String complaintType;
  final XFile photoFile;
  final String description;
  final String photo;
}

class _CouponExchangeRequestInput {
  const _CouponExchangeRequestInput({
    required this.couponId,
    required this.requestedToStudentId,
    required this.message,
  });

  final String couponId;
  final String requestedToStudentId;
  final String message;
}

class _CouponExchangeRequestRecord {
  const _CouponExchangeRequestRecord({
    required this.exchangeId,
    required this.couponId,
    required this.requestedToStudentId,
    required this.message,
    this.status,
    this.requestedByStudentId,
    this.requestedByName,
    this.couponMeal,
    this.createdAt,
  });

  final String exchangeId;
  final String couponId;
  final String requestedToStudentId;
  final String message;
  final String? status;
  final String? requestedByStudentId;
  final String? requestedByName;
  final String? couponMeal;
  final String? createdAt;

  bool get isPending =>
      (status ?? '').trim().toLowerCase().isEmpty ||
      (status ?? '').trim().toLowerCase() == 'pending';
}

class _CouponRecord {
  const _CouponRecord({required this.couponId, this.raw});

  final String couponId;
  final Map<String, dynamic>? raw;

  String? get meal => raw?['coupon_meal']?.toString();
  String? get hostelId => raw?['hostel_id']?.toString();
  String? get qrImageUrl => raw?['qr_image_url']?.toString();
  String? get couponDate => raw?['coupon_date']?.toString();
  String? get validTill => raw?['valid_till']?.toString();
}

class _AuthApi {
  const _AuthApi();

  static final Uri _signupUri = AppEnv.uri('/signup/');
  static final Uri _loginUri = AppEnv.uri('/login/');

  Future<_ApiResult> signup(_SignupPayload payload) {
    final body = <String, dynamic>{
      'name': payload.name,
      'email': payload.email,
      'password': payload.password,
      'role': payload.role,
      'hostel_id': payload.hostelId,
    };

    if (payload.role == 'student') {
      body['student_id'] = payload.studentId;
    }
    if (payload.role == 'staff') {
      body['staff_id'] = payload.staffId;
    }

    return _post(_signupUri, body);
  }

  Future<_ApiResult> login(_LoginPayload payload) {
    return _post(_loginUri, {
      'student_id': payload.studentId,
      'password': payload.password,
    });
  }

  Future<_ApiResult> _post(Uri uri, Map<String, dynamic> payload) async {
    try {
      final requestBody = jsonEncode(
        payload..removeWhere((key, value) => value == null),
      );
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'application/json'
        ..bodyBytes = utf8.encode(requestBody);

      final streamed = await ApiHttp.client
          .send(request)
          .timeout(ApiRequestPolicy.writeTimeout);
      final response = await http.Response.fromStream(streamed);

      return _ApiResult(
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (error) {
      return _ApiResult(
        isSuccess: false,
        statusCode: 0,
        error: error.toString(),
      );
    }
  }
}

class _FeedbackApi {
  const _FeedbackApi();

  static final Uri _feedbacksUri = AppEnv.uri('/feedbacks/');

  Future<_ApiResult> submitFeedback({
    required String raisedBy,
    required String raisedById,
    required String couponMeal,
    required int rating,
    required String description,
  }) async {
    try {
      final payload = <String, dynamic>{
        'raised_by': raisedBy,
        'raised_by_id': raisedById,
        'coupon_meal': couponMeal,
        'rating': rating,
        'description': description,
      };

      final requestBody = jsonEncode(
        payload..removeWhere((key, value) => value == null),
      );
      final request = http.Request('POST', _feedbacksUri)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'application/json'
        ..bodyBytes = utf8.encode(requestBody);

      final streamed = await ApiHttp.client
          .send(request)
          .timeout(ApiRequestPolicy.writeTimeout);
      final response = await http.Response.fromStream(streamed);

      return _ApiResult(
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (error) {
      return _ApiResult(
        isSuccess: false,
        statusCode: 0,
        error: error.toString(),
      );
    }
  }
}

class _ComplaintApi {
  const _ComplaintApi();

  static final Uri _complaintsUri = AppEnv.uri('/complaints/');

  Future<_ApiResult> submitComplaint({
    required String raisedBy,
    required String raisedById,
    required String mess,
    required String hostelId,
    required String couponMeal,
    required String complaintType,
    required XFile photoFile,
    required String description,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _complaintsUri)
        ..headers['Accept'] = 'application/json'
        ..fields['raised_by'] = raisedBy
        ..fields['raised_by_id'] = raisedById
        ..fields['mess'] = mess
        ..fields['hostel_id'] = hostelId
        ..fields['coupon_meal'] = couponMeal
        ..fields['complaint_type'] = complaintType
        ..fields['description'] = description;

      if (kIsWeb) {
        final bytes = await photoFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            bytes,
            filename: photoFile.name.isEmpty
                ? 'complaint_photo.jpg'
                : photoFile.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            photoFile.path,
            filename: photoFile.name.isEmpty ? null : photoFile.name,
          ),
        );
      }

      final streamed = await ApiHttp.client
          .send(request)
          .timeout(ApiRequestPolicy.uploadTimeout);
      final response = await http.Response.fromStream(streamed);

      return _ApiResult(
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (error) {
      return _ApiResult(
        isSuccess: false,
        statusCode: 0,
        error: error.toString(),
      );
    }
  }
}

class _CouponExchangeApi {
  const _CouponExchangeApi();

  static final Uri _exchangeRequestsUri = AppEnv.uri(
    '/coupon-exchange-requests/',
  );

  Future<List<_CouponExchangeRequestRecord>> fetchExchangeRequests() async {
    try {
      final response = await ApiRequestPolicy.runGetWithRetry(
        () => ApiHttp.client.get(
          _exchangeRequestsUri,
          headers: const {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Exchange requests request failed with HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _parseRequestList(decoded);
    } catch (error) {
      throw Exception('Could not load exchange requests: $error');
    }
  }

  Future<_ApiResult> submitExchangeRequest({
    required String couponId,
    required String requestedToStudentId,
    required String message,
  }) async {
    try {
      final payload = <String, dynamic>{
        'coupon_id': couponId,
        'requested_to_student_id': requestedToStudentId,
        'message': message,
      };

      final requestBody = jsonEncode(
        payload..removeWhere((key, value) => value == null),
      );
      final request = http.Request('POST', _exchangeRequestsUri)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'application/json'
        ..bodyBytes = utf8.encode(requestBody);

      final streamed = await ApiHttp.client
          .send(request)
          .timeout(ApiRequestPolicy.writeTimeout);
      final response = await http.Response.fromStream(streamed);

      return _ApiResult(
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (error) {
      return _ApiResult(
        isSuccess: false,
        statusCode: 0,
        error: error.toString(),
      );
    }
  }

  Future<_ApiResult> acceptExchangeRequest(String exchangeId) async {
    return _postEmpty(
      AppEnv.uri('/coupon-exchange-requests/$exchangeId/accept/'),
    );
  }

  Future<_ApiResult> rejectExchangeRequest(String exchangeId) async {
    return _postEmpty(
      AppEnv.uri('/coupon-exchange-requests/$exchangeId/reject/'),
    );
  }

  Future<_ApiResult> _postEmpty(Uri uri) async {
    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'application/json'
        ..bodyBytes = utf8.encode('{}');

      final streamed = await ApiHttp.client
          .send(request)
          .timeout(ApiRequestPolicy.writeTimeout);
      final response = await http.Response.fromStream(streamed);

      return _ApiResult(
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (error) {
      return _ApiResult(
        isSuccess: false,
        statusCode: 0,
        error: error.toString(),
      );
    }
  }

  List<_CouponExchangeRequestRecord> _parseRequestList(dynamic decoded) {
    final items = <dynamic>[];
    if (decoded is List) {
      items.addAll(decoded);
    } else if (decoded is Map<String, dynamic>) {
      for (final key in ['results', 'data', 'requests', 'exchanges']) {
        final value = decoded[key];
        if (value is List) {
          items.addAll(value);
          break;
        }
      }
      if (items.isEmpty) {
        items.add(decoded);
      }
    }

    return items
        .map(_parseRequestRecord)
        .whereType<_CouponExchangeRequestRecord>()
        .toList();
  }

  _CouponExchangeRequestRecord? _parseRequestRecord(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final exchangeId = _asText(raw, const ['exchange_id', 'id', 'request_id']);
    final couponId = _asText(raw, const ['coupon_id', 'couponId']);
    final requestedToStudentId = _asText(raw, const [
      'requested_to_student_id',
      'requestedToStudentId',
    ]);
    final message = _asText(raw, const ['message', 'note']) ?? '';
    if (exchangeId == null ||
        couponId == null ||
        requestedToStudentId == null) {
      return null;
    }

    return _CouponExchangeRequestRecord(
      exchangeId: exchangeId,
      couponId: couponId,
      requestedToStudentId: requestedToStudentId,
      message: message,
      status: _asText(raw, const ['status']),
      requestedByStudentId: _asText(raw, const [
        'requested_by_student_id',
        'requestedByStudentId',
      ]),
      requestedByName: _asText(raw, const [
        'requested_by_name',
        'requestedByName',
      ]),
      couponMeal: _asText(raw, const ['coupon_meal', 'couponMeal']),
      createdAt: _asText(raw, const ['created_at', 'createdAt']),
    );
  }

  String? _asText(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty && text != 'null') {
          return text;
        }
      }
    }
    return null;
  }
}

class _CouponApi {
  const _CouponApi();

  static final Uri _couponsUri = AppEnv.uri('/coupons');
  static final Uri _apiBaseUri = AppEnv.apiBaseUri;

  Future<List<_CouponRecord>> fetchCoupons() async {
    final response = await ApiRequestPolicy.runGetWithRetry(
      () => ApiHttp.client.get(
        _couponsUri,
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Coupons request failed with HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return _parseCouponList(decoded);
  }

  Future<Uint8List> fetchCouponQrBytes(String couponId) async {
    final uri = AppEnv.uri('/coupons/${Uri.encodeComponent(couponId)}/qr/');
    final response = await ApiRequestPolicy.runGetWithRetry(
      () => ApiHttp.client.get(
        uri,
        headers: const {'Accept': 'application/json,image/*,*/*'},
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('QR request failed with HTTP ${response.statusCode}');
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.startsWith('image/')) {
      return response.bodyBytes;
    }

    final bodyText = utf8
        .decode(response.bodyBytes, allowMalformed: true)
        .trim();
    if (bodyText.isEmpty) {
      return response.bodyBytes;
    }

    try {
      final decoded = jsonDecode(bodyText);
      final imageSource = _extractImageSource(decoded);
      if (imageSource != null) {
        return _resolveImageSource(imageSource);
      }
    } on FormatException {
      // Fall through to raw bytes/base64 handling below.
    }

    final base64Candidate = _stripDataUriPrefix(bodyText);
    if (base64Candidate != null) {
      return base64Decode(base64Candidate);
    }

    return response.bodyBytes;
  }

  Future<Uint8List> fetchImageFromUrl(String imageUrl) {
    return _resolveImageSource(imageUrl);
  }

  List<_CouponRecord> _parseCouponList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .map(_parseCouponRecord)
          .whereType<_CouponRecord>()
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in ['results', 'data', 'coupons']) {
        final value = decoded[key];
        if (value is List) {
          return value
              .map(_parseCouponRecord)
              .whereType<_CouponRecord>()
              .toList();
        }
      }

      final record = _parseCouponRecord(decoded);
      if (record != null) {
        return [record];
      }
    }

    throw Exception('Unexpected /coupons response format');
  }

  _CouponRecord? _parseCouponRecord(dynamic item) {
    if (item is String) {
      return _CouponRecord(couponId: item);
    }

    if (item is Map<String, dynamic>) {
      final couponId =
          item['coupon_id'] ?? item['couponId'] ?? item['id'] ?? item['code'];
      if (couponId is String && couponId.trim().isNotEmpty) {
        return _CouponRecord(couponId: couponId.trim(), raw: item);
      }
    }

    return null;
  }

  String? _extractImageSource(dynamic decoded) {
    if (decoded is String) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in [
        'qr',
        'qr_image',
        'qr_image_url',
        'image',
        'image_base64',
        'base64',
        'data',
        'url',
        'result',
      ]) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return null;
  }

  Future<Uint8List> _resolveImageSource(String source) async {
    final normalized = source.trim();
    final dataUriBody = _stripDataUriPrefix(normalized);
    if (dataUriBody != null) {
      return base64Decode(dataUriBody);
    }

    if (normalized.startsWith('/')) {
      final imageResponse = await ApiRequestPolicy.runGetWithRetry(
        () => ApiHttp.client.get(AppEnv.apiBaseUri.resolve(normalized)),
      );
      if (imageResponse.statusCode < 200 || imageResponse.statusCode >= 300) {
        throw Exception(
          'QR image fetch failed with HTTP ${imageResponse.statusCode}',
        );
      }
      return imageResponse.bodyBytes;
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      final imageResponse = await ApiRequestPolicy.runGetWithRetry(
        () => ApiHttp.client.get(Uri.parse(normalized)),
      );
      if (imageResponse.statusCode < 200 || imageResponse.statusCode >= 300) {
        throw Exception(
          'QR image fetch failed with HTTP ${imageResponse.statusCode}',
        );
      }
      return imageResponse.bodyBytes;
    }

    return base64Decode(normalized);
  }

  String? _stripDataUriPrefix(String value) {
    if (!value.startsWith('data:')) {
      return null;
    }

    final commaIndex = value.indexOf(',');
    if (commaIndex < 0 || commaIndex == value.length - 1) {
      return null;
    }

    return value.substring(commaIndex + 1);
  }
}

class _StudentApi {
  const _StudentApi();

  Future<Map<String, dynamic>> fetchStudentDetails(String studentId) async {
    final uri = AppEnv.uri('/students/${Uri.encodeComponent(studentId)}/');
    final response = await ApiRequestPolicy.runGetWithRetry(
      () => ApiHttp.client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Student profile request failed with HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Unexpected student profile response format');
  }

  Future<_StudentProfile> fetchStudentProfile(String studentId) async {
    final decoded = await fetchStudentDetails(studentId);
    if (decoded is Map<String, dynamic>) {
      final nameCandidate =
          decoded['name'] ?? decoded['student_name'] ?? decoded['full_name'];
      final messCandidate =
          decoded['mess_name'] ?? decoded['messName'] ?? decoded['hostel_name'];
      final userIdCandidate =
          decoded['user_id'] ?? decoded['userId'] ?? decoded['user'];
      final hostelCandidate =
          decoded['hostel_id'] ?? decoded['hostelId'] ?? decoded['hostel'];

      final name = nameCandidate is String && nameCandidate.trim().isNotEmpty
          ? nameCandidate.trim()
          : 'Student';
      final messName =
          messCandidate is String && messCandidate.trim().isNotEmpty
          ? messCandidate.trim()
          : 'Mess';
      final userId = userIdCandidate?.toString().trim();
      final hostelId = hostelCandidate?.toString().trim();

      return _StudentProfile(
        name: name,
        messName: messName,
        userId: userId,
        hostelId: hostelId,
      );
    }

    throw Exception('Unexpected student profile response format');
  }
}

class _StudentProfile {
  const _StudentProfile({
    required this.name,
    required this.messName,
    this.userId,
    this.hostelId,
  });

  final String name;
  final String messName;
  final String? userId;
  final String? hostelId;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'messName': messName,
      'userId': userId,
      'hostelId': hostelId,
    };
  }

  factory _StudentProfile.fromJson(Map<String, dynamic> json) {
    return _StudentProfile(
      name: json['name']?.toString() ?? 'Student',
      messName: json['messName']?.toString() ?? 'Mess',
      userId: json['userId']?.toString(),
      hostelId: json['hostelId']?.toString(),
    );
  }
}

class _MessMenuEntry {
  const _MessMenuEntry({
    required this.id,
    required this.messName,
    required this.hostelId,
    required this.dayOfWeek,
    required this.meal,
    required this.items,
  });

  final int id;
  final String messName;
  final String hostelId;
  final String dayOfWeek;
  final String meal;
  final List<String> items;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messName': messName,
      'hostelId': hostelId,
      'dayOfWeek': dayOfWeek,
      'meal': meal,
      'items': items,
    };
  }

  factory _MessMenuEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return _MessMenuEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      messName: json['messName']?.toString() ?? '',
      hostelId: json['hostelId']?.toString() ?? '',
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      meal: json['meal']?.toString() ?? '',
      items: rawItems is List
          ? rawItems.map((item) => item.toString()).toList()
          : const [],
    );
  }
}

abstract final class _DailyCache {
  static const _studentProfilePrefix = 'coupon_cloud_student_profile';
  static const _menusPrefix = 'coupon_cloud_daily_menus';
  static const _qrPrefix = 'coupon_cloud_qr';
  static final Map<String, Uint8List> _qrMemoryCache = {};

  static String _todayKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _studentProfileKey(String studentId) {
    return '$_studentProfilePrefix-${_todayKey()}-${Uri.encodeComponent(studentId)}';
  }

  static String _menusKey() => '$_menusPrefix-${_todayKey()}';

  static String _qrKey(String couponId) {
    return '$_qrPrefix-${_todayKey()}-${Uri.encodeComponent(couponId)}';
  }

  static Future<_StudentProfile?> loadStudentProfile(String studentId) async {
    final encoded = await AppCacheStorage.getString(
      _studentProfileKey(studentId),
    );
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return _StudentProfile.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<void> saveStudentProfile(
    String studentId,
    _StudentProfile profile,
  ) async {
    await AppCacheStorage.setString(
      _studentProfileKey(studentId),
      jsonEncode(profile.toJson()),
    );
  }

  static Future<Map<String, List<_MessMenuEntry>>?> loadMenus() async {
    final encoded = await AppCacheStorage.getString(_menusKey());
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        final rawMenus = decoded['menusByHostel'];
        if (rawMenus is Map<String, dynamic>) {
          final grouped = <String, List<_MessMenuEntry>>{};
          for (final entry in rawMenus.entries) {
            final value = entry.value;
            if (value is List) {
              grouped[entry.key] = value
                  .whereType<Map<String, dynamic>>()
                  .map(_MessMenuEntry.fromJson)
                  .toList();
            }
          }
          return grouped;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<void> saveMenus(
    Map<String, List<_MessMenuEntry>> menusByHostel,
  ) async {
    final encodedMenus = menusByHostel.map((hostelId, entries) {
      return MapEntry(
        hostelId,
        entries.map((entry) => entry.toJson()).toList(),
      );
    });

    await AppCacheStorage.setString(
      _menusKey(),
      jsonEncode({'menusByHostel': encodedMenus}),
    );
  }

  static Future<Uint8List?> loadQrBytes(String couponId) async {
    final memoryCached = _qrMemoryCache[couponId];
    if (memoryCached != null) {
      return memoryCached;
    }

    final encoded = await AppCacheStorage.getString(_qrKey(couponId));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = base64Decode(encoded);
      _qrMemoryCache[couponId] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveQrBytes(String couponId, Uint8List bytes) async {
    _qrMemoryCache[couponId] = bytes;
    await AppCacheStorage.setString(_qrKey(couponId), base64Encode(bytes));
  }

  static Future<void> clearQrBytes(String couponId) async {
    _qrMemoryCache.remove(couponId);
    await AppCacheStorage.remove(_qrKey(couponId));
  }
}

class _MessMenuApi {
  const _MessMenuApi();

  static final Uri _menusListUri = AppEnv.uri('/mess-menus/');

  Future<Map<String, List<_MessMenuEntry>>> fetchFullDayMenusByHostel() async {
    final todayCode = _weekdayCode(DateTime.now().weekday);
    final allMenus = await _tryFetchFromListEndpoint(dayOfWeek: todayCode);
    if (allMenus.isEmpty) {
      return const {};
    }

    final grouped = <String, List<_MessMenuEntry>>{};
    for (final menu in allMenus) {
      grouped.putIfAbsent(menu.hostelId, () => []).add(menu);
    }

    final mealOrder = {'B': 0, 'L': 1, 'S': 2, 'D': 3};
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final mealCompare = (mealOrder[a.meal.toUpperCase()] ?? 99).compareTo(
          mealOrder[b.meal.toUpperCase()] ?? 99,
        );
        if (mealCompare != 0) {
          return mealCompare;
        }
        return a.id.compareTo(b.id);
      });
    }

    return grouped;
  }

  Future<List<_MessMenuEntry>> _tryFetchFromListEndpoint({
    required String dayOfWeek,
  }) async {
    try {
      final uri = _menusListUri.replace(
        queryParameters: {'day_of_week': dayOfWeek},
      );
      final response = await ApiRequestPolicy.runGetWithRetry(
        () => ApiHttp.client.get(
          uri,
          headers: const {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final list = _extractList(decoded);
      return list.map(_parseMenuEntry).whereType<_MessMenuEntry>().toList();
    } catch (_) {
      return const [];
    }
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      final results = decoded['results'];
      if (results is List) {
        return results;
      }
      final data = decoded['data'];
      if (data is List) {
        return data;
      }
    }
    return const [];
  }

  _MessMenuEntry? _parseMenuEntry(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final mess = raw['mess'];
    if (mess is! Map<String, dynamic>) {
      return null;
    }

    final hostelIdRaw = mess['hostel_id'];
    final dayRaw = raw['day_of_week'];
    final mealRaw = raw['meal'];
    final itemsRaw = raw['items'];

    if (hostelIdRaw is! String ||
        dayRaw is! String ||
        mealRaw is! String ||
        itemsRaw is! List) {
      return null;
    }

    final sortedItems = itemsRaw.whereType<Map<String, dynamic>>().toList()
      ..sort((a, b) {
        final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
        final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
        return aOrder.compareTo(bOrder);
      });

    final itemNames = sortedItems
        .map((item) => item['name'])
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    return _MessMenuEntry(
      id: (raw['id'] as num?)?.toInt() ?? 0,
      messName: (mess['name'] as String?)?.trim() ?? hostelIdRaw.trim(),
      hostelId: hostelIdRaw.trim(),
      dayOfWeek: dayRaw.trim(),
      meal: mealRaw.trim(),
      items: itemNames,
    );
  }

  String _weekdayCode(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      case DateTime.sunday:
        return 'SUN';
      default:
        return 'MON';
    }
  }
}

class CouponCloudHome extends StatefulWidget {
  const CouponCloudHome({super.key});

  @override
  State<CouponCloudHome> createState() => _CouponCloudHomeState();
}

class _CouponCloudHomeState extends State<CouponCloudHome> {
  bool _isLoggedIn = false;
  bool _isInitializing = true;
  int _rating = 0;
  final _authApi = const _AuthApi();
  final _feedbackApi = const _FeedbackApi();
  final _complaintApi = const _ComplaintApi();
  final _couponExchangeApi = const _CouponExchangeApi();
  final _studentApi = const _StudentApi();
  String _studentName = 'Student';
  String _messName = 'Mess';
  String? _userId;
  String? _hostelId;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  void _rate(int value) => setState(() => _rating = value);

  Future<void> _restoreSession() async {
    final session = await SessionStorage.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggedIn = session.isLoggedIn;
      _studentId = session.studentId;
      _studentName = session.studentName;
      _messName = session.messName;
      _userId = session.userId;
      _hostelId = session.hostelId;
      _isInitializing = false;
    });

    if (session.isLoggedIn && session.studentId != null) {
      unawaited(_loadStudentProfile(session.studentId!));
    }
  }

  Future<void> _saveSession() {
    return SessionStorage.save(
      SessionData(
        isLoggedIn: _isLoggedIn,
        studentId: _studentId,
        studentName: _studentName,
        messName: _messName,
        userId: _userId,
        hostelId: _hostelId,
      ),
    );
  }

  Route<dynamic> _buildRoute(RouteSettings settings) {
    final routeName = settings.name ?? AppRoutes.login;

    if (!_isLoggedIn &&
        routeName != AppRoutes.login &&
        routeName != AppRoutes.signup) {
      return _buildPageRoute(AppRoutes.login, _buildLoginScreen);
    }

    switch (routeName) {
      case AppRoutes.login:
        return _buildPageRoute(AppRoutes.login, _buildLoginScreen);
      case AppRoutes.signup:
        return _buildPageRoute(AppRoutes.signup, _buildSignupScreen);
      case AppRoutes.home:
        return _buildPageRoute(AppRoutes.home, _buildHomeScreen);
      case AppRoutes.swap:
        return _buildPageRoute(AppRoutes.swap, _buildSwapScreen);
      case AppRoutes.guest:
        return _buildPageRoute(AppRoutes.guest, _buildGuestScreen);
      case AppRoutes.menus:
        return _buildPageRoute(AppRoutes.menus, _buildMenusScreen);
      case AppRoutes.rate:
        return _buildPageRoute(AppRoutes.rate, _buildRateScreen);
      case AppRoutes.complaint:
        return _buildPageRoute(AppRoutes.complaint, _buildComplaintScreen);
      case AppRoutes.profile:
        return _buildPageRoute(AppRoutes.profile, _buildProfileScreen);
      case AppRoutes.exchangeRequests:
        return _buildPageRoute(
          AppRoutes.exchangeRequests,
          _buildExchangeRequestsScreen,
        );
      default:
        return _buildPageRoute(AppRoutes.login, _buildLoginScreen);
    }
  }

  PageRouteBuilder<void> _buildPageRoute(String name, WidgetBuilder builder) {
    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          SingleChildScrollView(key: ValueKey(name), child: builder(context)),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curve);
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  Widget _buildLoginScreen(BuildContext context) {
    return _LoginScreen(
      onLogin: _login,
      onOpenSignup: () => Navigator.of(context).pushNamed(AppRoutes.signup),
    );
  }

  Widget _buildSignupScreen(BuildContext context) {
    return _SignupScreen(
      onSignup: _signup,
      onOpenLogin: () =>
          Navigator.of(context).pushReplacementNamed(AppRoutes.login),
    );
  }

  Future<void> _signup(BuildContext context, _SignupPayload payload) async {
    await _runAuthAction(
      context,
      actionName:
          '${payload.role[0].toUpperCase()}${payload.role.substring(1)} signup',
      request: () => _authApi.signup(payload),
      onSuccess: () {
        if (payload.role == 'student' && payload.studentId != null) {
          unawaited(_loadStudentProfile(payload.studentId!));
        }
      },
    );
  }

  Future<void> _login(BuildContext context, _LoginPayload payload) async {
    await _runAuthAction(
      context,
      actionName: 'Login',
      request: () => _authApi.login(payload),
      onSuccess: () {
        setState(() {
          _studentId = payload.studentId;
          _isLoggedIn = true;
        });
        unawaited(_saveSession());
        unawaited(_loadStudentProfile(payload.studentId));
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      },
    );
  }

  Future<void> _loadStudentProfile(String studentId) async {
    try {
      final cachedProfile = await _DailyCache.loadStudentProfile(studentId);
      if (cachedProfile != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _studentName = cachedProfile.name;
          _messName = cachedProfile.messName;
          _userId = cachedProfile.userId;
          _hostelId = cachedProfile.hostelId;
          _studentId = studentId;
        });
        return;
      }

      final profile = await _studentApi.fetchStudentProfile(studentId);
      if (!mounted) {
        return;
      }
      setState(() {
        _studentName = profile.name;
        _messName = profile.messName;
        _userId = profile.userId;
        _hostelId = profile.hostelId;
        _studentId = studentId;
      });
      unawaited(_DailyCache.saveStudentProfile(studentId, profile));
      unawaited(_saveSession());
    } catch (_) {
      // Keep existing fallback values when profile fetch fails.
    }
  }

  Future<void> _runAuthAction(
    BuildContext context, {
    required String actionName,
    required Future<_ApiResult> Function() request,
    VoidCallback? onSuccess,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('$actionName request started...')),
    );

    final result = await request();
    if (!mounted) {
      return;
    }

    if (result.isSuccess) {
      onSuccess?.call();
      final details = _buildResponseSummary(result);
      messenger.showSnackBar(
        SnackBar(content: Text('$actionName success: $details')),
      );
      return;
    }

    final details = _buildResponseSummary(result);
    messenger.showSnackBar(
      SnackBar(content: Text('$actionName failed: $details')),
    );
  }

  String _buildResponseSummary(_ApiResult result) {
    if (result.error != null) {
      return result.error!;
    }
    final body = result.body.trim();
    if (body.isEmpty) {
      return 'HTTP ${result.statusCode}';
    }
    return 'HTTP ${result.statusCode} - $body';
  }

  Widget _buildHomeScreen(BuildContext context) {
    return _MainScreen(
      studentName: _studentName,
      messName: _messName,
      onNavigate: (route) => Navigator.of(context).pushNamed(route),
      onAvatarTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
      onRequestExchange: _submitCouponExchangeRequest,
    );
  }

  Widget _buildProfileScreen(BuildContext context) {
    return _ProfileScreen(
      studentId: _studentId,
      onBack: () => Navigator.of(context).pop(),
      onLogout: () => _logout(context),
    );
  }

  Widget _buildSwapScreen(BuildContext context) {
    return _SwapScreen(onBack: () => Navigator.of(context).pop());
  }

  Widget _buildGuestScreen(BuildContext context) {
    return _GuestScreen(onBack: () => Navigator.of(context).pop());
  }

  Widget _buildMenusScreen(BuildContext context) {
    return _MenusScreen(onBack: () => Navigator.of(context).pop());
  }

  Widget _buildRateScreen(BuildContext context) {
    return _RateScreen(
      onBack: () => Navigator.of(context).pop(),
      onRate: _rate,
      rating: _rating,
      messName: _messName,
      onSubmitFeedback: _submitRateFeedback,
    );
  }

  Future<_ApiResult> _submitRateFeedback(_RateFeedbackInput input) {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) {
      return Future.value(
        const _ApiResult(
          isSuccess: false,
          statusCode: 0,
          error: 'User ID is missing. Please login again.',
        ),
      );
    }

    return _feedbackApi.submitFeedback(
      raisedBy: _studentName,
      raisedById: userId,
      couponMeal: input.couponMeal,
      rating: input.rating,
      description: input.description,
    );
  }

  Widget _buildComplaintScreen(BuildContext context) {
    return _ComplaintScreen(
      onBack: () => Navigator.of(context).pop(),
      raisedBy: _studentName,
      mess: _messName,
      onSubmitComplaint: _submitComplaint,
    );
  }

  Widget _buildExchangeRequestsScreen(BuildContext context) {
    return CouponExchangeRequestsPage(
      onBack: () => Navigator.of(context).pop(),
    );
  }

  void _logout(BuildContext context) {
    setState(() {
      _isLoggedIn = false;
      _userId = null;
      _hostelId = null;
      _studentId = null;
      _studentName = 'Student';
      _messName = 'Mess';
    });
    unawaited(SessionStorage.clear());
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<_ApiResult> _submitComplaint(_ComplaintInput input) {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) {
      return Future.value(
        const _ApiResult(
          isSuccess: false,
          statusCode: 0,
          error: 'User ID is missing. Please login again.',
        ),
      );
    }

    final hostelId = _hostelId;
    if (hostelId == null || hostelId.trim().isEmpty) {
      return Future.value(
        const _ApiResult(
          isSuccess: false,
          statusCode: 0,
          error: 'Hostel ID is missing. Please login again.',
        ),
      );
    }

    return _complaintApi.submitComplaint(
      raisedBy: _studentName,
      raisedById: userId,
      mess: _messName,
      hostelId: hostelId,
      couponMeal: input.couponMeal,
      complaintType: input.complaintType,
      photoFile: input.photoFile,
      description: input.description,
    );
  }

  Future<_ApiResult> _submitCouponExchangeRequest(
    _CouponExchangeRequestInput input,
  ) {
    return _couponExchangeApi.submitExchangeRequest(
      couponId: input.couponId,
      requestedToStudentId: input.requestedToStudentId,
      message: input.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: CouponCloudApp.cream,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: CouponCloudApp.orange),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CouponCloudApp.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Navigator(
              initialRoute: _isLoggedIn ? AppRoutes.home : AppRoutes.login,
              onGenerateRoute: _buildRoute,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({required this.onLogin, required this.onOpenSignup});

  final _LoginAction onLogin;
  final VoidCallback onOpenSignup;

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  bool _isSubmitting = false;

  final _loginPasswordController = TextEditingController();
  final _loginStudentIdController = TextEditingController();

  @override
  void dispose() {
    _loginPasswordController.dispose();
    _loginStudentIdController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    await action();
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
  }

  void _submitLogin() {
    final password = _loginPasswordController.text;
    final studentId = _loginStudentIdController.text.trim();

    if (password.isEmpty || studentId.isEmpty) {
      _showValidationError('Student ID and password are required.');
      return;
    }

    final payload = _LoginPayload(password: password, studentId: studentId);
    _run(() => widget.onLogin(context, payload));
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const _LogoBlock(),
          const _DividerWithLabel('LOGIN'),
          const SizedBox(height: 18),
          _InputField('Student ID', controller: _loginStudentIdController),
          const SizedBox(height: 14),
          _InputField(
            'Password',
            controller: _loginPasswordController,
            obscureText: true,
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: 'Login',
            onPressed: _isSubmitting ? null : _submitLogin,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isSubmitting ? null : widget.onOpenSignup,
            child: const Text(
              'No account? Sign up',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CouponCloudApp.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupScreen extends StatefulWidget {
  const _SignupScreen({required this.onSignup, required this.onOpenLogin});

  final _SignupAction onSignup;
  final VoidCallback onOpenLogin;

  @override
  State<_SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<_SignupScreen> {
  bool _isSubmitting = false;
  String _signupRole = 'student';

  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupStudentIdController = TextEditingController();
  final _signupStaffIdController = TextEditingController();
  final _signupHostelIdController = TextEditingController();

  @override
  void dispose() {
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupStudentIdController.dispose();
    _signupStaffIdController.dispose();
    _signupHostelIdController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    await action();
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
  }

  void _submitSignup() {
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;
    final studentId = _signupStudentIdController.text.trim();
    final staffId = _signupStaffIdController.text.trim();
    final hostelId = _signupHostelIdController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || hostelId.isEmpty) {
      _showValidationError('Signup fields cannot be empty.');
      return;
    }

    if (_signupRole == 'student' && studentId.isEmpty) {
      _showValidationError('Student ID is required for student signup.');
      return;
    }

    if (_signupRole == 'staff' && staffId.isEmpty) {
      _showValidationError('Staff ID is required for staff signup.');
      return;
    }

    final payload = _SignupPayload(
      name: name,
      email: email,
      password: password,
      role: _signupRole,
      hostelId: hostelId,
      studentId: _signupRole == 'student' ? studentId : null,
      staffId: _signupRole == 'staff' ? staffId : null,
    );

    _run(() => widget.onSignup(context, payload));
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const _LogoBlock(),
          const SizedBox(height: 22),
          const _DividerWithLabel('SIGNUP'),
          const SizedBox(height: 16),
          _InputField('Full Name', controller: _signupNameController),
          const SizedBox(height: 12),
          _InputField('Email', controller: _signupEmailController),
          const SizedBox(height: 12),
          _InputField(
            'Password',
            controller: _signupPasswordController,
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _DropdownMock(
            const ['student', 'staff'],
            selectedValue: _signupRole,
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _signupRole = value ?? _signupRole),
          ),
          const SizedBox(height: 12),
          _InputField(
            _signupRole == 'student' ? 'Student ID' : 'Staff ID',
            controller: _signupRole == 'student'
                ? _signupStudentIdController
                : _signupStaffIdController,
          ),
          const SizedBox(height: 12),
          _InputField('Hostel ID', controller: _signupHostelIdController),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Signup',
            onPressed: _isSubmitting ? null : _submitSignup,
          ),
          const SizedBox(height: 18),
          const Text(
            'Signup sends name, email, password, role, role ID, and hostel ID.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0x80011627),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isSubmitting ? null : widget.onOpenLogin,
            child: const Text(
              'Already have an account? Login',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CouponCloudApp.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainScreen extends StatelessWidget {
  const _MainScreen({
    required this.studentName,
    required this.messName,
    required this.onNavigate,
    required this.onAvatarTap,
    required this.onRequestExchange,
  });
  final String studentName;
  final String messName;
  final ValueChanged<String> onNavigate;
  final VoidCallback onAvatarTap;
  final _CouponExchangeAction onRequestExchange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _Header(
            studentName: studentName,
            messName: messName,
            onExchangeTap: () => onNavigate(AppRoutes.exchangeRequests),
            onAvatarTap: onAvatarTap,
          ),
          const SizedBox(height: 18),
          _QrCard(onRequestExchange: onRequestExchange),
          const SizedBox(height: 22),
          const _SectionLabel('Quick Actions'),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            children: [
              _ActionTile(
                icon: Icons.person_add_alt_1,
                label: 'Guest\nPass',
                onTap: () => onNavigate(AppRoutes.guest),
              ),
              _ActionTile(
                icon: Icons.restaurant_menu,
                label: 'View\nMenus',
                onTap: () => onNavigate(AppRoutes.menus),
              ),
              _ActionTile(
                icon: Icons.star,
                label: 'Rate\nMeal',
                onTap: () => onNavigate(AppRoutes.rate),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DangerButton(
            label: 'Raise Official Hygiene Complaint',
            onPressed: () => onNavigate(AppRoutes.complaint),
          ),
        ],
      ),
    );
  }
}

class _SwapScreen extends StatefulWidget {
  const _SwapScreen({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<_SwapScreen> {
  static const _mealOptions = [
    'Today - Dinner (BH-1)',
    'Tomorrow - Breakfast (BH-1)',
  ];
  static const _transferRoll = '2023IMG-044';
  String _selectedMeal = _mealOptions.first;

  void _confirmSwap() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Swapped "$_selectedMeal" to $_transferRoll')),
    );
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Swap Meal',
      onBack: widget.onBack,
      children: [
        const _FieldLabel('Which meal are you giving up?'),
        _DropdownMock(
          _mealOptions,
          selectedValue: _selectedMeal,
          onChanged: (value) =>
              setState(() => _selectedMeal = value ?? _selectedMeal),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Transfer to (Roll No.):'),
        _InputField('$_transferRoll (hardcoded for now)'),
        const SizedBox(height: 18),
        const _NoteCard(
          'Note: Once swapped, your QR code for this meal will be deactivated and transferred.',
        ),
      ],
      bottom: _PrimaryButton(label: 'Confirm Swap', onPressed: _confirmSwap),
    );
  }
}

class _GuestScreen extends StatefulWidget {
  const _GuestScreen({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<_GuestScreen> {
  static const _messOptions = ['BH-2 Mess', 'BH-3 Mess', 'GH Mess'];
  String _selectedMess = _messOptions.first;
  int _selectedMeal = 1;

  void _pay() {
    final meal = _selectedMeal == 0 ? 'Lunch' : 'Dinner';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Proceeding to UPI for $_selectedMess - $meal - Rs. 50'),
      ),
    );
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Buy Guest Pass',
      onBack: widget.onBack,
      children: [
        const _FieldLabel('Select Hostel Mess'),
        _DropdownMock(
          _messOptions,
          selectedValue: _selectedMess,
          onChanged: (value) =>
              setState(() => _selectedMess = value ?? _selectedMess),
        ),
        const SizedBox(height: 18),
        _MealToggle(
          selectedMeal: _selectedMeal,
          onChanged: (value) => setState(() => _selectedMeal = value),
        ),
        const SizedBox(height: 18),
        const _AmountCard('Rs. 50'),
      ],
      bottom: _PrimaryButton(label: 'Proceed to Pay UPI', onPressed: _pay),
    );
  }
}

class _MenusScreen extends StatefulWidget {
  const _MenusScreen({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_MenusScreen> createState() => _MenusScreenState();
}

class _MenusScreenState extends State<_MenusScreen> {
  final _menuApi = const _MessMenuApi();
  List<String> _hostels = const [];
  Map<String, List<_MessMenuEntry>> _menusByHostel = const {};
  bool _isLoading = true;
  String? _error;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMenus());
  }

  Future<void> _loadMenus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cachedMenus = await _DailyCache.loadMenus();
      if (cachedMenus != null) {
        if (!mounted) {
          return;
        }

        final hostels = cachedMenus.keys.toList()..sort();
        setState(() {
          _menusByHostel = cachedMenus;
          _hostels = hostels;
          _selected = 0;
          _isLoading = false;
          _error = hostels.isEmpty ? 'No menu data found for today.' : null;
        });
        return;
      }

      final grouped = await _menuApi.fetchFullDayMenusByHostel();
      if (!mounted) {
        return;
      }

      final hostels = grouped.keys.toList()..sort();
      setState(() {
        _menusByHostel = grouped;
        _hostels = hostels;
        _selected = 0;
        _isLoading = false;
        _error = hostels.isEmpty ? 'No menu data found for today.' : null;
      });
      unawaited(_DailyCache.saveMenus(grouped));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  String _mealTitle(String mealCode) {
    switch (mealCode.toUpperCase()) {
      case 'B':
        return 'Breakfast (B)';
      case 'L':
        return 'Lunch (L)';
      case 'S':
        return 'Snacks (S)';
      case 'D':
        return 'Dinner (D)';
      default:
        return mealCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMenus = _hostels.isNotEmpty;
    final selectedHostel = hasMenus ? _hostels[_selected] : null;
    final selectedMenus = selectedHostel == null
        ? const <_MessMenuEntry>[]
        : (_menusByHostel[selectedHostel] ?? const <_MessMenuEntry>[]);

    return _ScreenShell(
      title: 'Today\'s Menus',
      onBack: widget.onBack,
      topWidgets: [
        if (hasMenus)
          _MenuSelector(
            hostels: _hostels,
            selectedIndex: _selected,
            onSelected: (index) => setState(() => _selected = index),
          ),
      ],
      children: _isLoading
          ? const [
              SizedBox(height: 20),
              Center(
                child: CircularProgressIndicator(color: CouponCloudApp.orange),
              ),
            ]
          : _error != null && !hasMenus
          ? [
              _NoteCard('Could not load menus: $_error'),
              const SizedBox(height: 10),
              _SecondaryButton(label: 'Retry', onPressed: _loadMenus),
            ]
          : [
              for (var i = 0; i < selectedMenus.length; i++) ...[
                _MenuCard(
                  title: _mealTitle(selectedMenus[i].meal),
                  titleColor: i == 0 ? CouponCloudApp.orange : null,
                  muted: i != 0,
                  items: selectedMenus[i].items,
                ),
                if (i < selectedMenus.length - 1) const SizedBox(height: 14),
              ],
              if (selectedMenus.isEmpty)
                const _NoteCard('No meals available for this hostel today.'),
            ],
      bottom: const SizedBox(height: 8),
    );
  }
}

class _RateScreen extends StatefulWidget {
  const _RateScreen({
    required this.onBack,
    required this.onRate,
    required this.rating,
    required this.messName,
    required this.onSubmitFeedback,
  });

  final VoidCallback onBack;
  final ValueChanged<int> onRate;
  final int rating;
  final String messName;
  final _RateFeedbackAction onSubmitFeedback;

  @override
  State<_RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<_RateScreen> {
  final _descriptionController = TextEditingController();
  String _couponMeal = 'D';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) {
      return;
    }

    final rating = widget.rating;
    if (rating <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await widget.onSubmitFeedback(
      _RateFeedbackInput(
        couponMeal: _couponMeal,
        rating: rating,
        description: _descriptionController.text.trim(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.isSuccess) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Review submitted successfully.')),
      );
      widget.onBack();
      return;
    }

    final details =
        result.error ?? 'HTTP ${result.statusCode} - ${result.body}';
    messenger.showSnackBar(SnackBar(content: Text('Submit failed: $details')));
  }

  @override
  Widget build(BuildContext context) {
    final rating = widget.rating;

    return _ScreenShell(
      title: 'Rate Meal',
      onBack: widget.onBack,
      children: [
        const SizedBox(height: 2),
        Center(
          child: Text(
            'How was ${_mealTitle(_couponMeal)} at ${widget.messName}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CouponCloudApp.navy,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DropdownMock(
          const ['B', 'L', 'S', 'D'],
          selectedValue: _couponMeal,
          onChanged: _isSubmitting
              ? null
              : (value) => setState(() => _couponMeal = value ?? _couponMeal),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final active = index < rating;
            return IconButton(
              onPressed: _isSubmitting ? null : () => widget.onRate(index + 1),
              iconSize: 46,
              color: active ? CouponCloudApp.gold : const Color(0xFFCCCCCC),
              icon: const Icon(Icons.star_rounded),
            );
          }),
        ),
        const _FieldLabel('Tell us more (Optional)'),
        _InputField(
          'Was it too spicy? Not cooked well? Describe here...',
          controller: _descriptionController,
          maxLines: 4,
          enabled: !_isSubmitting,
        ),
      ],
      bottom: _PrimaryButton(
        label: _isSubmitting ? 'Submitting...' : 'Submit Review',
        onPressed: _isSubmitting ? null : _submitReview,
      ),
    );
  }

  String _mealTitle(String mealCode) {
    switch (mealCode.toUpperCase()) {
      case 'B':
        return 'Breakfast';
      case 'L':
        return 'Lunch';
      case 'S':
        return 'Snacks';
      case 'D':
        return 'Dinner';
      default:
        return mealCode;
    }
  }
}

class _ComplaintScreen extends StatefulWidget {
  const _ComplaintScreen({
    required this.onBack,
    required this.raisedBy,
    required this.mess,
    required this.onSubmitComplaint,
  });

  final VoidCallback onBack;
  final String raisedBy;
  final String mess;
  final _ComplaintAction onSubmitComplaint;

  @override
  State<_ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<_ComplaintScreen> {
  static const _complaintTypes = [
    'Hygiene Issue (Hair/Insect in food)',
    'Raw or Undercooked Food',
    'Stale Food',
    'Staff Behavior / Misconduct',
    'Utensils Unclean',
    'Other',
  ];
  String _selectedType = _complaintTypes.first;
  String _couponMeal = 'D';
  bool _isSubmitting = false;
  XFile? _photoFile;

  final _imagePicker = ImagePicker();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_isSubmitting) {
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted || file == null) {
        return;
      }
      setState(() => _photoFile = file);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open camera: $error')));
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final description = _descriptionController.text.trim();

    if (_photoFile == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo and description are required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await widget.onSubmitComplaint(
      _ComplaintInput(
        couponMeal: _couponMeal,
        complaintType: _selectedType,
        photoFile: _photoFile!,
        description: description,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.isSuccess) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully.')),
      );
      widget.onBack();
      return;
    }

    final details =
        result.error ?? 'HTTP ${result.statusCode} - ${result.body}';
    messenger.showSnackBar(SnackBar(content: Text('Submit failed: $details')));
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Raise Complaint',
      titleColor: Colors.red,
      onBack: widget.onBack,
      children: [
        const _FieldLabel('Raised by'),
        _InputField(widget.raisedBy, enabled: false),
        const SizedBox(height: 18),
        const _FieldLabel('Mess'),
        _InputField(widget.mess, enabled: false),
        const SizedBox(height: 18),
        const _FieldLabel('Coupon Meal'),
        _DropdownMock(
          const ['B', 'L', 'S', 'D'],
          selectedValue: _couponMeal,
          onChanged: _isSubmitting
              ? null
              : (value) => setState(() => _couponMeal = value ?? _couponMeal),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Complaint Type'),
        _DropdownMock(
          _complaintTypes,
          selectedValue: _selectedType,
          onChanged: _isSubmitting
              ? null
              : (value) =>
                    setState(() => _selectedType = value ?? _selectedType),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Photo (Required)'),
        _UploadBox(onTap: _isSubmitting ? null : _capturePhoto),
        const SizedBox(height: 8),
        Text(
          _photoFile == null
              ? 'No photo captured yet. Tap the box to open camera.'
              : 'Captured: ${_photoFile!.name.isEmpty ? 'complaint_photo.jpg' : _photoFile!.name}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0x99011627),
          ),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Describe the Issue'),
        _InputField(
          'Please provide specific details...',
          controller: _descriptionController,
          maxLines: 5,
          enabled: !_isSubmitting,
        ),
      ],
      bottom: _DangerButton(
        label: _isSubmitting
            ? 'Submitting Complaint...'
            : 'Submit Official Complaint',
        onPressed: _isSubmitting ? null : _submit,
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen({
    required this.studentId,
    required this.onBack,
    required this.onLogout,
  });

  final String? studentId;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  final _studentApi = const _StudentApi();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final studentId = widget.studentId;
    if (studentId == null || studentId.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Student ID is not available. Please login again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await _studentApi.fetchStudentDetails(studentId);
      if (!mounted) {
        return;
      }
      setState(() {
        _details = details;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final name =
        _readProfileValue(details, const [
          'name',
          'student_name',
          'full_name',
        ]) ??
        'Student';
    final role = _readProfileValue(details, const ['role']) ?? 'student';
    final studentId =
        _readProfileValue(details, const ['student_id', 'studentId']) ??
        widget.studentId ??
        '-';
    final messName =
        _readProfileValue(details, const [
          'mess_name',
          'messName',
          'hostel_name',
        ]) ??
        'Mess';
    final hostelId =
        _readProfileValue(details, const ['hostel_id', 'hostelId']) ?? '-';

    return _ScreenShell(
      title: 'My Profile',
      onBack: widget.onBack,
      children: [
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [CouponCloudApp.orange, CouponCloudApp.gold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(255, 140, 0, 0.18),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: CouponCloudApp.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Color(0x99011627),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _summaryItem('Student ID', studentId),
                    _summaryItem('Hostel', hostelId),
                    _summaryItem('Mess', messName),
                  ],
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 14),
                  const Center(
                    child: CircularProgressIndicator(
                      color: CouponCloudApp.orange,
                    ),
                  ),
                ] else if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Could not refresh profile details.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CouponCloudApp.navy.withOpacity(0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      bottom: _DangerButton(label: 'Logout', onPressed: widget.onLogout),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14011627)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Color(0x99011627),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: CouponCloudApp.navy,
            ),
          ),
        ],
      ),
    );
  }

  String? _readProfileValue(Map<String, dynamic>? details, List<String> keys) {
    if (details == null) {
      return null;
    }

    for (final key in keys) {
      final value = details[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty && text != 'null') {
          return text;
        }
      }
    }

    return null;
  }
}

class _ScreenShell extends StatelessWidget {
  const _ScreenShell({
    required this.title,
    required this.onBack,
    required this.children,
    required this.bottom,
    this.topWidgets = const [],
    this.titleColor,
  });
  final String title;
  final Color? titleColor;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget bottom;
  final List<Widget> topWidgets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: Color(0x80011627),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: titleColor ?? CouponCloudApp.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...topWidgets,
          ...children,
          const SizedBox(height: 18),
          bottom,
        ],
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.10),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'logo.png',
                width: 88,
                height: 88,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'CouponCloud',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: CouponCloudApp.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Your mess, your rules.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0x80011627),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.studentName,
    required this.messName,
    required this.onExchangeTap,
    required this.onAvatarTap,
  });
  final String studentName;
  final String messName;
  final VoidCallback onExchangeTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $studentName',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: CouponCloudApp.navy,
                ),
              ),
              const SizedBox(height: 6),
              _HostelTag(messName: messName),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.mail_outline_rounded,
          onTap: onExchangeTap,
        ),
        const SizedBox(width: 8),
        GestureDetector(onTap: onAvatarTap, child: const _AvatarCircle()),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x14011627), width: 1.5),
        ),
        child: Icon(icon, color: CouponCloudApp.orange, size: 20),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [CouponCloudApp.orange, CouponCloudApp.gold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: CouponCloudApp.orange, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.10),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'SG',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _HostelTag extends StatelessWidget {
  const _HostelTag({required this.messName});

  final String messName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFF8C00),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FF8C00)),
      ),
      child: Text(
        messName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: CouponCloudApp.orange,
        ),
      ),
    );
  }
}

class _QrCard extends StatefulWidget {
  const _QrCard({required this.onRequestExchange});

  final _CouponExchangeAction onRequestExchange;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  int _selectedMeal = 2;

  static const _mealLabels = ['B', 'L', 'S', 'D'];

  final _couponApi = const _CouponApi();
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentCouponId;
  String? _currentCouponHostelId;
  DateTime? _currentCouponStart;
  DateTime? _currentCouponEnd;
  String? _qrImageUrl;
  Uint8List? _qrBytes;
  Timer? _validityTicker;

  @override
  void initState() {
    super.initState();
    _validityTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _currentCouponEnd != null) {
        setState(() {});
      }
    });
    unawaited(_refreshQrForSelectedMeal());
  }

  @override
  void dispose() {
    _validityTicker?.cancel();
    super.dispose();
  }

  void _selectMeal(int index) {
    if (_selectedMeal == index) {
      return;
    }
    setState(() => _selectedMeal = index);
    unawaited(_refreshQrForSelectedMeal());
  }

  Future<void> _openExchangeRequestDialog() async {
    final couponId = _currentCouponId;
    if (couponId == null || couponId.trim().isEmpty) {
      return;
    }

    final studentIdController = TextEditingController();

    try {
      final requestedToStudentId = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Request coupon exchange'),
            content: TextField(
              controller: studentIdController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                hintText: 'Enter recipient student ID',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final entered = studentIdController.text.trim();
                  if (entered.isEmpty) {
                    return;
                  }
                  Navigator.of(context).pop(entered);
                },
                child: const Text('Send'),
              ),
            ],
          );
        },
      );

      final recipient = requestedToStudentId?.trim();
      if (recipient == null || recipient.isEmpty) {
        return;
      }

      final result = await widget.onRequestExchange(
        _CouponExchangeRequestInput(
          couponId: couponId,
          requestedToStudentId: recipient,
          message:
              'Please take this ${_mealLabels[_selectedMeal].toLowerCase()} coupon.',
        ),
      );

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      if (result.isSuccess) {
        unawaited(_DailyCache.clearQrBytes(couponId));
        unawaited(_refreshQrForSelectedMeal());
        messenger.showSnackBar(
          const SnackBar(content: Text('Exchange request sent.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.error ?? 'Request failed: HTTP ${result.statusCode}',
            ),
          ),
        );
      }
    } finally {
      studentIdController.dispose();
    }
  }

  Future<void> _refreshQrForSelectedMeal() async {
    final selectedLabel = _mealLabels[_selectedMeal];

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final coupons = await _couponApi.fetchCoupons();
      final coupon = _findCouponForMeal(coupons, selectedLabel);

      if (coupon == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _currentCouponId = null;
          _currentCouponHostelId = null;
          _currentCouponStart = null;
          _currentCouponEnd = null;
          _qrImageUrl = null;
          _qrBytes = null;
          _isLoading = false;
          _errorMessage = 'No coupon found for $selectedLabel.';
        });
        return;
      }

      final qrImageUrl = coupon.qrImageUrl?.trim();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentCouponId = coupon.couponId;
        _currentCouponHostelId = coupon.hostelId?.trim().isNotEmpty == true
            ? coupon.hostelId!.trim()
            : _extractHostelFromCouponId(coupon.couponId);
        _currentCouponStart = _parseCouponStart(coupon.couponDate);
        _currentCouponEnd = _parseCouponEnd(
          couponDate: coupon.couponDate,
          validTill: coupon.validTill,
        );
        _qrImageUrl = null;
        _qrBytes = null;
        _errorMessage = null;
      });

      final cachedQrBytes = await _DailyCache.loadQrBytes(coupon.couponId);
      if (cachedQrBytes != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _qrBytes = cachedQrBytes;
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      try {
        final qrBytes = await _couponApi.fetchCouponQrBytes(coupon.couponId);

        if (!mounted) {
          return;
        }

        setState(() {
          _qrBytes = qrBytes;
          _qrImageUrl = null;
          _isLoading = false;
          _errorMessage = null;
        });
        unawaited(_DailyCache.saveQrBytes(coupon.couponId, qrBytes));
      } catch (qrError) {
        if (!mounted) {
          return;
        }

        final hasFallbackUrl =
            qrImageUrl != null && qrImageUrl.isNotEmpty && qrImageUrl != 'null';

        setState(() {
          _qrBytes = null;
          _qrImageUrl = hasFallbackUrl ? qrImageUrl : null;
          _isLoading = false;
          _errorMessage = hasFallbackUrl ? null : qrError.toString();
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
        _currentCouponHostelId = null;
        _currentCouponStart = null;
        _currentCouponEnd = null;
        _qrImageUrl = null;
        _qrBytes = null;
      });
    }
  }

  DateTime? _parseCouponStart(String? couponDateRaw) {
    if (couponDateRaw == null || couponDateRaw.trim().isEmpty) {
      return null;
    }
    return _parseDateTimeLoose(couponDateRaw.trim());
  }

  DateTime? _parseCouponEnd({
    required String? couponDate,
    required String? validTill,
  }) {
    final validTillRaw = validTill?.trim();
    if (validTillRaw == null || validTillRaw.isEmpty) {
      return null;
    }

    final asDateTime = _parseDateTimeLoose(validTillRaw);
    if (asDateTime != null) {
      return asDateTime;
    }

    final day = couponDate?.trim();
    if (day == null || day.isEmpty) {
      return null;
    }

    final dayOnly = _extractDayPart(day);
    if (dayOnly == null) {
      return null;
    }

    final timeOnly = _normalizeTimePart(validTillRaw);
    if (timeOnly == null) {
      return null;
    }

    return DateTime.tryParse('${dayOnly}T$timeOnly');
  }

  DateTime? _parseDateTimeLoose(String input) {
    final parsed = DateTime.tryParse(input);
    if (parsed != null) {
      return parsed;
    }
    if (input.contains(' ')) {
      return DateTime.tryParse(input.replaceFirst(' ', 'T'));
    }
    return null;
  }

  String? _extractDayPart(String raw) {
    final asDate = DateTime.tryParse(raw);
    if (asDate != null) {
      return _formatDate(asDate);
    }
    final parts = raw.split(' ');
    if (parts.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(parts[0])) {
      return parts[0];
    }
    return null;
  }

  String _formatDate(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _normalizeTimePart(String raw) {
    final clean = raw.trim();
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(clean)) {
      return clean;
    }
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(clean)) {
      return '$clean:00';
    }
    return null;
  }

  String _validityLabel() {
    final start = _currentCouponStart;
    final end = _currentCouponEnd;
    if (start == null || end == null) {
      return 'Validity unavailable';
    }

    final now = DateTime.now();
    if (now.isBefore(start)) {
      final wait = start.difference(now);
      return 'Valid in ${_formatDuration(wait)}';
    }
    if (now.isAfter(end)) {
      return 'Expired';
    }

    final left = end.difference(now);
    return 'Valid ${_formatDuration(left)}';
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) {
      return '<1m';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) {
      return '${minutes}m';
    }
    return '${hours}h ${minutes}m';
  }

  String? _extractHostelFromCouponId(String couponId) {
    final parts = couponId.split('-');
    if (parts.length < 3) {
      return null;
    }

    final hostel = parts[1].trim();
    if (hostel.isEmpty) {
      return null;
    }

    return hostel;
  }

  _CouponRecord? _findCouponForMeal(List<_CouponRecord> coupons, String meal) {
    for (final coupon in coupons) {
      final couponMeal = coupon.meal?.toUpperCase();
      if (couponMeal == meal.toUpperCase()) {
        return coupon;
      }
    }

    for (final coupon in coupons) {
      final couponId = coupon.couponId.toUpperCase();
      if (couponId.endsWith('-${meal.toUpperCase()}')) {
        return coupon;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeLabel = _mealLabels[_selectedMeal];
    final displayHostel = (_currentCouponHostelId?.trim().isNotEmpty == true)
        ? _currentCouponHostelId!.trim()
        : (_currentCouponId != null
              ? _extractHostelFromCouponId(_currentCouponId!) ?? 'hostel'
              : 'hostel');
    final mealText = switch (_selectedMeal) {
      0 => 'breakfast',
      1 => 'lunch',
      2 => 'snacks',
      _ => 'dinner',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0D000000)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              _StatusBadge(
                label: _validityLabel(),
                icon: const _PulseDot(),
                backgroundColor: const Color(0x1AFF8C00),
                borderColor: const Color(0x33FF8C00),
                textColor: CouponCloudApp.orange,
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                label: displayHostel,
                icon: const Icon(
                  Icons.home_work_outlined,
                  size: 10,
                  color: CouponCloudApp.orange,
                ),
                backgroundColor: const Color(0x1AFF8C00),
                borderColor: const Color(0x33FF8C00),
                textColor: CouponCloudApp.orange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: 260,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x14011627)),
            ),
            child: Row(
              children: List.generate(_mealLabels.length, (index) {
                return _MealPill(
                  label: _mealLabels[index],
                  selected: _selectedMeal == index,
                  onTap: () => _selectMeal(index),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF6),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: CouponCloudApp.orange.withOpacity(0.45),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(255, 140, 0, 0.16),
                  blurRadius: 25,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x14011627)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.04),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: CouponCloudApp.orange,
                            ),
                          ),
                        )
                      : _qrImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _qrImageUrl!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: CouponCloudApp.orange,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  _errorMessage ?? 'QR unavailable',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: CouponCloudApp.navy,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : _qrBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _qrBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        )
                      : Center(
                          child: Text(
                            _errorMessage ?? 'QR unavailable',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CouponCloudApp.navy,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_currentCouponId != null) ...[
            Text(
              _currentCouponId!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0x99011627),
              ),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 4),
          _SecondaryButton(
            label: 'Request Exchange',
            onPressed: _isLoading || _currentCouponId == null
                ? null
                : _openExchangeRequestDialog,
          ),
          const SizedBox(height: 12),
          Text(
            'Scan code at $displayHostel gate to verify $mealText ($activeLabel).',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0x99011627),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Widget icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealPill extends StatelessWidget {
  const _MealPill({required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1AFF8C00) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected
                  ? CouponCloudApp.orange
                  : CouponCloudApp.navy.withOpacity(0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: CouponCloudApp.orange,
      shape: BoxShape.circle,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: Color(0x8011627),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: CouponCloudApp.orange, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: CouponCloudApp.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0D000000)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CouponCloudApp.orange, CouponCloudApp.gold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(255, 140, 0, 0.30),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x0D011627),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: CouponCloudApp.navy,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(239, 68, 68, 0.24),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}

class _DividerWithLabel extends StatelessWidget {
  const _DividerWithLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Container(height: 1, color: const Color(0x14011627))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0x4D011627),
            letterSpacing: 0.5,
          ),
        ),
      ),
      Expanded(child: Container(height: 1, color: const Color(0x14011627))),
    ],
  );
}

class _InputField extends StatelessWidget {
  const _InputField(
    this.placeholder, {
    this.controller,
    this.obscureText = false,
    this.maxLines = 1,
    this.enabled = true,
  });
  final String placeholder;
  final TextEditingController? controller;
  final bool obscureText;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      style: const TextStyle(
        color: CouponCloudApp.navy,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(
          color: Color(0x80162711),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: CouponCloudApp.cream,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x14011627), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x14011627), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CouponCloudApp.orange, width: 2),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xB3011627),
      ),
    ),
  );
}

class _DropdownMock extends StatelessWidget {
  const _DropdownMock(
    this.values, {
    required this.selectedValue,
    this.onChanged,
  });
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14011627), width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0x80011627),
          ),
          style: const TextStyle(
            color: CouponCloudApp.navy,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: values
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MealToggle extends StatelessWidget {
  const _MealToggle({required this.selectedMeal, required this.onChanged});
  final int selectedMeal;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onChanged(0),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selectedMeal == 0
                    ? const Color(0x1AFF8C00)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedMeal == 0
                      ? const Color(0x33FF8C00)
                      : const Color(0x14011627),
                  width: 2,
                ),
              ),
              child: Text(
                'Lunch',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selectedMeal == 0
                      ? FontWeight.w800
                      : FontWeight.w700,
                  color: selectedMeal == 0
                      ? CouponCloudApp.orange
                      : const Color(0x80011627),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => onChanged(1),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selectedMeal == 1
                    ? const Color(0x1AFF8C00)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedMeal == 1
                      ? const Color(0x33FF8C00)
                      : const Color(0x14011627),
                  width: 2,
                ),
              ),
              child: Text(
                'Dinner',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selectedMeal == 1
                      ? FontWeight.w800
                      : FontWeight.w700,
                  color: selectedMeal == 1
                      ? CouponCloudApp.orange
                      : const Color(0x80011627),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard(this.amount);
  final String amount;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Amount:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: CouponCloudApp.navy,
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: CouponCloudApp.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSelector extends StatelessWidget {
  const _MenuSelector({
    required this.hostels,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<String> hostels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(hostels.length, (index) {
            return _Chip(
              label: hostels[index],
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
            );
          }),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? CouponCloudApp.navy : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? CouponCloudApp.navy : const Color(0x14011627),
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(1, 22, 39, 0.18),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected
                  ? Colors.white
                  : CouponCloudApp.navy.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.items,
    this.titleColor,
    this.muted = false,
  });
  final String title;
  final List<String> items;
  final Color? titleColor;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.7 : 1,
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: titleColor == null
                          ? const Color(0x14011627)
                          : const Color(0x33FF8C00),
                    ),
                  ),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: titleColor ?? CouponCloudApp.navy,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: titleColor ?? const Color(0x66011627),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
                          color: CouponCloudApp.navy.withOpacity(
                            muted ? 0.85 : 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: const Border(
        left: BorderSide(color: CouponCloudApp.orange, width: 4),
      ),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: CouponCloudApp.navy,
      ),
    ),
  );
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x4D011627), width: 2),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.file_upload_outlined,
              size: 34,
              color: Color(0x80011627),
            ),
            SizedBox(height: 8),
            Text(
              'Tap to upload photo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0x99011627),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DishFeedbackRow extends StatelessWidget {
  const _DishFeedbackRow(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => _GlassCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CouponCloudApp.navy,
            ),
          ),
          const Text(
            'Thumbs up / down',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CouponCloudApp.orange,
            ),
          ),
        ],
      ),
    ),
  );
}
