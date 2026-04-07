import 'package:flutter/material.dart';

void main() => runApp(const CouponCloudApp());

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

enum AppScreen { login, main, swap, guest, menus, rate, complaint }

class CouponCloudHome extends StatefulWidget {
  const CouponCloudHome({super.key});

  @override
  State<CouponCloudHome> createState() => _CouponCloudHomeState();
}

class _CouponCloudHomeState extends State<CouponCloudHome> {
  AppScreen _screen = AppScreen.login;
  int _rating = 0;

  void _go(AppScreen screen) => setState(() => _screen = screen);
  void _rate(int value) => setState(() => _rating = value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouponCloudApp.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(begin: const Offset(0.10, 0), end: Offset.zero).animate(animation);
                return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
              },
              child: SingleChildScrollView(
                key: ValueKey(_screen),
                child: switch (_screen) {
                  AppScreen.login => _LoginScreen(onContinue: () => _go(AppScreen.main)),
                  AppScreen.main => _MainScreen(onScreen: _go),
                  AppScreen.swap => _SwapScreen(onBack: () => _go(AppScreen.main)),
                  AppScreen.guest => _GuestScreen(onBack: () => _go(AppScreen.main)),
                  AppScreen.menus => _MenusScreen(onBack: () => _go(AppScreen.main)),
                  AppScreen.rate => _RateScreen(onBack: () => _go(AppScreen.main), onRate: _rate, rating: _rating),
                  AppScreen.complaint => _ComplaintScreen(onBack: () => _go(AppScreen.main)),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const _LogoBlock(),
          const SizedBox(height: 42),
          _PrimaryButton(label: 'Continue with Institute Email', onPressed: onContinue),
          const SizedBox(height: 18),
          const Text('Verification required. For student use only.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0x80011627))),
          const SizedBox(height: 18),
          const _DividerWithLabel('OR USE ROLL NUMBER'),
          const SizedBox(height: 18),
          const _InputField('Roll Number (e.g., 2023IMG-047)'),
          const SizedBox(height: 14),
          const _InputField('OTP / Password', obscureText: true),
          const SizedBox(height: 18),
          _SecondaryButton(label: 'Login', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _MainScreen extends StatelessWidget {
  const _MainScreen({required this.onScreen});
  final ValueChanged<AppScreen> onScreen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _Header(onAvatarTap: () => onScreen(AppScreen.login)),
          const SizedBox(height: 18),
          const _QrCard(),
          const SizedBox(height: 22),
          const _SectionLabel('Quick Actions'),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            children: [
              _ActionTile(icon: Icons.swap_horiz, label: 'Swap\nMeal', onTap: () => onScreen(AppScreen.swap)),
              _ActionTile(icon: Icons.person_add_alt_1, label: 'Guest\nPass', onTap: () => onScreen(AppScreen.guest)),
              _ActionTile(icon: Icons.restaurant_menu, label: 'View\nMenus', onTap: () => onScreen(AppScreen.menus)),
              _ActionTile(icon: Icons.star, label: 'Rate\nMeal', onTap: () => onScreen(AppScreen.rate)),
            ],
          ),
          const SizedBox(height: 18),
          _DangerButton(label: 'Raise Official Hygiene Complaint', onPressed: () => onScreen(AppScreen.complaint)),
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
  static const _mealOptions = ['Today - Dinner (BH-1)', 'Tomorrow - Breakfast (BH-1)'];
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
          onChanged: (value) => setState(() => _selectedMeal = value ?? _selectedMeal),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Transfer to (Roll No.):'),
        _InputField('$_transferRoll (hardcoded for now)'),
        const SizedBox(height: 18),
        const _NoteCard('Note: Once swapped, your QR code for this meal will be deactivated and transferred.'),
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
      SnackBar(content: Text('Proceeding to UPI for $_selectedMess - $meal - Rs. 50')),
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
          onChanged: (value) => setState(() => _selectedMess = value ?? _selectedMess),
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
  static const _hostels = ['BH-1', 'BH-2', 'BH-3', 'GH'];
  int _selected = 0;

  static const _menus = <String, Map<String, List<String>>>{
    'BH-1': {
      'Dinner (8:00 PM - 10:00 PM)': ['Dal Makhani', 'Kadai Paneer', 'Jeera Rice', 'Butter Roti', 'Gulab Jamun'],
      'Snacks (5:30 PM - 6:30 PM)': ['Samosa (2 pcs)', 'Tea / Coffee'],
    },
    'BH-2': {
      'Dinner (8:00 PM - 10:00 PM)': ['Rajma Chawal', 'Aloo Gobi', 'Jeera Rice', 'Roti', 'Fruit Custard'],
      'Snacks (5:30 PM - 6:30 PM)': ['Bread Pakora', 'Tea / Coffee'],
    },
    'BH-3': {
      'Dinner (8:00 PM - 10:00 PM)': ['Chole Bhature', 'Mix Veg', 'Rice', 'Roti', 'Kheer'],
      'Snacks (5:30 PM - 6:30 PM)': ['Vegetable Sandwich', 'Tea / Coffee'],
    },
    'GH': {
      'Dinner (8:00 PM - 10:00 PM)': ['Paneer Butter Masala', 'Veg Pulao', 'Roti', 'Salad', 'Gulab Jamun'],
      'Snacks (5:30 PM - 6:30 PM)': ['Poha', 'Tea / Coffee'],
    },
  };

  @override
  Widget build(BuildContext context) {
    final hostel = _hostels[_selected];
    final menu = _menus[hostel]!;
    final entries = menu.entries.toList();
    return _ScreenShell(
      title: 'Today\'s Menus',
      onBack: widget.onBack,
      topWidgets: [
        _MenuSelector(
          hostels: _hostels,
          selectedIndex: _selected,
          onSelected: (index) => setState(() => _selected = index),
        ),
      ],
      children: [
        _MenuCard(title: entries[0].key, titleColor: CouponCloudApp.orange, items: entries[0].value),
        const SizedBox(height: 14),
        _MenuCard(title: entries[1].key, items: entries[1].value, muted: true),
      ],
      bottom: const SizedBox(height: 8),
    );
  }
}

class _RateScreen extends StatelessWidget {
  const _RateScreen({required this.onBack, required this.onRate, required this.rating});
  final VoidCallback onBack;
  final ValueChanged<int> onRate;
  final int rating;

  @override
  Widget build(BuildContext context) {
    void submitReview() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review submitted with ${rating == 0 ? 5 : rating} star(s).')),
      );
      onBack();
    }

    return _ScreenShell(
      title: 'Rate Meal',
      onBack: onBack,
      children: [
        const SizedBox(height: 2),
        const Center(child: Text('How was Dinner at BH-1?', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CouponCloudApp.navy))),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final active = index < rating;
            return IconButton(
              onPressed: () => onRate(index + 1),
              iconSize: 46,
              color: active ? CouponCloudApp.gold : const Color(0xFFCCCCCC),
              icon: const Icon(Icons.star_rounded),
            );
          }),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: rating > 0 && rating <= 3
              ? Column(
                  key: const ValueKey('feedback'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 6),
                    Text('Dish Feedback', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CouponCloudApp.navy)),
                    SizedBox(height: 10),
                    _DishFeedbackRow('Dal Makhani'),
                    SizedBox(height: 10),
                    _DishFeedbackRow('Kadai Paneer'),
                    SizedBox(height: 18),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('no-feedback')),
        ),
        const _FieldLabel('Tell us more (Optional)'),
        const _InputField('Was it too spicy? Not cooked well? Describe here...', maxLines: 4),
      ],
      bottom: _PrimaryButton(label: 'Submit Review', onPressed: submitReview),
    );
  }
}

