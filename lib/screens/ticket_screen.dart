import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_system.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class TicketScreen extends StatefulWidget {
  final bool openMyTickets;
  const TicketScreen({super.key, this.openMyTickets = false});
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  int     _step            = 0;
  String? _selectedCat;
  String? _selectedCatLabel;
  String? _selectedSub;
  String? _selectedSubLabel;
  final _subjectCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  String _priority       = 'normal';
  bool   _isSubmitting   = false;
  List<Map<String, dynamic>> _myTickets     = [];
  bool   _showMyTickets  = false;
  bool   _loadingTickets = false;

  final Map<String, Map<String, dynamic>> _categories = {
    'complaint': {
      'label': 'تقديم شكوى',
      'icon':  Icons.report_problem_rounded,
      'color': DesignSystem.rose,
      'desc':  'تقديم شكوى رسمية',
      'subs': {
        'provider_complaint': 'شكوى ضد مزود خدمة',
        'claim_rejection':    'شكوى على رفض مطالبة',
        'service_delay':      'شكوى على تأخير في الإجراءات',
        'billing_error':      'شكوى على خطأ في الفوترة',
        'technical':          'شكوى تقنية',
      },
    },
    'objection': {
      'label': 'الاعتراض على خدمة',
      'icon':  Icons.gavel_rounded,
      'color': DesignSystem.amber,
      'desc':  'تقديم اعتراض رسمي',
      'subs': {
        'coverage_denial':    'اعتراض على رفض تغطية علاجية',
        'deductible_dispute': 'اعتراض على مبلغ التحمّل',
        'invoice_dispute':    'اعتراض على قيمة فاتورة',
        'uncovered_service':  'اعتراض على خدمة غير مغطاة',
      },
    },
    'inquiry': {
      'label': 'استفسار',
      'icon':  Icons.help_outline_rounded,
      'color': DesignSystem.emerald,
      'desc':  'استفسار عام',
      'subs': {
        'coverage_inquiry':  'استفسار عن التغطية التأمينية',
        'provider_inquiry':  'استفسار عن المستشفيات المعتمدة',
        'approval_inquiry':  'استفسار عن إجراءات الموافقات',
        'general_inquiry':   'استفسار عام',
      },
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.openMyTickets) {
      // Open directly on "my tickets" tab and mark replies as read
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyTicketsAndMarkRead());
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── DATA ─────────────────────────────────────────────

  Future<void> _loadMyTickets() async {
    setState(() => _loadingTickets = true);
    try {
      final res = await ApiService.getMyTickets();
      if (res['success'] == true) {
        setState(() {
          _myTickets      = List<Map<String, dynamic>>.from(res['tickets'] ?? []);
          _showMyTickets  = true;
          _loadingTickets = false;
        });
      }
    } catch (_) {
      setState(() => _loadingTickets = false);
    }
  }

  Future<void> _loadMyTicketsAndMarkRead() async {
    await _loadMyTickets();
    // Mark all ticket replies as read silently
    try { await ApiService.markTicketsRead(); } catch (_) {}
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('يرجى ملء جميع الحقول',
            style: DesignSystem.bodyTextStyle.copyWith(color: Colors.white)),
        backgroundColor: DesignSystem.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService.createTicket({
        'category':     _selectedCat,
        'sub_category': _selectedSub,
        'subject':      _subjectCtrl.text.trim(),
        'description':  _descCtrl.text.trim(),
        'priority':     _priority,
      });
      if (!mounted) return;
      if (res['success'] == true) {
        _showSuccessDialog(res['ticket']?['ticket_no'] ?? '');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'حدث خطأ',
              style: DesignSystem.bodyTextStyle.copyWith(color: Colors.white)),
          backgroundColor: DesignSystem.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذّر الاتصال بالخادم',
            style: DesignSystem.bodyTextStyle.copyWith(color: Colors.white)),
        backgroundColor: DesignSystem.rose,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String ticketNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: DesignSystem.bgPhone,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DesignSystem.emerald.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 56, color: DesignSystem.emerald),
            ),
            const SizedBox(height: 20),
            Text('تم إرسال التذكرة بنجاح!',
                style: DesignSystem.headingStyle.copyWith(fontSize: 18)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: DesignSystem.bgPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignSystem.borderBright),
              ),
              child: Text('رقم التذكرة: $ticketNo',
                  style: DesignSystem.headingStyle
                      .copyWith(fontSize: 15, color: DesignSystem.teal)),
            ),
            const SizedBox(height: 10),
            Text('سيتم مراجعة طلبك والرد عليك في أقرب وقت',
                style: DesignSystem.bodyTextStyle
                    .copyWith(color: DesignSystem.textMuted),
                textAlign: TextAlign.center),
          ]),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: DesignSystem.ctaGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: Text('حسناً',
                      style: DesignSystem.buttonTextStyle.copyWith(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? s) => switch (s) {
        'open'        => DesignSystem.amber,
        'in_progress' => DesignSystem.teal,
        'resolved'    => DesignSystem.emerald,
        'closed'      => DesignSystem.slate,
        _             => DesignSystem.slate,
      };

  // ── BUILD ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        floatingActionButton: (!_showMyTickets && _step == 0)
            ? _liveChatFab()
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(child: Column(
          children: [
            // TOP BAR — flat
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_showMyTickets)     setState(() => _showMyTickets = false);
                      else if (_step > 0)     setState(() => _step--);
                      else                    Navigator.pop(context);
                    },
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
                      _showMyTickets ? 'تذاكري' : 'فتح تذكرة',
                      style: DesignSystem.headingStyle.copyWith(fontSize: 17),
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadMyTicketsAndMarkRead,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: DesignSystem.teal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: DesignSystem.teal, size: 18),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // CONTENT
            Expanded(
              child: _loadingTickets
                  ? const Center(
                      child: CircularProgressIndicator(color: DesignSystem.teal))
                  : _showMyTickets
                      ? _myTicketsView()
                      : _step == 0
                          ? _categorySelection()
                          : _step == 1
                              ? _subCategorySelection()
                              : _ticketForm(),
            ),
          ],
        )),
      ),
    );
  }

  // ── CATEGORY SELECTION ───────────────────────────────

  Widget _categorySelection() {
    final cats = _categories.entries.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        Text('اختر نوع التذكرة',
            style: DesignSystem.headingStyle.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text('حدد التصنيف المناسب لطلبك',
            style: DesignSystem.bodyTextStyle.copyWith(color: DesignSystem.textMuted)),
        const SizedBox(height: 20),
        ...cats.asMap().entries.map((e) {
          final key = e.value.key;
          final cat = e.value.value;
          final c   = cat['color'] as Color;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedCat      = key;
              _selectedCatLabel = cat['label'];
              _step             = 1;
            }),
            child: Container(
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
                      color: c.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(cat['icon'] as IconData, size: 22, color: c),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat['label'] as String,
                            style: DesignSystem.headingStyle.copyWith(fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(cat['desc'] as String,
                            style: DesignSystem.smallTextStyle
                                .copyWith(color: DesignSystem.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: DesignSystem.textSubtle),
                ],
              ),
            ).animate()
                .fadeIn(delay: Duration(milliseconds: 40 * e.key), duration: 300.ms)
                .slideX(begin: 0.04, curve: DesignSystem.easeOutCurve),
          );
        }),
      ],
    );
  }

  // ── SUB-CATEGORY ─────────────────────────────────────

  Widget _subCategorySelection() {
    final subs = (_categories[_selectedCat]?['subs'] as Map<String, String>?) ?? {};
    final c    = (_categories[_selectedCat]?['color'] as Color?) ?? DesignSystem.teal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        Text(_selectedCatLabel ?? '',
            style: DesignSystem.headingStyle.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text('اختر النوع الفرعي',
            style: DesignSystem.bodyTextStyle.copyWith(color: DesignSystem.textMuted)),
        const SizedBox(height: 20),
        ...subs.entries.toList().asMap().entries.map((e) {
          final subKey   = e.value.key;
          final subLabel = e.value.value;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedSub      = subKey;
              _selectedSubLabel = subLabel;
              _step             = 2;
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignSystem.bgPhone,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: DesignSystem.borderPrimary),
              ),
              child: Row(
                children: [
                  Container(
                      width: 4, height: 34,
                      decoration: BoxDecoration(
                          color: c, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(subLabel,
                        style: DesignSystem.headingStyle.copyWith(fontSize: 14)),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: DesignSystem.textSubtle),
                ],
              ),
            ).animate()
                .fadeIn(delay: Duration(milliseconds: 60 * e.key))
                .slideX(begin: 0.08, curve: DesignSystem.easeOutCurve),
          );
        }),
      ],
    );
  }

  // ── TICKET FORM ──────────────────────────────────────

  Widget _ticketForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DesignSystem.teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DesignSystem.teal.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.label_rounded, size: 16, color: DesignSystem.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$_selectedCatLabel  ←  $_selectedSubLabel',
                      style: DesignSystem.bodyTextStyle.copyWith(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: DesignSystem.teal)),
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 20),
          Text('تفاصيل التذكرة',
              style: DesignSystem.headingStyle.copyWith(fontSize: 18)),
          const SizedBox(height: 16),

          // Subject
          TextFormField(
            controller: _subjectCtrl,
            textDirection: TextDirection.rtl,
            style: DesignSystem.bodyTextStyle,
            decoration: _inputDeco('عنوان التذكرة', 'اكتب عنواناً مختصراً',
                Icons.title_rounded, DesignSystem.blue),
          ),
          const SizedBox(height: 14),

          // Description
          TextFormField(
            controller: _descCtrl,
            textDirection: TextDirection.rtl,
            maxLines: 5,
            style: DesignSystem.bodyTextStyle,
            decoration: _inputDeco('وصف المشكلة', 'اشرح المشكلة بالتفصيل...',
                Icons.description_rounded, DesignSystem.blue),
          ),
          const SizedBox(height: 16),

          // Priority
          Text('الأولوية',
              style: DesignSystem.headingStyle.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _priorityChip('عادية',  'normal',   DesignSystem.emerald),
              const SizedBox(width: 8),
              _priorityChip('عاجلة',  'urgent',   DesignSystem.amber),
              const SizedBox(width: 8),
              _priorityChip('حرجة',   'critical', DesignSystem.rose),
            ],
          ),

          const SizedBox(height: 28),

          // Submit button
          GestureDetector(
            onTap: _isSubmitting ? null : _submit,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: DesignSystem.ctaGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: DesignSystem.ctaShadow,
              ),
              child: Center(
                child: _isSubmitting
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('إرسال التذكرة',
                            style: DesignSystem.buttonTextStyle.copyWith(fontSize: 16)),
                      ]),
              ),
            ),
          ).animate().fadeIn(delay: 180.ms).scale(
              begin: const Offset(0.96, 0.96), curve: DesignSystem.springCurve),
        ],
      ),
    );
  }

  Widget _priorityChip(String label, String value, Color color) {
    final sel = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color : DesignSystem.bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? color : DesignSystem.borderPrimary),
            boxShadow: sel ? DesignSystem.glowShadow(color, opacity: 0.3) : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: DesignSystem.bodyTextStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : DesignSystem.textMuted)),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(
          String label, String hint, IconData icon, Color accent) =>
      InputDecoration(
        labelText: label,
        labelStyle: DesignSystem.bodyTextStyle.copyWith(color: DesignSystem.textMuted),
        hintText: hint,
        hintStyle: DesignSystem.bodyTextStyle.copyWith(color: DesignSystem.textSubtle),
        prefixIcon: Icon(icon, color: accent),
        filled: true,
        fillColor: DesignSystem.bgPhone,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: DesignSystem.borderPrimary, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accent, width: 2)),
      );

  // ── MY TICKETS ───────────────────────────────────────

  // ── PHONE SUPPORT ─────────────────────────────────────

  // غيّر هذا الرقم برقم الدعم الفني الرسمي
  static const _supportPhone = 'tel:+21891264060';

  Widget _liveChatFab() {
    return GestureDetector(
      onTap: _callSupport,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: DesignSystem.emerald,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
          boxShadow: DesignSystem.ctaShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'الدعم الفني الهاتفي',
              style: DesignSystem.buttonTextStyle.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 300.ms)
        .slideY(begin: 0.5, curve: DesignSystem.easeOutCurve);
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse(_supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── MY TICKETS ───────────────────────────────────────

  Widget _myTicketsView() {
    if (_myTickets.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox_rounded, size: 56, color: DesignSystem.textSubtle),
          const SizedBox(height: 14),
          Text('لا توجد تذاكر سابقة',
              style: DesignSystem.bodyTextStyle
                  .copyWith(color: DesignSystem.textMuted)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: _myTickets.length,
      itemBuilder: (_, i) {
        final t           = _myTickets[i];
        final statusColor = _statusColor(t['status']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignSystem.bgPhone,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DesignSystem.borderPrimary),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Expanded(
                  child: Text(t['subject'] ?? '',
                      style: DesignSystem.headingStyle.copyWith(fontSize: 14)),
                ),
                if (t['reply_unread'] == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DesignSystem.rose,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('رد جديد',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(t['status_text'] ?? '',
                      style: DesignSystem.bodyTextStyle.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.confirmation_number_rounded,
                    size: 13, color: DesignSystem.textSubtle),
                const SizedBox(width: 4),
                Text(t['ticket_no'] ?? '',
                    style: DesignSystem.bodyTextStyle
                        .copyWith(color: DesignSystem.textMuted, fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: DesignSystem.textSubtle),
                const SizedBox(width: 4),
                Text(t['created_at'] ?? '',
                    style: DesignSystem.bodyTextStyle
                        .copyWith(color: DesignSystem.textMuted, fontSize: 12)),
              ],
            ),
            if (t['admin_reply'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DesignSystem.emerald.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: DesignSystem.emerald.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.reply_rounded, size: 15, color: DesignSystem.emerald),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t['admin_reply'],
                          style: DesignSystem.bodyTextStyle.copyWith(
                              fontSize: 12, color: DesignSystem.emerald)),
                    ),
                  ],
                ),
              ),
            ],
          ]),
        ).animate()
            .fadeIn(delay: Duration(milliseconds: 60 * i))
            .slideX(begin: 0.06, curve: DesignSystem.easeOutCurve);
      },
    );
  }
}
