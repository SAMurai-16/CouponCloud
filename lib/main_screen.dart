part of 'main.dart';

class CouponCloudHome extends StatefulWidget {
  const CouponCloudHome({super.key});

  @override
  State<CouponCloudHome> createState() => _CouponCloudHomeState();
}

class _CouponCloudHomeState extends State<CouponCloudHome> {
  final _navigatorKey = GlobalKey<NavigatorState>();
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

  Future<bool> _handleSystemBack() async {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    return !_isLoggedIn;
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
      case AppRoutes.hostelComplaints:
        return _buildPageRoute(AppRoutes.hostelComplaints, _buildHostelComplaintsScreen);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup successful!')),
        );
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
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
      messenger.showSnackBar(
        SnackBar(content: Text('$actionName successful.')),
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

  Widget _buildHostelComplaintsScreen(BuildContext context) {
    return _HostelComplaintsPage(
      defaultHostelId: _hostelId,
      onBack: () {
        final navigator = _navigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }
        Navigator.of(context).pop();
      },
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
      body: WillPopScope(
        onWillPop: _handleSystemBack,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Navigator(
                key: _navigatorKey,
                initialRoute: _isLoggedIn ? AppRoutes.home : AppRoutes.login,
                onGenerateRoute: _buildRoute,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