class _ComplaintScreen extends StatefulWidget {
  const _ComplaintScreen({required this.onBack});
  final VoidCallback onBack;

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

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Complaint submitted: $_selectedType')),
    );
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenShell(
      title: 'Raise Complaint',
      titleColor: Colors.red,
      onBack: widget.onBack,
      children: [
        const _FieldLabel('Complaint Type'),
        _DropdownMock(
          _complaintTypes,
          selectedValue: _selectedType,
          onChanged: (value) => setState(() => _selectedType = value ?? _selectedType),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Upload Evidence (Required)'),
        _UploadBox(onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Using placeholder evidence image for now.')),
          );
        }),
        const SizedBox(height: 18),
        const _FieldLabel('Describe the Issue'),
        const _InputField('Please provide specific details...', maxLines: 5),
      ],
      bottom: _DangerButton(label: 'Submit Official Complaint', onPressed: _submit),
    );
  }
}

class _ScreenShell extends StatelessWidget {
  const _ScreenShell({required this.title, required this.onBack, required this.children, required this.bottom, this.topWidgets = const [], this.titleColor});
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
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0x80011627)),
                ),
              ),
              Expanded(child: Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: titleColor ?? CouponCloudApp.navy))),
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
      children: const [
        SizedBox(
          width: 110,
          height: 110,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(24)),
              boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.10), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Center(child: Icon(Icons.confirmation_number_rounded, size: 54, color: CouponCloudApp.orange)),
          ),
        ),
        SizedBox(height: 12),
        Text('CouponCloud', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: CouponCloudApp.navy)),
        SizedBox(height: 2),
        Text('Your mess, your rules.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0x80011627))),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAvatarTap});
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, Shashank', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CouponCloudApp.navy)),
              SizedBox(height: 6),
              _HostelTag(),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(onTap: onAvatarTap, child: const _AvatarCircle()),
      ],
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
        gradient: const LinearGradient(colors: [CouponCloudApp.orange, CouponCloudApp.gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: CouponCloudApp.orange, width: 2),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.10), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: const Center(child: Text('SG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
    );
  }
}
class _HostelTag extends StatelessWidget {
  const _HostelTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0x1AFF8C00), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x33FF8C00))),
      child: const Text('BH-1 Mess', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CouponCloudApp.orange)),
    );
  }
}

