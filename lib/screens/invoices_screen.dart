import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/design_system.dart';
import '../services/api_service.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _familyFilter = [];
  int?     _selectedCardNo;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool     _isLoading    = true;
  bool     _selectionMode = false;
  final Set<String> _selectedIds = {};

  static const int _perPage = 20;
  int  _page    = 1;
  int  _total   = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadInvoices();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        _hasMore &&
        !_isLoadingMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });
    try {
      final result = await ApiService.getInvoices(
        cardNo:   _selectedCardNo,
        fromDate: _fromDate != null ? _fmtDate(_fromDate!) : null,
        toDate:   _toDate   != null ? _fmtDate(_toDate!)   : null,
        page: 1,
        perPage: _perPage,
      );
      if (result['success'] == true) {
        final pg = result['pagination'] as Map<String, dynamic>?;
        setState(() {
          _invoices = List<Map<String, dynamic>>.from(result['invoices'] ?? []);
          if (_familyFilter.isEmpty) {
            _familyFilter = List<Map<String, dynamic>>.from(result['family_filter'] ?? []);
          }
          _total   = (pg?['total'] as num?)?.toInt() ?? _invoices.length;
          _hasMore = pg?['has_more'] == true;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final next = _page + 1;
      final result = await ApiService.getInvoices(
        cardNo:   _selectedCardNo,
        fromDate: _fromDate != null ? _fmtDate(_fromDate!) : null,
        toDate:   _toDate   != null ? _fmtDate(_toDate!)   : null,
        page: next,
        perPage: _perPage,
      );
      if (result['success'] == true) {
        final pg = result['pagination'] as Map<String, dynamic>?;
        final more = List<Map<String, dynamic>>.from(result['invoices'] ?? []);
        setState(() {
          _invoices.addAll(more);
          _page    = next;
          _total   = (pg?['total'] as num?)?.toInt() ?? _total;
          _hasMore = pg?['has_more'] == true;
        });
      }
    } catch (_) {
      // silently ignore; user can scroll again to retry
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool _isIndividual(Map<String, dynamic> inv) {
    final raw = inv['id_clint'];
    if (raw == null) {
      final p = (inv['provider'] ?? '').toString().trim();
      return p.isEmpty;
    }
    return int.tryParse(raw.toString()) == 0;
  }

  String _providerLabel(Map<String, dynamic> inv) {
    if (_isIndividual(inv)) return 'فاتورة فردية';
    final p = (inv['provider'] ?? '').toString().trim();
    return p.isEmpty ? 'عام' : p;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_fromDate ?? now) : (_toDate ?? now),
      firstDate: DateTime(2015),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: DesignSystem.teal,
            surface: DesignSystem.bgBody,
            onSurface: DesignSystem.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) { _fromDate = picked; } else { _toDate = picked; }
      });
      _loadInvoices();
    }
  }

  void _clearDateFilter() {
    setState(() { _fromDate = null; _toDate = null; });
    _loadInvoices();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _copyInvoiceId(dynamic id) async {
    final text = id?.toString() ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'تم نسخ رقم الفاتورة #$text',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: DesignSystem.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _exitSelectionMode() {
    setState(() { _selectionMode = false; _selectedIds.clear(); });
  }

  Future<void> _printSelectedInvoices() async {
    final selected = _invoices
        .where((inv) => _selectedIds.contains(inv['id'].toString()))
        .toList();
    if (selected.isEmpty) return;

    // Show loading indicator while generating PDF
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: DesignSystem.teal)),
    );

    try {
      final doc      = pw.Document();
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBold = await PdfGoogleFonts.cairoBold();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
          header: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'إجمالي الفواتير: ${selected.length}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 11,
                      color: PdfColors.grey600),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'سجل الفواتير الطبية',
                  style: pw.TextStyle(font: arabicBold, fontSize: 16,
                      color: PdfColors.teal700),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
              style: pw.TextStyle(font: arabicFont, fontSize: 10,
                  color: PdfColors.grey400),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
          build: (ctx) => selected
              .map((inv) => _buildInvoicePdfRow(inv, arabicFont, arabicBold))
              .toList(),
        ),
      );

      final bytes = await doc.save();

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PdfPreviewScreen(
            title: 'فواتير طبية (${selected.length})',
            pdfBytes: Uint8List.fromList(bytes),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذّر توليد ملف PDF'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  pw.Widget _buildInvoicePdfRow(
      Map<String, dynamic> inv, pw.Font font, pw.Font bold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(inv['date'] ?? '', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey600)),
              pw.Text(
                _providerLabel(inv),
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 12,
                  color: _isIndividual(inv) ? PdfColors.amber700 : PdfColors.teal700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(inv['beneficiary_name'] ?? '', style: pw.TextStyle(font: bold, fontSize: 13), textDirection: pw.TextDirection.rtl),
          pw.SizedBox(height: 3),
          pw.Text(inv['service'] ?? '', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey600), textDirection: pw.TextDirection.rtl),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfAmountCol('الإجمالي',    inv['value'],         PdfColors.grey800, font, bold),
              _pdfAmountCol('حصة الشركة',  inv['value_company'], PdfColors.teal700, font, bold),
              _pdfAmountCol('حصة الموظف',  inv['value_emp'],     PdfColors.amber700, font, bold),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfAmountCol(String label, dynamic val, PdfColor color,
      pw.Font font, pw.Font bold) =>
      pw.Column(children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey500),
            textDirection: pw.TextDirection.rtl),
        pw.SizedBox(height: 3),
        pw.Text('${val ?? 0} د.ل',
            style: pw.TextStyle(font: bold, fontSize: 12, color: color),
            textDirection: pw.TextDirection.rtl),
      ]);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              // ── TOP BAR — flat & clean ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  children: [
                    _selectionMode
                        ? GestureDetector(
                            onTap: _exitSelectionMode,
                            child: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: DesignSystem.bgBody,
                                borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                                border: Border.all(color: DesignSystem.borderPrimary),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: DesignSystem.textPrimary, size: 18),
                            ),
                          )
                        : _backBtn(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectionMode
                            ? '${_selectedIds.length} محدد'
                            : 'سجل الفواتير',
                        style: DesignSystem.headingStyle.copyWith(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectionMode)
                      if (_selectedIds.isNotEmpty)
                        GestureDetector(
                          onTap: _printSelectedInvoices,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: DesignSystem.teal,
                              borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
                              boxShadow: DesignSystem.ctaShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text('طباعة (${_selectedIds.length})',
                                    style: DesignSystem.buttonTextStyle.copyWith(fontSize: 12)),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: DesignSystem.bgBody,
                            borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                            border: Border.all(color: DesignSystem.borderPrimary),
                          ),
                          child: Text('اختر فواتير',
                              style: DesignSystem.labelStyle.copyWith(
                                  color: DesignSystem.textMuted)),
                        )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _selectionMode = true),
                            child: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: DesignSystem.teal.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                              ),
                              child: const Icon(Icons.print_rounded,
                                  color: DesignSystem.teal, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _countBadge(),
                        ],
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              // ── FILTERS ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  children: [
                    _familyDropdown(),
                    const SizedBox(height: 8),
                    _dateFilterRow(),
                  ],
                ),
              ),

              // ── LIST ──
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DesignSystem.teal, strokeWidth: 2))
                    : _invoices.isEmpty
                        ? _emptyState()
                        : RefreshIndicator(
                            color: DesignSystem.teal,
                            backgroundColor: DesignSystem.bgBody,
                            onRefresh: _loadInvoices,
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              itemCount: _invoices.length + (_hasMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= _invoices.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const SizedBox(
                                              width: 22, height: 22,
                                              child: CircularProgressIndicator(
                                                  color: DesignSystem.teal,
                                                  strokeWidth: 2),
                                            )
                                          : const SizedBox(height: 22),
                                    ),
                                  );
                                }
                                return _invoiceCard(_invoices[i], i);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER WIDGETS ───────────────────────────────────

  Widget _backBtn() => GestureDetector(
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
      );

  Widget _countBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: DesignSystem.teal.withOpacity(0.10),
          borderRadius: BorderRadius.circular(DesignSystem.radiusPill),
        ),
        child: Text(
          '${_total > 0 ? _total : _invoices.length} فاتورة',
          style: DesignSystem.labelStyle.copyWith(
              color: DesignSystem.teal, fontWeight: FontWeight.w700),
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
            dropdownColor: DesignSystem.bgBody,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: DesignSystem.teal, size: 20),
            style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13),
            items: [
              DropdownMenuItem(
                value: null,
                child: Row(children: [
                  const Icon(Icons.groups_rounded,
                      color: DesignSystem.teal, size: 16),
                  const SizedBox(width: 8),
                  Text('جميع أفراد العائلة',
                      style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13)),
                ]),
              ),
              ..._familyFilter.map((f) => DropdownMenuItem(
                    value: int.tryParse(f['card_no'].toString()),
                    child: Row(children: [
                      const Icon(Icons.person_rounded,
                          color: DesignSystem.teal, size: 16),
                      const SizedBox(width: 8),
                      Text(f['name'] ?? '',
                          style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13)),
                    ]),
                  )),
            ],
            onChanged: (v) {
              setState(() => _selectedCardNo = v);
              _loadInvoices();
            },
          ),
        ),
      );

  Widget _dateFilterRow() => Row(
        children: [
          Expanded(child: _dateBtn(
            label: _fromDate != null ? _displayDate(_fromDate!) : 'من تاريخ',
            hasValue: _fromDate != null,
            onTap: () => _pickDate(isFrom: true),
          )),
          const SizedBox(width: 8),
          Expanded(child: _dateBtn(
            label: _toDate != null ? _displayDate(_toDate!) : 'إلى تاريخ',
            hasValue: _toDate != null,
            onTap: () => _pickDate(isFrom: false),
          )),
          if (_fromDate != null || _toDate != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _clearDateFilter,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DesignSystem.rose.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignSystem.rose.withAlpha(60)),
                ),
                child: Icon(Icons.clear_rounded, color: DesignSystem.rose, size: 16),
              ),
            ),
          ],
        ],
      );

  Widget _dateBtn({required String label, required bool hasValue, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hasValue ? DesignSystem.teal.withAlpha(30) : DesignSystem.bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: hasValue ? DesignSystem.teal.withAlpha(80) : DesignSystem.borderPrimary),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 13,
                  color: hasValue ? DesignSystem.teal : DesignSystem.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: DesignSystem.bodyTextStyle.copyWith(
                        fontSize: 11,
                        color: hasValue ? DesignSystem.teal : DesignSystem.textMuted),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );

  // ── INVOICE CARD ─────────────────────────────────────

  Widget _invoiceCard(Map<String, dynamic> inv, int i) {
    final id       = inv['id'].toString();
    final selected = _selectedIds.contains(id);

    return GestureDetector(
      onLongPress: () {
        setState(() { _selectionMode = true; _selectedIds.add(id); });
      },
      onTap: _selectionMode ? () => _toggleSelection(id) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selected
              ? DesignSystem.teal.withOpacity(0.06)
              : DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(
            color: selected
                ? DesignSystem.teal.withOpacity(0.40)
                : DesignSystem.borderPrimary,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: DesignSystem.cardShadow,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Top: date + provider + name + service
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 12, color: DesignSystem.textMuted),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    inv['date'] ?? '',
                                    style: DesignSystem.bodyTextStyle.copyWith(
                                        color: DesignSystem.textMuted, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _copyInvoiceId(inv['id']),
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '#${inv['id']}',
                                        style: DesignSystem.bodyTextStyle
                                            .copyWith(
                                          color: DesignSystem.teal,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 10,
                                        color: DesignSystem.teal
                                            .withOpacity(0.75),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: _pill(
                                _providerLabel(inv),
                                _isIndividual(inv) ? DesignSystem.amber : DesignSystem.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        inv['beneficiary_name'] ?? '',
                        style: DesignSystem.bodyTextStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DesignSystem.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inv['service'] ?? '',
                        style: DesignSystem.bodyTextStyle
                            .copyWith(color: DesignSystem.textMuted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                Divider(color: DesignSystem.borderPrimary, height: 1),

                // Bottom: amounts
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      _amountCol('الإجمالي',   inv['value'],         DesignSystem.textPrimary),
                      _dividerV(),
                      _amountCol('حصة الشركة', inv['value_company'], DesignSystem.teal),
                      _dividerV(),
                      _amountCol('حصة الموظف', inv['value_emp'],     DesignSystem.amber),
                    ],
                  ),
                ),
              ],
            ),

            // Selection checkbox overlay
            if (_selectionMode)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: selected ? DesignSystem.teal : DesignSystem.bgBody,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? DesignSystem.teal : DesignSystem.borderBright,
                        width: 2),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (i * 40).ms, duration: 300.ms).slideY(begin: 0.04, curve: DesignSystem.easeOutCurve);
  }

  Widget _amountCol(String label, dynamic val, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: DesignSystem.labelStyle.copyWith(
                  color: DesignSystem.textSubtle),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 5),
            Text(
              '${val ?? 0}',
              textDirection: TextDirection.ltr,
              style: DesignSystem.bodyTextStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              'د.ل',
              style: DesignSystem.labelStyle.copyWith(
                  color: color.withOpacity(0.6)),
            ),
          ],
        ),
      );

  Widget _dividerV() => Container(width: 1, height: 36, color: DesignSystem.borderPrimary);

  Widget _pill(String text, Color color) => Tooltip(
        message: text,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 3),
        preferBelow: false,
        textAlign: TextAlign.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: DesignSystem.bodyTextStyle.copyWith(
          color: DesignSystem.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: DesignSystem.bodyTextStyle
                .copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );

  Widget _emptyState() => Center(
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
                child: const Icon(Icons.receipt_long_outlined,
                    size: 44, color: DesignSystem.teal),
              ),
              const SizedBox(height: 16),
              Text('لا توجد فواتير',
                  style: DesignSystem.headingStyle.copyWith(fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                'ستظهر فواتيرك الطبية هنا تلقائياً\nعند تسجيلها من مزود الخدمة',
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

class _PdfPreviewScreen extends StatelessWidget {
  final String title;
  final Uint8List pdfBytes;
  const _PdfPreviewScreen({required this.title, required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        backgroundColor: DesignSystem.bgPhone,
        foregroundColor: DesignSystem.textPrimary,
        elevation: 0,
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: 'فواتير_طبية_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
  }
}
