import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_system.dart';
import '../widgets/app_bottom_nav.dart';
import 'chat_screen.dart';
import 'ticket_screen.dart';

/// 🌿 شاشة الدعم الموحَّدة
/// تجمع: محادثة فورية + تذاكر الدعم في مكان واحد
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Top Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: DesignSystem.teal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          color: DesignSystem.teal, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'الدعم والمساعدة',
                            style: DesignSystem.headingStyle.copyWith(fontSize: 17),
                          ),
                          Text(
                            'كيف يمكننا مساعدتك اليوم؟',
                            style: DesignSystem.labelStyle.copyWith(
                              color: DesignSystem.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Hero card — quick chat
                    _heroCard(context).animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .slideY(begin: 0.04, curve: DesignSystem.easeOutCurve),

                    const SizedBox(height: 20),

                    _sectionLabel('قنوات التواصل'),
                    const SizedBox(height: 10),

                    _supportOption(
                      context,
                      icon: Icons.phone_rounded,
                      title: 'محادثة هاتفية',
                      subtitle: 'اتصل بفريق الدعم مباشرة',
                      color: DesignSystem.emerald,
                      onTap: () => _showPhoneSheet(context),
                    ).animate().fadeIn(delay: 180.ms, duration: 300.ms),

                    const SizedBox(height: 10),

                    _supportOption(
                      context,
                      icon: Icons.confirmation_number_outlined,
                      title: 'فتح تذكرة',
                      subtitle: 'تذاكر شكاوى ومتابعة طلباتك',
                      color: DesignSystem.amber,
                      onTap: () => _push(context, const TicketScreen()),
                    ).animate().fadeIn(delay: 240.ms, duration: 300.ms),

                    const SizedBox(height: 10),

                    _supportOption(
                      context,
                      icon: Icons.history_rounded,
                      title: 'تذاكري السابقة',
                      subtitle: 'عرض الردود وحالة التذاكر',
                      color: DesignSystem.violet,
                      onTap: () => _push(
                          context, const TicketScreen(openMyTickets: true)),
                    ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

                    const SizedBox(height: 24),

                    _sectionLabel('أسئلة شائعة'),
                    const SizedBox(height: 10),

                    _faqTile(
                      'كيف يمكنني إضافة تابع جديد؟',
                      'تواصل مع قسم الموارد البشرية لإضافة تابع.',
                    ),
                    _faqTile(
                      'لماذا لا تظهر بعض فواتيري؟',
                      'الفواتير تظهر فور تسجيلها من مزود الخدمة.',
                    ),
                    _faqTile(
                      'كيف أتحقق من سقفي العلاجي؟',
                      'من قائمة الخدمات الرئيسية اختر "السقف العلاجي".',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showPhoneSheet(BuildContext context) {
    const phones = [
      {'label': 'الخط الأول', 'number': '218912640760'},
      {'label': 'الخط الثاني', 'number': '218912640761'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: DesignSystem.bgPhone,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignSystem.borderPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: DesignSystem.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_rounded,
                          color: DesignSystem.emerald, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('محادثة هاتفية',
                            style: DesignSystem.headingStyle.copyWith(fontSize: 15)),
                        Text('اختر الخط للاتصال',
                            style: DesignSystem.smallTextStyle
                                .copyWith(color: DesignSystem.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...phones.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final uri = Uri.parse('tel:+${p['number']}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: DesignSystem.emerald.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.call_rounded,
                                  color: DesignSystem.emerald, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(p['label']!,
                                      style: DesignSystem.headingStyle
                                          .copyWith(fontSize: 13)),
                                  Text('+${p['number']}',
                                      style: DesignSystem.smallTextStyle.copyWith(
                                          color: DesignSystem.textMuted,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: DesignSystem.textSubtle),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
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

  Widget _heroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DesignSystem.tealGradient,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        boxShadow: DesignSystem.ctaShadow,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -30, top: -30,
            child: Container(
              width: 120, height: 120,
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
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFA3E635),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'متصل الآن',
                          style: DesignSystem.labelStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'فريق الدعم جاهز للمساعدة',
                style: DesignSystem.headingStyle.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'متوسط زمن الرد أقل من 5 دقائق',
                style: DesignSystem.smallTextStyle.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _push(context, const ChatScreen()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_rounded,
                          color: DesignSystem.teal, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'ابدأ المحادثة',
                        style: DesignSystem.buttonTextStyle.copyWith(
                          color: DesignSystem.teal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _supportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? badge,
    Color? badgeColor,
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
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
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
                          title,
                          style: DesignSystem.headingStyle.copyWith(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? color).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(
                                DesignSystem.radiusPill),
                          ),
                          child: Text(
                            badge,
                            style: DesignSystem.labelStyle.copyWith(
                              color: badgeColor ?? color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: DesignSystem.smallTextStyle.copyWith(
                      color: DesignSystem.textMuted,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: DesignSystem.textSubtle),
          ],
        ),
      ),
    );
  }

  Widget _faqTile(String q, String a) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
        ),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: DesignSystem.teal,
          collapsedIconColor: DesignSystem.textMuted,
          title: Text(
            q,
            style: DesignSystem.bodyTextStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                a,
                style: DesignSystem.smallTextStyle.copyWith(
                  color: DesignSystem.textMuted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
}