class _QrCard extends StatefulWidget {
  const _QrCard();

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  int _selectedMeal = 2;

  static const _mealLabels = ['B', 'L', 'S', 'D'];

  static const _patterns = <int, List<List<int>>>{
    0: [
      [1, 1, 1, 0, 0, 1, 0],
      [1, 0, 1, 0, 1, 1, 1],
      [1, 1, 1, 1, 0, 0, 1],
      [0, 0, 1, 1, 1, 0, 0],
      [1, 0, 0, 1, 0, 1, 1],
      [0, 1, 1, 0, 1, 0, 1],
      [1, 1, 0, 1, 1, 1, 0],
    ],
    1: [
      [1, 1, 0, 1, 0, 0, 1],
      [0, 1, 1, 0, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 0],
      [0, 1, 0, 1, 0, 1, 1],
      [1, 1, 0, 0, 1, 1, 0],
      [0, 0, 1, 1, 0, 1, 1],
      [1, 0, 1, 0, 1, 1, 0],
    ],
    2: [
      [1, 0, 1, 1, 0, 1, 0],
      [0, 1, 1, 0, 1, 1, 0],
      [1, 1, 0, 1, 0, 0, 1],
      [0, 1, 1, 1, 1, 0, 0],
      [1, 0, 0, 1, 1, 1, 1],
      [0, 1, 0, 1, 0, 1, 0],
      [1, 1, 1, 0, 1, 0, 1],
    ],
    3: [
      [1, 1, 1, 0, 1, 0, 1],
      [0, 1, 0, 1, 1, 1, 0],
      [1, 0, 1, 1, 0, 1, 1],
      [1, 1, 0, 0, 1, 0, 1],
      [0, 1, 1, 1, 0, 1, 0],
      [1, 0, 0, 1, 1, 0, 1],
      [0, 1, 1, 0, 1, 1, 0],
    ],
  };

  void _selectMeal(int index) {
    setState(() => _selectedMeal = index);
  }

  @override
  Widget build(BuildContext context) {
    final activeLabel = _mealLabels[_selectedMeal];
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
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0x1AFF8C00), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33FF8C00))),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulseDot(),
                  SizedBox(width: 6),
                  Text('Valid 1h 24m', style: TextStyle(color: CouponCloudApp.orange, fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
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
              border: Border.all(color: CouponCloudApp.orange.withOpacity(0.45), width: 2),
              boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 140, 0, 0.16), blurRadius: 25)],
            ),
            child: Center(
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x14011627)),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _QrPainter(pattern: _patterns[_selectedMeal]!),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Scan code at BH-1 gate to verify $mealText ($activeLabel).',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0x99011627)),
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
              color: selected ? CouponCloudApp.orange : CouponCloudApp.navy.withOpacity(0.35),
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
  Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: const BoxDecoration(color: CouponCloudApp.orange, shape: BoxShape.circle));
}

class _QrPainter extends StatelessWidget {
  const _QrPainter({required this.pattern});

