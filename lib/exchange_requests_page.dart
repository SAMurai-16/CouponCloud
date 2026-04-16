import 'dart:async';
import 'dart:convert';

import 'api_http.dart';
import 'api_request_policy.dart';
import 'app_env.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const Color _cream = Color(0xFFFFFBF6);
const Color _navy = Color(0xFF011627);
const Color _orange = Color(0xFFFF8C00);
const Color _gold = Color(0xFFFFB703);
const Color _danger = Color(0xFFEF4444);
const Color _success = Color(0xFF16A34A);

class CouponExchangeRequestsPage extends StatefulWidget {
  const CouponExchangeRequestsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CouponExchangeRequestsPage> createState() =>
      _CouponExchangeRequestsPageState();
}

class _CouponExchangeRequestsPageState extends State<CouponExchangeRequestsPage> {
  final _exchangeApi = const _CouponExchangeApi();
  bool _isLoading = true;
  bool _isActioning = false;
  String? _error;
  List<_ExchangeRequestRecord> _requests = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadRequests());
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final requests = await _exchangeApi.fetchExchangeRequests();
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests;
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

  Future<void> _handleAction(
    _ExchangeRequestRecord request,
    Future<_ApiResult> Function(String exchangeId) action,
    String successMessage,
  ) async {
    if (_isActioning) {
      return;
    }

    setState(() => _isActioning = true);
    final result = await action(request.exchangeId);
    if (!mounted) {
      return;
    }

    setState(() => _isActioning = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.isSuccess) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      await _loadRequests();
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.error ?? 'Request failed: HTTP ${result.statusCode}',
        ),
      ),
    );
  }

  String _statusLabel(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    if (value.isEmpty) {
      return 'pending';
    }
    return value;
  }

  Color _statusColor(String? status) {
    final value = _statusLabel(status);
    if (value == 'accepted' || value == 'approved') {
      return _success;
    }
    if (value == 'rejected' || value == 'declined') {
      return _danger;
    }
    return _orange;
  }

  String _mealLabel(String? meal) {
    final value = (meal ?? '').trim().toUpperCase();
    switch (value) {
      case 'B':
        return 'Breakfast';
      case 'L':
        return 'Lunch';
      case 'S':
        return 'Snacks';
      case 'D':
        return 'Dinner';
      default:
        return meal?.trim().isNotEmpty == true ? meal!.trim() : 'Coupon';
    }
  }

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
                onTap: widget.onBack,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: Color(0x80011627),
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Exchange Requests',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: CircularProgressIndicator(color: _orange),
              ),
            )
          else if (_error != null)
            _NoteCard('Could not load exchange requests: $_error')
          else if (_requests.isEmpty)
            const _NoteCard('No exchange requests found.')
          else
            ..._requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _mealLabel(request.couponMeal),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Coupon: ${request.couponId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0x99011627),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'To: ${request.requestedToStudentId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0x99011627),
                                    ),
                                  ),
                                  if ((request.requestedByName ?? '').trim().isNotEmpty ||
                                      (request.requestedByStudentId ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'From: ${request.requestedByName?.trim().isNotEmpty == true ? request.requestedByName!.trim() : request.requestedByStudentId!.trim()}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0x99011627),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _StatusPill(
                              label: _statusLabel(request.status).toUpperCase(),
                              color: _statusColor(request.status),
                            ),
                          ],
                        ),
                        if (request.message.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            request.message,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _navy,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Reject',
                                icon: Icons.close_rounded,
                                backgroundColor: const Color(0xFFFEE2E2),
                                foregroundColor: _danger,
                                onPressed: _isActioning || !request.isPending
                                    ? null
                                    : () => _handleAction(
                                          request,
                                          _exchangeApi.rejectExchangeRequest,
                                          'Exchange request rejected.',
                                        ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionButton(
                                label: 'Accept',
                                icon: Icons.check_rounded,
                                backgroundColor: const Color(0xFFDCFCE7),
                                foregroundColor: _success,
                                onPressed: _isActioning || !request.isPending
                                    ? null
                                    : () => _handleAction(
                                          request,
                                          _exchangeApi.acceptExchangeRequest,
                                          'Exchange request accepted.',
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          _SecondaryButton(label: 'Refresh', onPressed: _loadRequests),
        ],
      ),
    );
  }
}

class _CouponExchangeApi {
  const _CouponExchangeApi();

  static final Uri _exchangeRequestsUri = AppEnv.uri(
    '/coupon-exchange-requests/',
  );

  Future<List<_ExchangeRequestRecord>> fetchExchangeRequests() async {
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

  Future<_ApiResult> acceptExchangeRequest(String exchangeId) {
    return _postEmpty(
      AppEnv.uri('/coupon-exchange-requests/$exchangeId/accept/'),
    );
  }

  Future<_ApiResult> rejectExchangeRequest(String exchangeId) {
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

      final streamed = await ApiHttp.client.send(request)
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

  List<_ExchangeRequestRecord> _parseRequestList(dynamic decoded) {
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
        .whereType<_ExchangeRequestRecord>()
        .toList();
  }

  _ExchangeRequestRecord? _parseRequestRecord(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final coupon = _asMap(raw['coupon']);
    final requestedBy = _asMap(raw['requested_by']);
    final requestedTo = _asMap(raw['requested_to']);

    final exchangeId = _asText(raw, const ['exchange_id', 'id', 'request_id']);
    final couponId =
        _asText(raw, const ['coupon_id', 'couponId']) ??
        _asText(coupon, const ['coupon_id', 'couponId']);
    final requestedToStudentId = _asText(
      raw,
      const ['requested_to_student_id', 'requestedToStudentId'],
    ) ??
    _asText(requestedTo, const ['student_id', 'studentId']);
    final message = _asText(raw, const ['message', 'note']) ?? '';

    if (exchangeId == null || couponId == null || requestedToStudentId == null) {
      return null;
    }

    return _ExchangeRequestRecord(
      exchangeId: exchangeId,
      couponId: couponId,
      requestedToStudentId: requestedToStudentId,
      message: message,
      status: _asText(raw, const ['status']),
      requestedByStudentId: _asText(
        raw,
        const ['requested_by_student_id', 'requestedByStudentId'],
      ) ??
      _asText(requestedBy, const ['student_id', 'studentId']),
      requestedByName: _asText(
        raw,
        const ['requested_by_name', 'requestedByName'],
      ) ??
      _asText(requestedBy, const ['name']),
      couponMeal:
          _asText(raw, const ['coupon_meal', 'couponMeal']) ??
          _asText(coupon, const ['coupon_meal', 'couponMeal']),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return const {};
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

class _ExchangeRequestRecord {
  const _ExchangeRequestRecord({
    required this.exchangeId,
    required this.couponId,
    required this.requestedToStudentId,
    required this.message,
    this.status,
    this.requestedByStudentId,
    this.requestedByName,
    this.couponMeal,
  });

  final String exchangeId;
  final String couponId;
  final String requestedToStudentId;
  final String message;
  final String? status;
  final String? requestedByStudentId;
  final String? requestedByName;
  final String? couponMeal;

  bool get isPending {
    final value = (status ?? '').trim().toLowerCase();
    return value.isEmpty || value == 'pending';
  }
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x0D011627),
          borderRadius: BorderRadius.circular(18),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: _navy,
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
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: _orange, width: 4),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: _navy,
        ),
      ),
    );
  }
}
