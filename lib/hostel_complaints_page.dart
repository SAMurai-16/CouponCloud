part of 'main.dart';

class _HostelComplaintsPage extends StatefulWidget {
  const _HostelComplaintsPage({
    required this.onBack,
    this.defaultHostelId,
  });

  final VoidCallback onBack;
  final String? defaultHostelId;

  @override
  State<_HostelComplaintsPage> createState() => _HostelComplaintsPageState();
}

class _HostelComplaintsPageState extends State<_HostelComplaintsPage> {
  final _hostelIdController = TextEditingController();
  final _complaintsApi = _HostelComplaintsApi();
  bool _isLoading = false;
  String? _error;
  List<_HostelComplaintRecord> _complaints = const [];

  @override
  void initState() {
    super.initState();
    _hostelIdController.text = widget.defaultHostelId?.trim() ?? '';
    if (_hostelIdController.text.trim().isNotEmpty) {
      unawaited(_loadComplaints());
    }
  }

  @override
  void dispose() {
    _hostelIdController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    final hostelId = _hostelIdController.text.trim();
    if (hostelId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please enter a hostel ID.';
        _complaints = const [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final complaints = await _complaintsApi.fetchComplaints(hostelId);
      if (!mounted) {
        return;
      }

      setState(() {
        _complaints = complaints;
        _isLoading = false;
        _error = complaints.isEmpty
            ? 'No complaints found for hostel $hostelId.'
            : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error.toString();
        _complaints = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onBack();
        }
      },
      child: _ScreenShell(
        title: 'Hostel Complaints',
        onBack: widget.onBack,
        children: [
          const _NoteCard(
            'Use a hostel ID like H1, H2, or GH to see complaints raised for that hostel.',
          ),
          const SizedBox(height: 18),
          const _FieldLabel('Hostel ID'),
          _InputField(
            'Enter hostel id',
            controller: _hostelIdController,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            label: _isLoading ? 'Loading...' : 'Load Complaints',
            onPressed: _isLoading ? null : _loadComplaints,
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: CouponCloudApp.orange),
            )
          else if (_error != null)
            _NoteCard(_error!)
          else
            ..._complaints.map(_buildComplaintCard),
        ],
        bottom: _SecondaryButton(
          label: 'Refresh',
          onPressed: _isLoading ? null : _loadComplaints,
        ),
      ),
    );
  }

