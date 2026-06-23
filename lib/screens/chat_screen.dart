import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_system.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  int?   _sessionId;
  String _status           = 'active';
  bool   _isLoading        = true;
  bool   _isSending        = false;
  bool   _isPolling        = false;
  bool   _isUploading      = false;
  int?   _lastMessageId;
  Timer? _pollTimer;
  Timer? _idleTimer;
  Timer? _queueTimer;
  DateTime _lastUserAction = DateTime.now();
  static const _idleTimeout = Duration(minutes: 10);
  final Set<int> _seenIds  = {};

  // ── Queue state ──────────────────────────────────────────
  int    _queuePosition   = 0;
  String _estName         = 'الدعم العام';
  int    _estWaitSeconds  = 0;

  final _imagePicker = ImagePicker();

  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _idleTimer?.cancel();
    _queueTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.chatGetSession();
      if (res['success'] == true) {
        final status = res['status'] ?? 'active';
        if (status == 'queued') {
          // ── وضع الطابور ──
          setState(() {
            _sessionId      = res['session_id'];
            _status         = 'queued';
            _queuePosition  = (res['queue_position'] as num?)?.toInt() ?? 0;
            _estName        = res['est_name'] as String? ?? 'الدعم العام';
            _estWaitSeconds = (res['est_wait_seconds'] as num?)?.toInt() ?? 0;
            _isLoading      = false;
          });
          _startQueuePolling();
        } else {
          setState(() {
            _sessionId = res['session_id'];
            _status    = status;
            final msgs = List<Map<String, dynamic>>.from(res['messages'] ?? []);
            _messages.addAll(msgs);
            for (final m in msgs) {
              if (m['id'] != null) _seenIds.add(m['id'] as int);
            }
            if (_messages.isNotEmpty) _lastMessageId = _messages.last['id'];
            _isLoading = false;
          });
          _scrollToBottom();
          _startPolling();
        }
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── Queue polling ────────────────────────────────────────
  void _startQueuePolling() {
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollQueue());
  }

  Future<void> _pollQueue() async {
    if (_sessionId == null || _status != 'queued') return;
    try {
      final res = await ApiService.chatQueueStatus(_sessionId!);
      if (!mounted) return;
      if (res['success'] == true) {
        final newStatus = res['status'] as String? ?? 'queued';
        if (newStatus == 'active') {
          // الموظف متاح الآن - انتقل للمحادثة
          _queueTimer?.cancel();
          setState(() {
            _status    = 'active';
            _isLoading = false;
          });
          _startPolling();
        } else {
          setState(() {
            _queuePosition  = (res['position'] as num?)?.toInt() ?? _queuePosition;
            _estWaitSeconds = (res['est_wait_seconds'] as num?)?.toInt() ?? _estWaitSeconds;
            _estName        = res['est_name'] as String? ?? _estName;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _cancelQueue() async {
    _queueTimer?.cancel();
    if (_sessionId != null) {
      try { await ApiService.chatCloseSession(_sessionId!); } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _idleTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _idleTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkIdle());
  }

  void _checkIdle() {
    if (_status != 'active') return;
    if (DateTime.now().difference(_lastUserAction) >= _idleTimeout) {
      _pollTimer?.cancel();
      _idleTimer?.cancel();
      if (mounted) setState(() => _status = 'idle_closed');
    }
  }

  void _resetIdleTimer() {
    _lastUserAction = DateTime.now();
  }

  Future<void> _poll() async {
    if (_sessionId == null || _status == 'closed' || _status == 'idle_closed' || _isPolling) return;
    _isPolling = true;
    try {
      final res = await ApiService.chatPoll(_sessionId!, _lastMessageId);
      if (!mounted) return;
      if (res['success'] == true) {
        final all = List<Map<String, dynamic>>.from(res['messages'] ?? []);
        final newMsgs = all.where((m) {
          final id = m['id'];
          if (id == null) return true;
          return _seenIds.add(id as int);
        }).toList();
        if (newMsgs.isNotEmpty) {
          setState(() {
            _messages.addAll(newMsgs);
            _lastMessageId = newMsgs.last['id'];
          });
          _scrollToBottom();
        }
        final newStatus = res['status'] ?? 'active';
        // Server-side timeout or agent closed chat → show rating
        if (newStatus == 'closed' && _status == 'active') {
          _pollTimer?.cancel();
          _idleTimer?.cancel();
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) _showChatRatingDialog();
          });
        }
        if (newStatus != _status) setState(() => _status = newStatus);
      }
    } catch (_) {
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sessionId == null || _isSending) return;
    _resetIdleTimer();
    _msgCtrl.clear();
    setState(() => _isSending = true);

    final optimistic = {
      'id'          : null,
      'sender_type' : 'insured',
      'message'     : text,
      'time'        : _nowTime(),
      'date'        : _nowDate(),
      'pending'     : true,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final res = await ApiService.chatSendMessage(_sessionId!, text);
      if (!mounted) return;
      if (res['success'] == true) {
        final idx = _messages.indexOf(optimistic);
        if (idx != -1) {
          final confirmed = Map<String, dynamic>.from(res['message'] as Map)
            ..remove('pending');
          final confirmedId = confirmed['id'];
          if (confirmedId != null) _seenIds.add(confirmedId as int);
          setState(() {
            _messages[idx] = confirmed;
            _lastMessageId = confirmedId as int?;
          });
        }
      } else {
        setState(() => _messages.remove(optimistic));
        _showError('تعذّر إرسال الرسالة');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messages.remove(optimistic));
        _showError('تعذّر الاتصال بالخادم');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _uploadFile(String path, String name) async {
    if (_sessionId == null) return;
    setState(() => _isUploading = true);
    try {
      final res = await ApiService.chatUploadFile(_sessionId!, path, name);
      if (!mounted) return;
      if (res['success'] == true) {
        final msg = Map<String, dynamic>.from(res['message'] as Map);
        final msgId = msg['id'];
        if (msgId != null) _seenIds.add(msgId as int);
        setState(() {
          _messages.add(msg);
          _lastMessageId = msgId as int?;
        });
        _scrollToBottom();
      } else {
        _showError('تعذّر رفع الملف');
      }
    } catch (_) {
      if (mounted) _showError('تعذّر الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignSystem.bgPhone,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(
                color: DesignSystem.borderPrimary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              _attachOption(Icons.camera_alt_rounded, 'الكاميرا', () async {
                Navigator.pop(context);
                try {
                  final img = await _imagePicker.pickImage(
                      source: ImageSource.camera, imageQuality: 85);
                  if (img != null && mounted) _uploadFile(img.path, img.name);
                } catch (_) {
                  if (mounted) _showError('تعذّر فتح الكاميرا');
                }
              }),
              _attachOption(Icons.photo_library_rounded, 'معرض الصور', () async {
                Navigator.pop(context);
                try {
                  final img = await _imagePicker.pickImage(
                      source: ImageSource.gallery, imageQuality: 85);
                  if (img != null && mounted) _uploadFile(img.path, img.name);
                } catch (_) {
                  if (mounted) _showError('تعذّر فتح معرض الصور');
                }
              }),
              _attachOption(Icons.picture_as_pdf_rounded, 'ملف PDF', () async {
                Navigator.pop(context);
                try {
                  final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom, allowedExtensions: ['pdf']);
                  if (result != null &&
                      result.files.single.path != null &&
                      mounted) {
                    _uploadFile(
                        result.files.single.path!, result.files.single.name);
                  }
                } catch (_) {
                  if (mounted) _showError('تعذّر اختيار الملف');
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: DesignSystem.emerald.withAlpha(30),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: DesignSystem.emerald, size: 20),
        ),
        title: Text(label, style: DesignSystem.bodyTextStyle),
        onTap: onTap,
      );

  // ── Chat Rating Dialog ───────────────────────────────────
  Future<void> _showChatRatingDialog() async {
    if (_sessionId == null || !mounted) return;
    int selectedRating  = 0;
    final commentCtrl   = TextEditingController();
    bool submitting     = false;

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
                Text('قيّم المحادثة',
                    style: DesignSystem.headingStyle.copyWith(fontSize: 18),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  'كيف كانت تجربتك مع فريق الدعم؟',
                  style: DesignSystem.bodyTextStyle.copyWith(
                      color: DesignSystem.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedRating = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          star <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: DesignSystem.amber,
                          size: 36,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Comment
                Container(
                  decoration: BoxDecoration(
                    color: DesignSystem.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DesignSystem.borderPrimary),
                  ),
                  child: TextField(
                    controller: commentCtrl,
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                      hintText: 'تعليق اختياري...',
                      hintStyle: DesignSystem.bodyTextStyle.copyWith(
                          color: DesignSystem.textSubtle, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: Text('تخطي',
                    style: DesignSystem.bodyTextStyle.copyWith(
                        color: DesignSystem.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignSystem.teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (submitting || selectedRating == 0)
                    ? null
                    : () async {
                        // أغلق الكيبورد قبل الإرسال لتجنب assertion خاص بـ InheritedWidget
                        FocusManager.instance.primaryFocus?.unfocus();
                        setDialogState(() => submitting = true);
                        try {
                          await ApiService.rateChatSession(
                            _sessionId!,
                            selectedRating,
                            comment: commentCtrl.text.trim(),
                          );
                        } catch (_) {}
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: submitting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('إرسال التقييم',
                        style: DesignSystem.buttonTextStyle.copyWith(
                            fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: DesignSystem.bodyTextStyle.copyWith(color: Colors.white)),
      backgroundColor: DesignSystem.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _nowTime() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _nowDate() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ── BUILD ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(child: Column(
          children: [
            _header(),
            Expanded(
              child: _isLoading
                  ? _loader()
                  : _status == 'queued'
                      ? _queueScreen()
                      : _messageList(),
            ),
            if (_status == 'active') _inputBar(),
            if (_status == 'closed' || _status == 'idle_closed') _closedBanner(),
          ],
        )),
      ),
    );
  }

  // ── Queue Screen ─────────────────────────────────────────
  Widget _queueScreen() {
    final minutes = (_estWaitSeconds / 60).ceil();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // أيقونة الانتظار
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: DesignSystem.amber.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: DesignSystem.amber, size: 40),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.95, end: 1.05, duration: 900.ms, curve: Curves.easeInOut),
          const SizedBox(height: 20),
          Text(
            'جميع الموظفين مشغولون حالياً',
            style: DesignSystem.headingStyle.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'أنت في الطابور، سيتم ربطك بالموظف تلقائياً',
            style: DesignSystem.smallTextStyle.copyWith(
                color: DesignSystem.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // رقم الطابور
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignSystem.bgBody,
              borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
              border: Border.all(color: DesignSystem.borderPrimary),
              boxShadow: DesignSystem.cardShadow,
            ),
            child: Column(
              children: [
                Text('رقمك في الطابور',
                    style: DesignSystem.smallTextStyle.copyWith(
                        color: DesignSystem.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(
                  '$_queuePosition',
                  style: DesignSystem.headingStyle.copyWith(
                    fontSize: 56,
                    color: DesignSystem.teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _queueInfoChip(
                        Icons.support_agent_rounded, _estName, DesignSystem.teal),
                    if (_estWaitSeconds > 0)
                      _queueInfoChip(Icons.timer_outlined,
                          '~$minutes دقيقة', DesignSystem.amber),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // مؤشر التحميل
          const CircularProgressIndicator(
              color: DesignSystem.teal, strokeWidth: 2),
          const SizedBox(height: 12),
          Text(
            'جارٍ البحث عن موظف متاح...',
            style: DesignSystem.smallTextStyle.copyWith(
                color: DesignSystem.textSubtle, fontSize: 11),
          ),

          const SizedBox(height: 36),

          // زر الإلغاء
          GestureDetector(
            onTap: _cancelQueue,
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: DesignSystem.bgBody,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DesignSystem.rose.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(
                  'إلغاء الانتظار',
                  style: DesignSystem.buttonTextStyle.copyWith(
                      color: DesignSystem.rose, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _queueInfoChip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: DesignSystem.labelStyle.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      );

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: DesignSystem.bgBody,
          border: Border(
            bottom: BorderSide(color: DesignSystem.borderPrimary, width: 1),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: DesignSystem.bgPrimary,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                  border: Border.all(color: DesignSystem.borderPrimary),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: DesignSystem.textPrimary, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: DesignSystem.tealGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: DesignSystem.avatarShadow,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('المحادثة الفورية',
                      style: DesignSystem.headingStyle.copyWith(fontSize: 15)),
                  Row(
                    children: [
                      if (_status == 'active' || _status == 'queued') _statusDot(),
                      if (_status == 'active' || _status == 'queued') const SizedBox(width: 6),
                      Text(
                        _status == 'active'
                            ? 'فريق الدعم متاح'
                            : _status == 'queued'
                                ? 'في الطابور - رقم $_queuePosition'
                                : 'المحادثة مغلقة',
                        style: DesignSystem.labelStyle.copyWith(
                          color: _status == 'active'
                              ? DesignSystem.emerald
                              : _status == 'queued'
                                  ? DesignSystem.amber
                                  : DesignSystem.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);

  Widget _statusDot() => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: _status == 'queued' ? DesignSystem.amber : DesignSystem.emerald,
          shape: BoxShape.circle,
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .fadeIn(duration: 800.ms)
          .then()
          .fadeOut(duration: 800.ms);

  Widget _loader() =>
      const Center(child: CircularProgressIndicator(color: DesignSystem.teal, strokeWidth: 2));

  Widget _messageList() {
    if (_messages.isEmpty) return _emptyState();
    String? lastDate;
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m    = _messages[i];
        final date = m['date'] as String? ?? '';
        final showDate = date != lastDate;
        lastDate = date;
        return Column(children: [
          if (showDate) _dateDivider(date),
          _bubble(m, i),
        ]);
      },
    );
  }

  static const _faqs = [
    'ما هو حد تغطيتي التأمينية؟',
    'كيف أضيف أحد أفراد العائلة؟',
    'ما هي المستشفيات المعتمدة في منطقتي؟',
    'كيف أعترض على فاتورة؟',
    'ما مبلغ التحمّل الخاص بي؟',
    'كيف أرفع شكوى؟',
    'متى يتم تحديث فواتيري؟',
    'كيف أحصل على موافقة مسبقة؟',
  ];

  Widget _emptyState() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 52, color: DesignSystem.textSubtle),
            const SizedBox(height: 12),
            Text('ابدأ المحادثة مع فريق الدعم',
                style: DesignSystem.bodyTextStyle
                    .copyWith(color: DesignSystem.textMuted)),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الأسئلة الشائعة',
                style: DesignSystem.labelStyle.copyWith(
                    color: DesignSystem.textSubtle,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _faqs.map((q) {
                return GestureDetector(
                  onTap: () {
                    _msgCtrl.text = q;
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: DesignSystem.bgBody,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignSystem.teal.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline_rounded,
                            size: 13, color: DesignSystem.teal),
                        const SizedBox(width: 6),
                        Text(q,
                            style: DesignSystem.labelStyle.copyWith(
                                color: DesignSystem.textPrimary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  Widget _dateDivider(String date) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Divider(color: DesignSystem.borderPrimary)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(date,
                style: DesignSystem.bodyTextStyle
                    .copyWith(fontSize: 11, color: DesignSystem.textSubtle)),
          ),
          Expanded(child: Divider(color: DesignSystem.borderPrimary)),
        ]),
      );

  Widget _bubble(Map<String, dynamic> m, int i) {
    final isMe    = m['sender_type'] == 'insured';
    final pending = m['pending'] == true;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? DesignSystem.teal : DesignSystem.bgBody,
          borderRadius: BorderRadius.only(
            topRight: const Radius.circular(16),
            topLeft: const Radius.circular(16),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
          ),
          border: isMe ? null : Border.all(color: DesignSystem.borderPrimary),
          boxShadow: DesignSystem.cardShadow,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (m['file_type'] == 'image' && m['file_url'] != null)
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(m['file_url'] as String),
                    mode: LaunchMode.externalApplication),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    m['file_url'] as String,
                    width: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : SizedBox(
                            width: 200, height: 120,
                            child: Center(child: CircularProgressIndicator(
                              color: DesignSystem.emerald, strokeWidth: 2))),
                    errorBuilder: (_, e, s) => const Icon(
                        Icons.broken_image_rounded, color: Colors.white54),
                  ),
                ),
              )
            else if (m['file_type'] == 'pdf' && m['file_url'] != null)
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(m['file_url'] as String),
                    mode: LaunchMode.externalApplication),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: isMe ? Colors.white70 : DesignSystem.rose, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(
                      m['file_name'] as String? ?? 'ملف PDF',
                      style: DesignSystem.bodyTextStyle.copyWith(
                        fontSize: 13,
                        color: isMe ? Colors.white : DesignSystem.textPrimary,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ],
                ),
              )
            else
              Text(
                m['message'] as String? ?? '',
                textDirection: TextDirection.rtl,
                style: DesignSystem.bodyTextStyle.copyWith(
                  fontSize: 14,
                  color: isMe ? Colors.white : DesignSystem.textPrimary,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m['time'] as String? ?? '',
                  style: DesignSystem.bodyTextStyle.copyWith(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withAlpha(166)
                        : DesignSystem.textSubtle,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    pending
                        ? Icons.access_time_rounded
                        : Icons.done_all_rounded,
                    size: 13,
                    color: pending
                        ? Colors.white54
                        : Colors.white.withAlpha(191),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (i * 20).ms).slideY(begin: 0.05);
  }

  Widget _inputBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        decoration: BoxDecoration(
          color: DesignSystem.bgPhone,
          border: Border(top: BorderSide(color: DesignSystem.borderPrimary)),
        ),
        child: Row(
          children: [
            // Attach button
            GestureDetector(
              onTap: _isUploading ? null : _showAttachmentPicker,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DesignSystem.emerald.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DesignSystem.emerald.withAlpha(80)),
                ),
                child: _isUploading
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                            color: DesignSystem.emerald, strokeWidth: 2))
                    : const Icon(Icons.attach_file_rounded,
                        color: DesignSystem.emerald, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: DesignSystem.bgPrimary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DesignSystem.borderPrimary),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  focusNode: _focusNode,
                  textDirection: TextDirection.rtl,
                  style: DesignSystem.bodyTextStyle.copyWith(fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'اكتب رسالة...',
                    hintStyle: DesignSystem.bodyTextStyle.copyWith(
                        color: DesignSystem.textSubtle, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: DesignSystem.teal,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
                  boxShadow: DesignSystem.ctaShadow,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );

  Widget _closedBanner() => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        color: DesignSystem.bgPhone,
        child: Column(
          children: [
            Text(
              _status == 'idle_closed'
                  ? 'انتهت الجلسة بسبب عدم النشاط (10 دقائق)'
                  : 'تم إغلاق هذه المحادثة',
              style: DesignSystem.bodyTextStyle.copyWith(
                color: _status == 'idle_closed'
                    ? DesignSystem.amber
                    : DesignSystem.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  _messages.clear();
                  _lastMessageId = null;
                  _sessionId = null;
                  _status    = 'active';
                  _isLoading = true;
                });
                _initSession();
              },
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  gradient: DesignSystem.ctaGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('بدء محادثة جديدة',
                      style:
                          DesignSystem.buttonTextStyle.copyWith(fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      );
}