  final List<List<int>> pattern;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final cell = size / 7;
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _FinderPainter())),
            for (var row = 0; row < pattern.length; row++)
              for (var col = 0; col < pattern[row].length; col++)
                if (pattern[row][col] == 1)
                  Positioned(
                    left: col * cell,
                    top: row * cell,
                    width: cell,
                    height: cell,
                    child: Container(
                      margin: EdgeInsets.all(cell * 0.08),
                      decoration: BoxDecoration(
                        color: row == 3 && col == 3 ? CouponCloudApp.orange : CouponCloudApp.navy,
                        borderRadius: BorderRadius.circular(cell * 0.16),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _FinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = CouponCloudApp.navy;
    final orangePaint = Paint()..color = CouponCloudApp.orange;

    void drawFinder(double dx, double dy) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(dx, dy, size.width * 0.22, size.height * 0.22), const Radius.circular(6)), paint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(dx + size.width * 0.035, dy + size.height * 0.035, size.width * 0.15, size.height * 0.15), const Radius.circular(4)), Paint()..color = Colors.white);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(dx + size.width * 0.07, dy + size.height * 0.07, size.width * 0.08, size.height * 0.08), const Radius.circular(3)), orangePaint);
    }

    drawFinder(0, 0);
    drawFinder(size.width * 0.78, 0);
    drawFinder(0, size.height * 0.78);

    final gridPaint = Paint()
      ..color = CouponCloudApp.navy.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final step = size.width / 7;
    for (var i = 1; i < 7; i++) {
      canvas.drawLine(Offset(step * i, 0), Offset(step * i, size.height), gridPaint);
      canvas.drawLine(Offset(0, step * i), Offset(size.width, step * i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: Color(0x8011627))),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: CouponCloudApp.orange, size: 24),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, height: 1.2, color: CouponCloudApp.navy)),
          ]),
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
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: Offset(0, 4))],
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
            gradient: const LinearGradient(colors: [CouponCloudApp.orange, CouponCloudApp.gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 140, 0, 0.30), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0x0D011627), borderRadius: BorderRadius.circular(18)),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: CouponCloudApp.navy, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
            gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(239, 68, 68, 0.24), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
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
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0x4D011627), letterSpacing: 0.5)),
          ),
          Expanded(child: Container(height: 1, color: const Color(0x14011627))),
        ],
      );
}

class _InputField extends StatelessWidget {
  const _InputField(this.placeholder, {this.obscureText = false, this.maxLines = 1});
  final String placeholder;
  final bool obscureText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      maxLines: maxLines,
      style: const TextStyle(color: CouponCloudApp.navy, fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(color: Color(0x80162711), fontSize: 13, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: CouponCloudApp.cream,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x14011627), width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x14011627), width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CouponCloudApp.orange, width: 2)),
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
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xB3011627))),
      );
}

class _DropdownMock extends StatelessWidget {
  const _DropdownMock(this.values, {required this.selectedValue, this.onChanged});
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
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0x80011627)),
          style: const TextStyle(color: CouponCloudApp.navy, fontSize: 13, fontWeight: FontWeight.w600),
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
                color: selectedMeal == 0 ? const Color(0x1AFF8C00) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedMeal == 0 ? const Color(0x33FF8C00) : const Color(0x14011627),
                  width: 2,
                ),
              ),
              child: Text(
                'Lunch',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selectedMeal == 0 ? FontWeight.w800 : FontWeight.w700,
                  color: selectedMeal == 0 ? CouponCloudApp.orange : const Color(0x80011627),
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
                color: selectedMeal == 1 ? const Color(0x1AFF8C00) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedMeal == 1 ? const Color(0x33FF8C00) : const Color(0x14011627),
                  width: 2,
                ),
              ),
              child: Text(
                'Dinner',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selectedMeal == 1 ? FontWeight.w800 : FontWeight.w700,
                  color: selectedMeal == 1 ? CouponCloudApp.orange : const Color(0x80011627),
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
            const Text('Total Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CouponCloudApp.navy)),
            Text(amount, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CouponCloudApp.orange)),
          ],
        ),
      ),
    );
  }
}

class _MenuSelector extends StatelessWidget {
  const _MenuSelector({required this.hostels, required this.selectedIndex, required this.onSelected});
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
            border: Border.all(color: selected ? CouponCloudApp.navy : const Color(0x14011627)),
            boxShadow: selected ? const [BoxShadow(color: Color.fromRGBO(1, 22, 39, 0.18), blurRadius: 8, offset: Offset(0, 4))] : const [],
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : CouponCloudApp.navy.withOpacity(0.7))),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.title, required this.items, this.titleColor, this.muted = false});
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
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: titleColor == null ? const Color(0x14011627) : const Color(0x33FF8C00)))),
                child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: titleColor ?? CouponCloudApp.navy)),
              ),
              const SizedBox(height: 10),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: titleColor ?? const Color(0x66011627))),
                        const SizedBox(width: 10),
                        Text(item, style: TextStyle(fontSize: 13, fontWeight: muted ? FontWeight.w600 : FontWeight.w700, color: CouponCloudApp.navy.withOpacity(muted ? 0.85 : 1))),
                      ],
                    ),
                  )),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: const Border(left: BorderSide(color: CouponCloudApp.orange, width: 4))),
        child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: CouponCloudApp.navy)),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x4D011627), width: 2)),
            child: const Column(
              children: [
                Icon(Icons.file_upload_outlined, size: 34, color: Color(0x80011627)),
                SizedBox(height: 8),
                Text('Tap to upload photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0x99011627))),
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
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CouponCloudApp.navy)),
              const Text('Thumbs up / down', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CouponCloudApp.orange)),
            ],
          ),
        ),
      );
}
