import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/design_system.dart';
import '../services/api_service.dart';

class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key});
  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  List<Map<String, dynamic>> _activeRules  = [];
  List<Map<String, dynamic>> _retireeRules = [];
  bool _isLoading = true;
  int _segment = 0; // 0 = active, 1 = retirees

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final result = await ApiService.getCoverageRules();
      if (result['success'] == true && mounted) {
        setState(() {
          _activeRules  = List<Map<String, dynamic>>.from(result['active_rules']  ?? []);
          _retireeRules = List<Map<String, dynamic>>.from(result['retiree_rules'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatPrice(dynamic price) {
    final n = double.tryParse(price?.toString() ?? '') ?? 0;
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)} ألف';
    }
    return n.toStringAsFixed(0);
  }

  IconData _icon(String name) {
    final l = name.toLowerCase();
    if (l.contains('عيون') || l.contains('نظارات')) return Icons.visibility_outlined;
    if (l.contains('أسنان') || l.contains('اسنان')) return Icons.medical_services_outlined;
    if (l.contains('حمل')  || l.contains('ولادة'))  return Icons.pregnant_woman_outlined;
    if (l.contains('جراح'))                          return Icons.healing_outlined;
    if (l.contains('أدوية') || l.contains('ادوية')) return Icons.medication_outlined;
    if (l.contains('أشعة') || l.contains('اشعة'))   return Icons.filter_center_focus_outlined;
    if (l.contains('تحليل') || l.contains('مختبر')) return Icons.science_outlined;
    if (l.contains('طوارئ'))                         return Icons.emergency_outlined;
    if (l.contains('إيواء') || l.contains('تنويم')) return Icons.hotel_outlined;
    if (l.contains('علاج طبيعي'))                   return Icons.accessibility_new_rounded;
    return Icons.local_hospital_outlined;
  }

  // كل القواعد لها لون تيل واحد — متناسق مع Medical Calm
  Color _color(int i) => DesignSystem.teal;

  @override
  Widget build(BuildContext context) {
    final rules = _segment == 0 ? _activeRules : _retireeRules;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: _buildSegmented(),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DesignSystem.teal, strokeWidth: 2))
                    : rules.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: DesignSystem.teal,
                            onRefresh: _loadRules,
                            child: ListView.builder(
                              key: ValueKey(_segment),
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              itemCount: rules.length,
                              itemBuilder: (_, i) =>
                                  _buildRuleCard(rules[i], i),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // TOP BAR
  // ───────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'السقف العلاجي',
              style: DesignSystem.headingStyle.copyWith(fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: DesignSystem.teal.withOpacity(0.10),
              borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: DesignSystem.teal, size: 18),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────
  // SEGMENTED CONTROL
  // ───────────────────────────────────────
  Widget _buildSegmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignSystem.bgDeepDark,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
        border: Border.all(color: DesignSystem.borderPrimary),
      ),
      child: Row(
        children: [
          _segBtn('الموظفون النشطون', 0),
          _segBtn('المتقاعدون', 1),
        ],
      ),
    );
  }

  Widget _segBtn(String label, int index) {
    final selected = _segment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? DesignSystem.bgBody : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? DesignSystem.cardShadow : null,
          ),
          child: Center(
            child: Text(
              label,
              style: DesignSystem.smallTextStyle.copyWith(
                color: selected ? DesignSystem.teal : DesignSystem.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // RULE CARD
  // ───────────────────────────────────────
  Widget _buildRuleCard(Map<String, dynamic> rule, int i) {
    final color = _color(i);
    final icon  = _icon(rule['name'] ?? '');
    final price = double.tryParse(rule['price'].toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rule['name'] ?? '',
                  style: DesignSystem.headingStyle.copyWith(
                    fontSize: 14,
                    height: 1.3,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 12, color: DesignSystem.textSubtle),
                    const SizedBox(width: 4),
                    Text(
                      'الحد الأقصى للتغطية',
                      style: DesignSystem.labelStyle.copyWith(
                          color: DesignSystem.textSubtle),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Price badge — gold
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatPrice(price),
                textDirection: TextDirection.ltr,
                style: DesignSystem.bodyTextStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DesignSystem.amber,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'د.ل',
                style: DesignSystem.labelStyle.copyWith(
                    color: DesignSystem.amber.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (i * 40).ms, duration: 300.ms)
        .slideX(begin: 0.04, curve: DesignSystem.easeOutCurve);
  }

  // ───────────────────────────────────────
  // EMPTY
  // ───────────────────────────────────────
  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: DesignSystem.teal.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 44, color: DesignSystem.teal),
              ),
              const SizedBox(height: 16),
              Text('لا توجد بيانات تغطية',
                  style: DesignSystem.headingStyle.copyWith(fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                'لم يتم تسجيل قواعد تغطية لهذه الفئة',
                textAlign: TextAlign.center,
                style: DesignSystem.smallTextStyle.copyWith(
                  color: DesignSystem.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
}
