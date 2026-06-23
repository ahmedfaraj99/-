import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../theme/design_system.dart';
import '../services/api_service.dart';

class CeilingScreen extends StatefulWidget {
  const CeilingScreen({super.key});
  @override
  State<CeilingScreen> createState() => _CeilingScreenState();
}

class _CeilingScreenState extends State<CeilingScreen>
    with SingleTickerProviderStateMixin {
  bool   _isLoading       = true;
  double _totalCeiling    = 100000;
  double _totalConsumed   = 0;
  double _totalPercentage = 0;
  List<Map<String, dynamic>> _rules        = [];
  List<Map<String, dynamic>> _familyFilter = [];
  int?   _selectedCardNo;
  int?   _selectedRuleId;

  late AnimationController _animCtrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: 1200.ms);
    _anim     = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _loadCeiling();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  /// البنود التي استهلكها المؤمَّن فعلاً (consumed > 0).
  /// لا نعرض البنود غير المستخدمة حتى لا يسعى المؤمَّن لاستهلاكها.
  List<Map<String, dynamic>> get _activeRules => _rules
      .where((r) => ((r['consumed'] ?? 0) as num).toDouble() > 0)
      .toList();

  Future<void> _loadCeiling() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getInsuredCeiling(cardNo: _selectedCardNo);
      if (result['success'] == true && mounted) {
        setState(() {
          _totalCeiling    = (result['total_ceiling']    ?? 100000).toDouble();
          _totalConsumed   = (result['total_consumed']   ?? 0).toDouble();
          _totalPercentage = (result['total_percentage'] ?? 0).toDouble();
          _rules           = List<Map<String, dynamic>>.from(result['rules']         ?? []);
          if (_familyFilter.isEmpty) {
            _familyFilter  = List<Map<String, dynamic>>.from(result['family_filter'] ?? []);
          }
          _isLoading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _progressColor(double pct) {
    if (pct >= 90) return DesignSystem.rose;
    if (pct >= 70) return DesignSystem.amber;
    return DesignSystem.teal;
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)} ألف';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selRule;
    double dCeil = _totalCeiling, dCons = _totalConsumed,
        dPct = _totalPercentage;
    String dTitle = 'السقف الإجمالي';

    if (_selectedRuleId != null) {
      selRule = _rules.firstWhere((r) => r['id'] == _selectedRuleId,
          orElse: () => {});
      if (selRule.isNotEmpty) {
        dCeil  = (selRule['ceiling']    ?? 0).toDouble();
        dCons  = (selRule['consumed']   ?? 0).toDouble();
        dPct   = (selRule['percentage'] ?? 0).toDouble();
        dTitle = selRule['name'] ?? '';
      }
    }
    final dRem   = math.max(0.0, dCeil - dCons);
    final pColor = _progressColor(dPct);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              if (_familyFilter.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _familyDropdown(),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DesignSystem.teal, strokeWidth: 2))
                    : RefreshIndicator(
                        color: DesignSystem.teal,
                        onRefresh: _loadCeiling,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          children: [
                            _circularCard(
                              title:      dTitle,
                              ceiling:    dCeil,
                              consumed:   dCons,
                              remaining:  dRem,
                              percentage: dPct,
                              color:      pColor,
                              dgre:       selRule?['dgre'],
                            ).animate().fadeIn(delay: 80.ms, duration: 400.ms),

                            const SizedBox(height: 20),

                            if (_activeRules.isNotEmpty) ...[
                              _sectionLabel('تصفية حسب البند المُستخدم'),
                              const SizedBox(height: 8),
                              _ruleChips(),
                              const SizedBox(height: 16),
                            ],

                            if (_selectedRuleId == null &&
                                _activeRules.isNotEmpty) ...[
                              _sectionLabel('تفاصيل البنود المُستخدمة'),
                              const SizedBox(height: 8),
                              _sharedPoolBanner(),
                              ..._activeRules.asMap().entries.map((e) =>
                                  _ruleCard(e.value, e.key)),
                            ],

                            if (_activeRules.isEmpty) _noUsageBanner(),
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

  // ───────────────────────────────────────
  // TOP BAR
  // ───────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
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
              'سقف المؤمَّن',
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
            child: const Icon(Icons.shield_outlined,
                color: DesignSystem.teal, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _sharedPoolBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: DesignSystem.teal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.teal.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: DesignSystem.teal, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'السقف الإجمالي ${_fmt(_totalCeiling)} د.ل هو أقصى تغطية. '
                'جميع البنود الفرعية تُستهلك من هذا المبلغ وليست إضافةً إليه.',
                style: DesignSystem.smallTextStyle.copyWith(
                  color: DesignSystem.teal,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );

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

  Widget _familyDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: _selectedCardNo,
            isExpanded: true,
            dropdownColor: DesignSystem.bgBody,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: DesignSystem.teal, size: 20),
            style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Row(children: [
                  const Icon(Icons.person_pin_rounded,
                      color: DesignSystem.teal, size: 16),
                  const SizedBox(width: 8),
                  Text('الموظف الرئيسي',
                      style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13)),
                ]),
              ),
              ..._familyFilter.map((f) {
                final cNo = f['card_no'];
                return DropdownMenuItem<int?>(
                  value: cNo != null ? int.tryParse(cNo.toString()) : null,
                  child: Row(children: [
                    const Icon(Icons.person_rounded,
                        color: DesignSystem.teal, size: 16),
                    const SizedBox(width: 8),
                    Text('${f['name']} (${f['relation']})',
                        style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13)),
                  ]),
                );
              }).toList(),
            ],
            onChanged: (val) {
              setState(() { _selectedCardNo = val; _selectedRuleId = null; });
              _loadCeiling();
            },
          ),
        ),
      );

  // ───────────────────────────────────────
  // CIRCULAR DONUT CARD
  // ───────────────────────────────────────
  Widget _circularCard({
    required String title,
    required double ceiling,
    required double consumed,
    required double remaining,
    required double percentage,
    required Color  color,
    int? dgre,
  }) {
    final clamped = percentage.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: DesignSystem.bgBody,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        border: Border.all(color: DesignSystem.borderPrimary),
        boxShadow: DesignSystem.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: DesignSystem.headingStyle.copyWith(fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final animPct = clamped * _anim.value;
              return SizedBox(
                width: 200, height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: _ArcPainter(
                        progress:    animPct / 100,
                        color:       color,
                        trackColor:  DesignSystem.bgDeepDark,
                        strokeWidth: 16,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmt(remaining * _anim.value),
                          textDirection: TextDirection.ltr,
                          style: DesignSystem.hugeNumberStyle.copyWith(
                            fontSize: 28,
                            color: DesignSystem.amber,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'د.ل المتبقي',
                          style: DesignSystem.labelStyle.copyWith(
                            color: DesignSystem.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(
                                DesignSystem.radiusPill),
                          ),
                          child: Text(
                            '${animPct.toStringAsFixed(0)}% مستهلك',
                            style: DesignSystem.labelStyle.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: DesignSystem.bgDeepDark,
              borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('السقف', _fmt(ceiling), DesignSystem.textPrimary),
                _dividerV(),
                _stat('المستهلك', _fmt(consumed), color),
                _dividerV(),
                _stat('المتبقي', _fmt(remaining), DesignSystem.amber),
              ],
            ),
          ),

          if (dgre != null && dgre > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DesignSystem.amber.withOpacity(0.10),
                borderRadius: BorderRadius.circular(DesignSystem.radiusPill),
                border: Border.all(color: DesignSystem.amber.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: DesignSystem.amber),
                  const SizedBox(width: 6),
                  Text(
                    'نسبة المؤمَّن عليه في هذا البند: $dgre%',
                    style: DesignSystem.smallTextStyle.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DesignSystem.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: DesignSystem.bodyTextStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DesignSystem.labelStyle.copyWith(
              color: DesignSystem.textSubtle,
            ),
          ),
        ],
      );

  Widget _dividerV() => Container(
      width: 1, height: 28, color: DesignSystem.borderPrimary);

  // ───────────────────────────────────────
  // RULE CHIPS
  // ───────────────────────────────────────
  Widget _ruleChips() => SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _chip('الكل', null),
            ..._activeRules.map((r) => _chip(r['name'] ?? '', r['id'])),
          ],
        ),
      );

  /// لوحة تظهر عندما لا يكون للمؤمَّن أي مصروفات بعد.
  Widget _noUsageBanner() => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
        ),
        child: Column(
          children: [
            const Icon(Icons.verified_outlined,
                color: DesignSystem.teal, size: 32),
            const SizedBox(height: 10),
            Text(
              'لا توجد بنود مُستخدمة حتى الآن',
              style: DesignSystem.headingStyle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر تفاصيل أي بند هنا بمجرد أن يتم استهلاك جزء منه.',
              style: DesignSystem.smallTextStyle.copyWith(
                color: DesignSystem.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _chip(String label, int? id) {
    final sel = _selectedRuleId == id;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedRuleId = id);
          _animCtrl.forward(from: 0);
        },
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? DesignSystem.teal : DesignSystem.bgBody,
            borderRadius: BorderRadius.circular(DesignSystem.radiusPill),
            border: Border.all(
                color: sel ? DesignSystem.teal : DesignSystem.borderPrimary),
          ),
          child: Text(
            label,
            style: DesignSystem.smallTextStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : DesignSystem.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // RULE CARD
  // ───────────────────────────────────────
  Widget _ruleCard(Map<String, dynamic> rule, int i) {
    final consumed   = (rule['consumed']   ?? 0).toDouble();
    final ceiling    = (rule['ceiling']    ?? 0).toDouble();
    final percentage = (rule['percentage'] ?? 0).toDouble();
    final remaining  = (rule['remaining']  ?? 0).toDouble();
    final color      = _progressColor(percentage);
    final dgre       = rule['dgre'] ?? 0;
    final clamped    = percentage.clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          Row(
            children: [
              SizedBox(
                width: 56, height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(56, 56),
                      painter: _ArcPainter(
                        progress:    (clamped / 100).clamp(0.0, 1.0),
                        color:       color,
                        trackColor:  DesignSystem.bgDeepDark,
                        strokeWidth: 6,
                      ),
                    ),
                    Text(
                      '${clamped.toStringAsFixed(0)}%',
                      style: DesignSystem.labelStyle.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
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
                        fontSize: 13,
                        height: 1.3,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    if (dgre > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: DesignSystem.amber.withOpacity(0.10),
                          borderRadius:
                              BorderRadius.circular(DesignSystem.radiusPill),
                        ),
                        child: Text(
                          'نسبتك $dgre%',
                          style: DesignSystem.labelStyle.copyWith(
                            color: DesignSystem.amber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: DesignSystem.borderPrimary),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(ceiling),
                    textDirection: TextDirection.ltr,
                    style: DesignSystem.bodyTextStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: DesignSystem.textPrimary,
                    ),
                  ),
                  Text(
                    'السقف',
                    style: DesignSystem.labelStyle.copyWith(
                      color: DesignSystem.textSubtle,
                    ),
                  ),
                  Text(
                    'من ${_fmt(_totalCeiling)} إجمالي',
                    style: DesignSystem.labelStyle.copyWith(
                      color: DesignSystem.teal,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _miniStat('مستهلك',  _fmt(consumed), color),
              _miniStat('متبقي',   _fmt(remaining), DesignSystem.amber),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (i * 40).ms, duration: 300.ms)
        .slideX(begin: 0.04, curve: DesignSystem.easeOutCurve);
  }

  Widget _miniStat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: DesignSystem.bodyTextStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: DesignSystem.labelStyle.copyWith(
              color: DesignSystem.textSubtle,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────
// ARC PAINTER — unchanged logic, just kept clean
// ─────────────────────────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final double progress;
  final Color  color;
  final Color  trackColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  static const double _startAngle = math.pi * 0.75;
  static const double _sweepTotal = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect, _startAngle, _sweepTotal, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    final sweepProgress = _sweepTotal * progress.clamp(0.0, 1.0);
    final endAngle      = _startAngle + sweepProgress;

    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: _startAngle,
        endAngle: endAngle,
        colors: [color.withOpacity(0.6), color],
      ).createShader(rect);

    canvas.drawArc(rect, _startAngle, sweepProgress, false, gradientPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}
