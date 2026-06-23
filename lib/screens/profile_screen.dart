import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'login_screen.dart';
import 'change_pin_screen.dart';

/// 🌿 شاشة حسابي — Profile + Settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AuthService.getUser();
    if (mounted) setState(() { _user = u; _loading = false; });
    try {
      final res = await ApiService.getProfile();
      if (res['success'] == true && mounted) {
        await AuthService.saveUser(res['user']);
        setState(() => _user = res['user']);
      }
    } catch (_) {}
  }

  void _logout() async {
    await AuthService.clearAll();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFemale = (_user?['gender'] as String?) == 'أنثى';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: DesignSystem.teal, strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Text(
                      'حسابي',
                      style: DesignSystem.headingStyle.copyWith(fontSize: 17),
                    ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 16),

                    // Profile hero card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: DesignSystem.bgBody,
                        borderRadius:
                            BorderRadius.circular(DesignSystem.radiusCard),
                        border: Border.all(color: DesignSystem.borderPrimary),
                        boxShadow: DesignSystem.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              gradient: isFemale
                                  ? DesignSystem.violetGradient
                                  : DesignSystem.tealGradient,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: DesignSystem.avatarShadow,
                            ),
                            child: Icon(
                              isFemale ? Icons.woman_rounded : Icons.man_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _user?['name'] ?? '—',
                                  style: DesignSystem.headingStyle
                                      .copyWith(fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: DesignSystem.teal.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(
                                        DesignSystem.radiusPill),
                                  ),
                                  child: Text(
                                    'الموظف ${_user?['emp_no'] ?? '—'}',
                                    style: DesignSystem.labelStyle.copyWith(
                                      color: DesignSystem.teal,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                    const SizedBox(height: 16),

                    // User info card
                    _infoCard([
                      _info(Icons.credit_card_outlined, 'رقم البطاقة',
                          (_user?['card_no'] ?? '—').toString()),
                      _info(Icons.badge_outlined, 'الرقم الوطني',
                          (_user?['national_id'] ?? '—').toString()),
                      _info(Icons.email_outlined, 'البريد الإلكتروني',
                          (_user?['email'] ?? '—').toString()),
                      _info(Icons.cake_outlined, 'تاريخ الميلاد',
                          (_user?['date_mtq'] ?? '—').toString()),
                    ]),

                    const SizedBox(height: 20),

                    _sectionLabel('الإعدادات'),
                    const SizedBox(height: 10),

                    _actionTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'تغيير الرمز السري',
                      color: DesignSystem.teal,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChangePinScreen())),
                    ),
                    const SizedBox(height: 8),
                    _actionTile(
                      icon: Icons.info_outline_rounded,
                      title: 'عن التطبيق',
                      color: DesignSystem.violet,
                      onTap: () => _showAbout(context),
                    ),
                    const SizedBox(height: 8),
                    _actionTile(
                      icon: Icons.logout_rounded,
                      title: 'تسجيل الخروج',
                      color: DesignSystem.rose,
                      onTap: _confirmLogout,
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        'الإصدار 1.0.0',
                        style: DesignSystem.labelStyle.copyWith(
                          color: DesignSystem.textSubtle,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: DesignSystem.smallTextStyle.copyWith(
            color: DesignSystem.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );

  Widget _infoCard(List<Widget> items) => Container(
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
          boxShadow: DesignSystem.cardShadow,
        ),
        child: Column(
          children: List.generate(items.length, (i) {
            return Column(
              children: [
                items[i],
                if (i < items.length - 1)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: DesignSystem.borderPrimary,
                  ),
              ],
            );
          }),
        ),
      );

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: DesignSystem.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: DesignSystem.teal, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: DesignSystem.labelStyle.copyWith(
                      color: DesignSystem.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: DesignSystem.bodyTextStyle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
          boxShadow: DesignSystem.cardShadow,
        ),
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
              child: Text(
                title,
                style: DesignSystem.bodyTextStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: DesignSystem.textSubtle),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: DesignSystem.bgBody,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusCard)),
          title: Text('تسجيل الخروج',
              style: DesignSystem.headingStyle.copyWith(fontSize: 15)),
          content: Text(
            'هل أنت متأكد من تسجيل الخروج؟',
            style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء',
                  style: DesignSystem.bodyTextStyle
                      .copyWith(color: DesignSystem.textMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _logout();
              },
              child: Text('خروج',
                  style: DesignSystem.bodyTextStyle.copyWith(
                    color: DesignSystem.rose,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: DesignSystem.bgBody,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusCard)),
          title: Text('بوابة المؤمَّن',
              style: DesignSystem.headingStyle.copyWith(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تطبيق رسمي تابع لـ BHIF لتوفير خدمات المؤمَّن عليهم.',
                style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 8),
              Text(
                'الإصدار 1.0.0 — Medical Calm',
                style: DesignSystem.smallTextStyle.copyWith(
                  color: DesignSystem.textMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('حسناً',
                  style: DesignSystem.bodyTextStyle
                      .copyWith(color: DesignSystem.teal,
                          fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
