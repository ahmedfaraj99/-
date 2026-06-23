import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/design_system.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<Map<String, dynamic>> _dependents = [];
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  Future<void> _loadFamily() async {
    try {
      final result = await ApiService.getProfile();
      if (result['success'] == true && mounted) {
        final deps = List<Map<String, dynamic>>.from(result['dependents'] ?? []);
        setState(() {
          _user = result['user'];
          _dependents = deps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isFemale(Map<String, dynamic> p) => (p['gender'] as String?) == 'أنثى';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        bottomNavigationBar: const AppBottomNav(currentIndex: 1),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DesignSystem.teal, strokeWidth: 2))
                    : RefreshIndicator(
                        color: DesignSystem.teal,
                        onRefresh: _loadFamily,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 20),
                            if (_user != null) ...[
                              _sectionLabel('الموظف الرئيسي'),
                              const SizedBox(height: 10),
                              _buildMemberCard(
                                _user!,
                                isPrimary: true,
                                index: 0,
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (_dependents.isNotEmpty) ...[
                              _sectionLabel('التابعون (${_dependents.length})'),
                              const SizedBox(height: 10),
                              ..._dependents.asMap().entries.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildMemberCard(
                                      e.value,
                                      isPrimary: false,
                                      index: e.key + 1,
                                    ),
                                  )),
                            ],
                            if (_dependents.isEmpty && _user != null)
                              _buildEmptyDependents(),
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

  // ─────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────
  Widget _buildTopBar() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          if (canPop)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: DesignSystem.bgBody,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                  border: Border.all(color: DesignSystem.borderPrimary),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: DesignSystem.textPrimary, size: 16),
              ),
            )
          else
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: DesignSystem.teal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
              ),
              child: const Icon(Icons.groups_rounded,
                  color: DesignSystem.teal, size: 18),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'أفراد العائلة',
              style: DesignSystem.headingStyle.copyWith(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // SUMMARY CARD (Teal soft with count)
  // ─────────────────────────────────────────
  Widget _buildSummaryCard() {
    final total = _dependents.length + (_user != null ? 1 : 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignSystem.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        border: Border.all(color: DesignSystem.teal.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DesignSystem.bgBody,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups_rounded,
                color: DesignSystem.teal, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إجمالي المؤمَّن عليهم',
                  style: DesignSystem.smallTextStyle.copyWith(
                    color: DesignSystem.tealDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$total',
                      textDirection: TextDirection.ltr,
                      style: DesignSystem.headingStyle.copyWith(
                        fontSize: 22,
                        color: DesignSystem.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'أفراد',
                      style: DesignSystem.bodyTextStyle.copyWith(
                        color: DesignSystem.tealDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05);
  }

  // ─────────────────────────────────────────
  // SECTION LABEL
  // ─────────────────────────────────────────
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

  // ─────────────────────────────────────────
  // MEMBER CARD (unified for primary + dependents)
  // ─────────────────────────────────────────
  Widget _buildMemberCard(
    Map<String, dynamic> p, {
    required bool isPrimary,
    required int index,
  }) {
    final isFemale = _isFemale(p);
    final isActive = (p['card_status'] as int? ?? 1) == 0;
    final statusColor = isActive ? DesignSystem.emerald : DesignSystem.rose;
    final statusText = (p['card_status_text'] as String?) ?? '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignSystem.bgBody,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        border: Border.all(color: DesignSystem.borderPrimary),
        boxShadow: DesignSystem.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: avatar + name + status chip
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isFemale
                      ? DesignSystem.violetGradient
                      : DesignSystem.tealGradient,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusAvatar),
                  boxShadow: DesignSystem.glowShadow(
                    isFemale ? DesignSystem.violet : DesignSystem.teal,
                  ),
                ),
                child: Icon(
                  isFemale ? Icons.woman_rounded : Icons.man_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p['name'] ?? '',
                      style: DesignSystem.headingStyle.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isPrimary)
                          _chip('المؤمَّن الرئيسي', DesignSystem.teal)
                        else
                          _chip(
                            (p['relation'] as String?) ?? 'تابع',
                            DesignSystem.violet,
                          ),
                        const SizedBox(width: 6),
                        _chip(statusText, statusColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: DesignSystem.borderPrimary),
          const SizedBox(height: 12),

          // Row 2: card no + birth date
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  Icons.credit_card_outlined,
                  'رقم البطاقة',
                  (p['card_no'] ?? '—').toString(),
                ),
              ),
              Expanded(
                child: _infoItem(
                  Icons.cake_outlined,
                  'تاريخ الميلاد',
                  (p['date_mtq'] ?? '—').toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  Icons.event_outlined,
                  'انتهاء الصلاحية',
                  (p['expired_date'] ?? '—').toString(),
                ),
              ),
              Expanded(
                child: _infoItem(
                  isFemale ? Icons.female_rounded : Icons.male_rounded,
                  'الجنس',
                  (p['gender'] ?? '—').toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 400.ms)
        .slideY(begin: 0.04, curve: DesignSystem.easeOutCurve);
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(DesignSystem.radiusPill),
        ),
        child: Text(
          text,
          style: DesignSystem.labelStyle.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _infoItem(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: DesignSystem.textMuted),
          const SizedBox(width: 6),
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
                    color: DesignSystem.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────
  // EMPTY STATE (no dependents)
  // ─────────────────────────────────────────
  Widget _buildEmptyDependents() => Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DesignSystem.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.groups_outlined,
                  color: DesignSystem.teal, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              'لا يوجد تابعون مسجَّلون',
              style: DesignSystem.headingStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'لإضافة تابع جديد، يرجى التواصل مع قسم الموارد البشرية',
              textAlign: TextAlign.center,
              style: DesignSystem.smallTextStyle.copyWith(
                color: DesignSystem.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
}
