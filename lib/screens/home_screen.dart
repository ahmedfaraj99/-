import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'coverage_screen.dart';
import 'invoices_screen.dart';
import 'ceiling_screen.dart';
import 'ticket_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _pendingRatings = [];
  int    _totalUnread = 0;
  Timer? _unreadTimer;

  final PageController _announcementsPageCtrl =
      PageController(viewportFraction: 0.92);
  int _currentAnnouncement = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadAnnouncements();
    _loadUnreadCount();
    _loadRecentActivity();
    _unreadTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnreadCount());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPendingRatings());
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _announcementsPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (mounted) setState(() => _user = user);
    try {
      final freshProfile = await ApiService.getProfile();
      if (freshProfile['success'] == true) {
        await AuthService.saveUser(freshProfile['user']);
        if (mounted) setState(() => _user = freshProfile['user']);
      }
    } catch (_) {}
  }

  Future<void> _loadAnnouncements() async {
    try {
      final res = await ApiService.getAnnouncements();
      if (res['success'] == true && mounted) {
        setState(() {
          _announcements =
              List<Map<String, dynamic>>.from(res['announcements'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await ApiService.getUnreadCount();
      if (res['success'] == true && mounted) {
        setState(() {
          _totalUnread = (res['total'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecentActivity() async {
    final List<Map<String, dynamic>> activity = [];
    // 1) آخر 5 فواتير
    try {
      final res = await ApiService.getInvoices();
      if (res['success'] == true) {
        final invoices = List<Map<String, dynamic>>.from(res['invoices'] ?? []);
        for (final inv in invoices.take(5)) {
          activity.add({
            'kind': 'invoice',
            'date': inv['date'] ?? '',
            'title': inv['provider'] ?? 'مزود الخدمة',
            'subtitle': inv['beneficiary_name'] ?? '',
            'amount': inv['value'],
            'id': inv['id'],
          });
        }
      }
    } catch (_) {}

    // 2) إشعارات (ردود على التذاكر/شات)
    try {
      final res = await ApiService.getNotifications();
      final notifs = List<Map<String, dynamic>>.from(res['notifications'] ?? []);
      for (final n in notifs.take(3)) {
        activity.add({
          'kind': n['type'] == 'ticket_reply' ? 'ticket' : 'chat',
          'date': n['time'] ?? '',
          'title': n['type'] == 'ticket_reply' ? 'رد على تذكرتك' : 'محادثة دعم',
          'subtitle': (n['body'] ?? '').toString(),
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _recentActivity = activity);
  }

  // ─────────────────────────────────────────
  // PROVIDER RATINGS
  // ─────────────────────────────────────────
  /// مفتاح SharedPreferences لتخزين التقييمات المُتخطَّاة/المُرسَلة
  static const _kDismissedRatings = 'dismissed_provider_ratings';

  /// يُنشئ مفتاحاً فريداً لكل زيارة
  static String _visitKey(Map<String, dynamic> v) =>
      '${v['provider_id']}:${v['visit_date']}';

  Future<Set<String>> _getDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kDismissedRatings)?.toSet() ?? {};
  }

  Future<void> _markDismissed(Map<String, dynamic> visit) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_kDismissedRatings)?.toSet() ?? {};
    current.add(_visitKey(visit));
    await prefs.setStringList(_kDismissedRatings, current.toList());
  }

  Future<void> _loadPendingRatings() async {
    try {
      final res = await ApiService.getPendingRatings();
      if (res['success'] == true && mounted) {
        final all      = List<Map<String, dynamic>>.from(res['pending'] ?? []);
        final dismissed = await _getDismissed();
        // استبعاد الزيارات التي سبق تخطيها أو تقييمها
        final list = all.where((v) => !dismissed.contains(_visitKey(v))).toList();
        if (list.isNotEmpty) {
          setState(() => _pendingRatings = list);
          _showRatingDialog(list.first);
        }
      }
    } catch (_) {}
  }

  Future<void> _showRatingDialog(Map<String, dynamic> visit) async {
    int selectedRating = 0;
    final commentCtrl  = TextEditingController();
    bool submitting    = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: DesignSystem.bgPhone,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: DesignSystem.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: DesignSystem.amber, size: 30),
                ),
                const SizedBox(height: 12),
                Text('قيّم زيارتك',
                    style: DesignSystem.headingStyle.copyWith(fontSize: 18),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  visit['provider_name'] ?? '',
                  style: DesignSystem.bodyTextStyle
                      .copyWith(color: DesignSystem.teal, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                Text(
                  visit['visit_date'] ?? '',
                  style: DesignSystem.bodyTextStyle.copyWith(
                      color: DesignSystem.textMuted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedRating = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          star <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: DesignSystem.amber,
                          size: 38,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentCtrl,
                  style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'تعليق (اختياري)...',
                    hintStyle: DesignSystem.bodyTextStyle
                        .copyWith(color: DesignSystem.textSubtle),
                    filled: true,
                    fillColor: DesignSystem.bgPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignSystem.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignSystem.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignSystem.teal),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('تخطي',
                    style: DesignSystem.bodyTextStyle
                        .copyWith(color: DesignSystem.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignSystem.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: selectedRating == 0 || submitting
                    ? null
                    : () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final comment = commentCtrl.text.trim();
                        setDialogState(() => submitting = true);
                        try {
                          final res = await ApiService.rateProvider(
                            providerId: visit['provider_id'] as int,
                            visitDate:  visit['visit_date'] as String,
                            rating:     selectedRating,
                            comment:    comment.isEmpty ? null : comment,
                          );
                          final success = res['success'] == true;
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (success && mounted) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('شكراً! تم حفظ تقييمك'),
                                    backgroundColor: DesignSystem.teal,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            });
                          }
                        } catch (_) {
                          if (ctx.mounted) {
                            setDialogState(() => submitting = false);
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال'),
              ),
            ],
          ),
        ),
      ),
    );

    // سواء تخطى أو أرسل: احفظ الزيارة محلياً حتى لا تظهر مجدداً
    await _markDismissed(visit);

    // عرض التقييم التالي إن وُجد
    if (mounted) {
      _pendingRatings.removeWhere((v) =>
          v['provider_id'] == visit['provider_id'] &&
          v['visit_date']  == visit['visit_date']);
      if (_pendingRatings.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _showRatingDialog(_pendingRatings.first);
      }
    }
  }

  void _nav(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final raw = _user?['total_expenses'];
    final totalExpenses = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0.0;
    final familyCount = _user?['family_count'] ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: DesignSystem.teal,
            onRefresh: () async {
              await Future.wait([
                _loadUser(),
                _loadAnnouncements(),
                _loadUnreadCount(),
                _loadRecentActivity(),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader().animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 20),

                  _buildHeroCard(totalExpenses, familyCount)
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 500.ms)
                      .slideY(begin: 0.04, curve: DesignSystem.easeOutCurve),

                  if (_announcements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildAnnouncementsBanner()
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms),
                  ],

                  const SizedBox(height: 24),

                  // ⭐ TOP — الخدمات الأهم (أفقية)
                  _sectionLabel('الخدمات الرئيسية'),
                  const SizedBox(height: 12),
                  _buildPrimaryActions()
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // 📜 آخر النشاط
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('آخر النشاط'),
                      if (_recentActivity.isNotEmpty)
                        GestureDetector(
                          onTap: () => _nav(const InvoicesScreen()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: DesignSystem.teal.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(
                                  DesignSystem.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'عرض الكل',
                                  style: DesignSystem.labelStyle.copyWith(
                                    color: DesignSystem.teal,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_back_ios_new_rounded,
                                    size: 9, color: DesignSystem.teal),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildRecentActivity()
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      ),
    );
  }

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    final isFemale = (_user?['gender'] as String?) == 'أنثى';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: isFemale
                ? DesignSystem.violetGradient
                : DesignSystem.tealGradient,
            borderRadius: BorderRadius.circular(DesignSystem.radiusAvatar),
            boxShadow: DesignSystem.avatarShadow,
          ),
          child: Icon(
            isFemale ? Icons.woman_rounded : Icons.man_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'مرحباً بك 🌿',
                style: DesignSystem.smallTextStyle.copyWith(
                  color: DesignSystem.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _user?['name'] ?? '...',
                style: DesignSystem.headingStyle.copyWith(fontSize: 15),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        _iconButton(
          icon: _totalUnread > 0
              ? Icons.notifications_rounded
              : Icons.notifications_outlined,
          onTap: _openNotifications,
          badge: _totalUnread > 0 ? _totalUnread : null,
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: DesignSystem.bgBody,
              borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
              border: Border.all(color: DesignSystem.borderPrimary),
            ),
            child: Icon(icon, color: DesignSystem.textPrimary, size: 18),
          ),
          if (badge != null && badge > 0)
            Positioned(
              top: -4, left: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: DesignSystem.rose,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: DesignSystem.bgPrimary, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // HERO CARD
  // ─────────────────────────────────────────
  Widget _buildHeroCard(double total, int family) {
    final intPart = total.floor();
    final decPart = ((total - intPart) * 100).round().toString().padLeft(2, '0');
    final formatted = intPart.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: DesignSystem.blueGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: DesignSystem.ctaShadow,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -40, top: -40,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'إجمالي المصروفات',
                    style: DesignSystem.bodyTextStyle.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$formatted.$decPart',
                    textDirection: TextDirection.ltr,
                    style: DesignSystem.hugeNumberStyle.copyWith(
                      color: const Color(0xFFFEF3C7),
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'د.ل',
                    style: DesignSystem.bodyTextStyle.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_rounded, color: Colors.white, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          '$family تابعين',
                          style: DesignSystem.bodyTextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // ANNOUNCEMENTS
  // ─────────────────────────────────────────
  Widget _buildAnnouncementsBanner() {
    if (_announcements.length == 1) {
      return _announcementCard(_announcements.first, fullWidth: true);
    }
    return Column(
      children: [
        SizedBox(
          height: 92,
          child: PageView.builder(
            controller: _announcementsPageCtrl,
            itemCount: _announcements.length,
            onPageChanged: (i) => setState(() => _currentAnnouncement = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _announcementCard(_announcements[i], fullWidth: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_announcements.length, (i) {
            final active = i == _currentAnnouncement;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? DesignSystem.teal
                    : DesignSystem.teal.withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _announcementCard(Map<String, dynamic> a, {required bool fullWidth}) {
    final type  = a['type'] as String? ?? 'info';
    final color = _announcementColor(type);
    final icon  = _announcementIcon(type);
    return Container(
      width: double.infinity,
      margin: fullWidth ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['title'] as String? ?? '',
                  style: DesignSystem.bodyTextStyle.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  a['message'] as String? ?? '',
                  style: DesignSystem.smallTextStyle.copyWith(
                    color: DesignSystem.textMuted,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _announcementColor(String type) => switch (type) {
        'warning' => DesignSystem.amber,
        'success' => DesignSystem.emerald,
        'urgent'  => DesignSystem.rose,
        _         => DesignSystem.teal,
      };

  IconData _announcementIcon(String type) => switch (type) {
        'warning' => Icons.warning_amber_rounded,
        'success' => Icons.check_circle_outline_rounded,
        'urgent'  => Icons.priority_high_rounded,
        _         => Icons.campaign_rounded,
      };

  // ─────────────────────────────────────────
  // PRIMARY ACTIONS — ⭐ الأهم في الأعلى
  // الفواتير + السقف + الخدمات (التغطية)
  // ─────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text,
        style: DesignSystem.smallTextStyle.copyWith(
          color: DesignSystem.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      );

  Widget _buildPrimaryActions() {
    final items = [
      _PA(
        icon: Icons.description_rounded,
        title: 'الفواتير',
        color: DesignSystem.teal,
        onTap: () => _nav(const InvoicesScreen()),
      ),
      _PA(
        icon: Icons.shield_rounded,
        title: 'السقف',
        color: DesignSystem.amber,
        onTap: () => _nav(const CeilingScreen()),
      ),
      _PA(
        icon: Icons.medical_services_rounded,
        title: 'الخدمات',
        color: DesignSystem.violet,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'سيتم تفعيل هذه الميزة قريباً',
                textAlign: TextAlign.center,
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    ];

    return Row(
      children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: isLast ? 0 : 10),
            child: _buildPrimaryCard(e.value, e.key),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrimaryCard(_PA item, int index) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
          boxShadow: DesignSystem.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: DesignSystem.smallTextStyle.copyWith(
                color: DesignSystem.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 300.ms)
        .slideY(begin: 0.04, curve: DesignSystem.easeOutCurve);
  }

  // ─────────────────────────────────────────
  // RECENT ACTIVITY
  // ─────────────────────────────────────────
  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
        ),
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: DesignSystem.teal.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.history_rounded,
                  color: DesignSystem.teal, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              'لا يوجد نشاط حديث',
              style: DesignSystem.bodyTextStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ستظهر هنا فواتيرك وإشعاراتك الأخيرة',
              style: DesignSystem.smallTextStyle.copyWith(
                color: DesignSystem.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    // عرض آخر 4 فقط — الباقي يُعرض في شاشة الإشعارات
    final visible = _recentActivity.take(4).toList();

    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.bgBody,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        border: Border.all(color: DesignSystem.borderPrimary),
        boxShadow: DesignSystem.cardShadow,
      ),
      child: Column(
        children: visible.asMap().entries.map((e) {
          final isLast = e.key == visible.length - 1;
          return Column(
            children: [
              _buildActivityRow(e.value),
              if (!isLast)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: DesignSystem.borderPrimary,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> a) {
    final kind = a['kind'] as String;
    final IconData icon;
    final Color color;
    switch (kind) {
      case 'invoice':
        icon = Icons.receipt_long_rounded;
        color = DesignSystem.teal;
        break;
      case 'ticket':
        icon = Icons.reply_rounded;
        color = DesignSystem.amber;
        break;
      case 'chat':
        icon = Icons.chat_bubble_rounded;
        color = DesignSystem.emerald;
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = DesignSystem.slate;
    }

    return InkWell(
      onTap: () {
        if (kind == 'invoice') _nav(const InvoicesScreen());
        else if (kind == 'ticket') {
          _nav(const TicketScreen(openMyTickets: true));
        } else if (kind == 'chat') _nav(const ChatScreen());
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a['title'] ?? '',
                          style: DesignSystem.bodyTextStyle.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (a['amount'] != null)
                        Text(
                          '${a['amount']} د.ل',
                          textDirection: TextDirection.ltr,
                          style: DesignSystem.bodyTextStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: DesignSystem.amber,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (a['subtitle'] ?? '').toString(),
                          style: DesignSystem.smallTextStyle.copyWith(
                            color: DesignSystem.textMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if ((a['date'] ?? '').toString().isNotEmpty)
                        Text(
                          a['date'].toString(),
                          textDirection: TextDirection.ltr,
                          style: DesignSystem.labelStyle.copyWith(
                            color: DesignSystem.textSubtle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────
  void _openNotifications() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(
        onDone: _loadUnreadCount,
        nav: (screen) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
      ),
    );
    _loadUnreadCount();
  }
}

class _PA {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _PA({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _NotificationsSheet extends StatefulWidget {
  final VoidCallback onDone;
  final Future<void> Function(Widget) nav;
  const _NotificationsSheet({required this.onDone, required this.nav});
  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          _items   = List<Map<String, dynamic>>.from(res['notifications'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try { await ApiService.markTicketsRead(); } catch (_) {}
    try { await ApiService.markInvoicesRead(); } catch (_) {}
  }

  Color _typeColor(String type) {
    if (type == 'ticket_reply') return DesignSystem.teal;
    if (type == 'new_invoice')  return DesignSystem.amber;
    return DesignSystem.emerald;
  }

  IconData _typeIcon(String type) {
    if (type == 'ticket_reply') return Icons.reply_rounded;
    if (type == 'new_invoice')  return Icons.receipt_long_rounded;
    return Icons.chat_bubble_rounded;
  }

  String _typeLabel(String type) {
    if (type == 'ticket_reply') return 'رد على تذكرة';
    if (type == 'new_invoice')  return 'فاتورة جديدة';
    return 'محادثة فورية';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: DesignSystem.bgBody,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: DesignSystem.borderBright,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: DesignSystem.teal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: DesignSystem.teal, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('الإشعارات',
                        style: DesignSystem.headingStyle.copyWith(fontSize: 17)),
                    const Spacer(),
                    if (_items.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          await _markAllRead();
                          widget.onDone();
                          if (mounted) Navigator.pop(context);
                        },
                        child: Text('تحديد الكل كمقروء',
                            style: DesignSystem.smallTextStyle.copyWith(
                                color: DesignSystem.teal, fontSize: 11)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: DesignSystem.borderPrimary, height: 1),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DesignSystem.teal, strokeWidth: 2))
                    : _items.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _buildItem(_items[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 56, color: DesignSystem.textSubtle.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('لا توجد إشعارات جديدة',
                style: DesignSystem.bodyTextStyle
                    .copyWith(color: DesignSystem.textMuted)),
          ],
        ),
      );

  Widget _buildItem(Map<String, dynamic> item) {
    final type    = item['type'] as String;
    final isRead  = item['is_read'] == true;
    final color   = _typeColor(type);
    final subject = item['subject'] as String?;
    final body    = item['body']    as String? ?? '';
    final time    = item['time']    as String? ?? '';

    return Opacity(
      opacity: isRead ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: () async {
          Navigator.pop(context);
          if (type == 'ticket_reply') {
            await _markAllRead();
            widget.onDone();
            await widget.nav(const TicketScreen(openMyTickets: true));
          } else if (type == 'new_invoice') {
            await ApiService.markInvoicesRead();
            widget.onDone();
            await widget.nav(const InvoicesScreen());
          } else {
            await widget.nav(const ChatScreen());
          }
          widget.onDone();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DesignSystem.bgBody,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRead
                  ? DesignSystem.borderPrimary
                  : color.withOpacity(0.35),
              width: isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(type), color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_typeLabel(type),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ),
                        if (isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DesignSystem.textSubtle.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('مقروء',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: DesignSystem.textSubtle)),
                          ),
                        ],
                        const Spacer(),
                        Text(time,
                            style: DesignSystem.labelStyle.copyWith(
                                color: DesignSystem.textSubtle)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (subject != null && subject.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(subject,
                            style: DesignSystem.bodyTextStyle.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    Text(
                      body,
                      style: DesignSystem.smallTextStyle.copyWith(
                          color: DesignSystem.textPrimary,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
