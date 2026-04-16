part of 'main.dart';

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
  bool _isLoadingHostels = true;
  String? _hostelLoadError;
  List<_MessOption> _hostelOptions = const [];
  String? _selectedHostelId;

  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupStudentIdController = TextEditingController();
  final _signupStaffIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadHostels());
  }

  @override
  void dispose() {
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupStudentIdController.dispose();
    _signupStaffIdController.dispose();
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
    final hostelId = _selectedHostelId?.trim() ?? '';

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

  Future<void> _loadHostels() async {
    try {
      final options = await _MessApi().fetchHostels();
      if (!mounted) {
        return;
      }

      setState(() {
        _hostelOptions = options;
        _selectedHostelId ??=
            options.isNotEmpty ? options.first.hostelId : null;
        _isLoadingHostels = false;
        _hostelLoadError = options.isEmpty ? 'No hostels found.' : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingHostels = false;
        _hostelLoadError = error.toString();
      });
    }
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
          const _FieldLabel('Hostel'),
          _isLoadingHostels
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: CouponCloudApp.orange,
                    ),
                  ),
                )
              : _HostelDropdown(
                  options: _hostelOptions,
                  selectedHostelId: _selectedHostelId,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _selectedHostelId = value),
                ),
          if (_hostelLoadError != null) ...[
            const SizedBox(height: 8),
            Text(
              _hostelLoadError!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xB3EF4444),
              ),
            ),
          ],
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

class _MessApi {
  _MessApi();

  static final Uri _messesUri = AppEnv.uri('/mess');

  Future<List<_MessOption>> fetchHostels() async {
    final results = <String, _MessOption>{};
    final options = await _fetchHostelsFromUri(_messesUri);
    for (final option in options) {
      results[option.hostelId] = option;
    }

    return results.values.toList()..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<List<_MessOption>> _fetchHostelsFromUri(Uri uri) async {
    final response = await ApiRequestPolicy.runGetWithRetry(
      () => _ApiHttp.client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final items = <dynamic>[];
    if (decoded is List) {
      items.addAll(decoded);
    } else if (decoded is Map<String, dynamic>) {
      for (final key in ['results', 'data', 'messes']) {
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

    return items.map(_parseMessOption).whereType<_MessOption>().toList();
  }

  _MessOption? _parseMessOption(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final hostelId = _asText(raw, const ['hostel_id', 'hostelId', 'id']);
    if (hostelId == null || hostelId.isEmpty) {
      return null;
    }

    final name = _asText(raw, const ['name', 'mess_name', 'messName']);
    return _MessOption(
      hostelId: hostelId,
      label: name == null || name.isEmpty ? hostelId : '$hostelId - $name',
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

class _MessOption {
  const _MessOption({required this.hostelId, required this.label});

  final String hostelId;
  final String label;
}

class _HostelDropdown extends StatelessWidget {
  const _HostelDropdown({
    required this.options,
    required this.selectedHostelId,
    required this.onChanged,
  });

  final List<_MessOption> options;
  final String? selectedHostelId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = selectedHostelId != null &&
            options.any((option) => option.hostelId == selectedHostelId)
        ? selectedHostelId
        : (options.isNotEmpty ? options.first.hostelId : null);

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
          value: effectiveValue,
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
          hint: const Text('Select hostel'),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.hostelId,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