  Widget _buildComplaintCard(_HostelComplaintRecord complaint) {
    final createdAt = complaint.createdAt == null
        ? null
        : _formatDateTime(complaint.createdAt!);

    return Padding(
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
                          complaint.complaintType.isNotEmpty
                              ? complaint.complaintType
                              : 'Complaint',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: CouponCloudApp.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hostel: ${complaint.hostelId.isNotEmpty ? complaint.hostelId : '-'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0x99011627),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Meal: ${_mealLabel(complaint.couponMeal)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0x99011627),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ComplaintStatusPill(label: complaint.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Raised by: ${complaint.raisedByName ?? complaint.raisedById ?? '-'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CouponCloudApp.navy,
                ),
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  createdAt,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0x99011627),
                  ),
                ),
              ],
              if (complaint.description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  complaint.description.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: CouponCloudApp.navy,
                  ),
                ),
              ],
              if (complaint.photoSource?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _ComplaintPhotoView(source: complaint.photoSource!.trim()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _mealLabel(String meal) {
    switch (meal.trim().toUpperCase()) {
      case 'B':
        return 'Breakfast';
      case 'L':
        return 'Lunch';
      case 'S':
        return 'Snacks';
      case 'D':
        return 'Dinner';
      default:
        return meal.isEmpty ? '-' : meal;
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Raised on $y-$m-$d at $hh:$mm';
  }
}

class _HostelComplaintsApi {
  _HostelComplaintsApi();

  static final Uri _complaintsUri = AppEnv.uri('/complaints/');
  static final http.Client _client = http_client_factory.createHttpClient();

  Future<List<_HostelComplaintRecord>> fetchComplaints(String hostelId) async {
    final uri = _complaintsUri.replace(
      queryParameters: {'hostel_id': hostelId},
    );

    final response = await ApiRequestPolicy.runGetWithRetry(
      () => _client.get(uri, headers: const {'Accept': 'application/json'}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Complaints request failed with HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return _parseComplaintList(decoded);
  }

  List<_HostelComplaintRecord> _parseComplaintList(dynamic decoded) {
    final items = <dynamic>[];
    if (decoded is List) {
      items.addAll(decoded);
    } else if (decoded is Map<String, dynamic>) {
      for (final key in ['results', 'data', 'complaints']) {
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
        .map(_parseComplaintRecord)
        .whereType<_HostelComplaintRecord>()
        .toList();
  }

  _HostelComplaintRecord? _parseComplaintRecord(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final raisedBy = _asMap(
      raw['raised_by'] ?? raw['raisedBy'] ?? raw['user'],
    );
    final hostel = _asMap(raw['hostel'] ?? raw['mess']);

    final complaintId = _asText(raw, const [
      'complaint_id',
      'complaintId',
      'id',
      'request_id',
    ]);
    final hostelId = _asText(raw, const ['hostel_id', 'hostelId']) ??
        _asText(hostel, const ['hostel_id', 'hostelId']);

    return _HostelComplaintRecord(
      complaintId: complaintId ?? '',
      hostelId: hostelId ?? '',
      raisedById: _asText(raw, const ['raised_by_id', 'raisedById']) ??
          _asText(raisedBy, const ['student_id', 'studentId', 'user_id']),
      raisedByName: _asText(raw, const ['raised_by_name', 'raisedByName']) ??
          _asText(raisedBy, const ['name', 'full_name']),
      couponMeal: _asText(raw, const ['coupon_meal', 'couponMeal']) ?? '',
      complaintType:
          _asText(raw, const ['complaint_type', 'complaintType', 'type']) ??
          '',
      description: _asText(raw, const ['description', 'details']) ?? '',
      photoSource: _asText(raw, const [
        'photo',
        'photo_url',
        'photoUrl',
        'image',
        'image_url',
        'imageUrl',
        'photo_image_url',
      ]),
      status: _asText(raw, const ['status']) ?? 'pending',
      createdAt: _parseDateTime(
        _asText(raw, const [
          'created_at',
          'createdAt',
          'complaint_date',
          'raised_at',
        ]),
      ),
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

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) {
      return parsed;
    }

    if (value.contains(' ')) {
      return DateTime.tryParse(value.trim().replaceFirst(' ', 'T'));
    }

    return null;
  }
}

class _HostelComplaintRecord {
  const _HostelComplaintRecord({
    required this.complaintId,
    required this.hostelId,
    required this.raisedById,
    required this.raisedByName,
    required this.couponMeal,
    required this.complaintType,
    required this.description,
    required this.photoSource,
    required this.status,
    required this.createdAt,
  });

  final String complaintId;
  final String hostelId;
  final String? raisedById;
  final String? raisedByName;
  final String couponMeal;
  final String complaintType;
  final String description;
  final String? photoSource;
  final String status;
  final DateTime? createdAt;
}

class _ComplaintPhotoView extends StatefulWidget {
  const _ComplaintPhotoView({required this.source});

  final String source;

  @override
  State<_ComplaintPhotoView> createState() => _ComplaintPhotoViewState();
}

class _ComplaintPhotoViewState extends State<_ComplaintPhotoView> {
  Future<_ComplaintPhotoData?>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _resolveComplaintPhotoData(widget.source);
  }

  @override
  void didUpdateWidget(covariant _ComplaintPhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _dataFuture = _resolveComplaintPhotoData(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ComplaintPhotoData?>(
      future: _dataFuture ??= _resolveComplaintPhotoData(widget.source),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(color: CouponCloudApp.orange),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Text(
            'Complaint image unavailable.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0x99011627),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: data.kind == _ComplaintPhotoKind.network
                ? Image.network(
                    data.source,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          'Could not display complaint image.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0x99011627),
                          ),
                        ),
                      );
                    },
                  )
                : Image.memory(
                    data.bytes!,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          'Could not display complaint image.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0x99011627),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<_ComplaintPhotoData?> _resolveComplaintPhotoData(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final dataUriBody = _stripDataUriPrefix(normalized);
    if (dataUriBody != null) {
      try {
        return _ComplaintPhotoData.bytes(base64Decode(dataUriBody));
      } catch (_) {
        return null;
      }
    }

    if (normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('/')) {
      if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
        return _ComplaintPhotoData.network(normalized);
      }

      try {
        final uri = AppEnv.apiBaseUri.resolve(normalized);
        final response = await ApiRequestPolicy.runGetWithRetry(
          () => http_client_factory.createHttpClient().get(uri),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        return _ComplaintPhotoData.bytes(response.bodyBytes);
      } catch (_) {
        return null;
      }
    }

    try {
      return _ComplaintPhotoData.bytes(base64Decode(normalized));
    } catch (_) {
      return null;
    }
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

enum _ComplaintPhotoKind { network, bytes }

class _ComplaintPhotoData {
  const _ComplaintPhotoData._(this.kind, this.source, this.bytes);

  factory _ComplaintPhotoData.network(String source) {
    return _ComplaintPhotoData._(_ComplaintPhotoKind.network, source, null);
  }

  factory _ComplaintPhotoData.bytes(Uint8List bytes) {
    return _ComplaintPhotoData._(_ComplaintPhotoKind.bytes, '', bytes);
  }

  final _ComplaintPhotoKind kind;
  final String source;
  final Uint8List? bytes;
}

class _ComplaintStatusPill extends StatelessWidget {
  const _ComplaintStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final value = label.trim().toLowerCase();
    final color = switch (value) {
      'resolved' || 'closed' || 'done' => const Color(0xFF16A34A),
      'rejected' || 'declined' => const Color(0xFFEF4444),
      _ => CouponCloudApp.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        value.isEmpty ? 'PENDING' : value.toUpperCase(),
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
