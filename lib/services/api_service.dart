import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ── Top-level function required by compute() ─────────────────────────────────
Map<String, dynamic> _parseJson(String body) =>
    jsonDecode(body) as Map<String, dynamic>;

// ─────────────────────────────────────────────────────────────────────────────

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'انتهت الجلسة، الرجاء تسجيل الدخول مجدداً']);
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = 'http://172.20.10.4:8000/api/insured';

  // Max time to wait for any request
  static const _timeout = Duration(seconds: 15);

  /// Set from main.dart so the global 401 handler can navigate / snack.
  static GlobalKey<NavigatorState>? navigatorKey;
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  // Guard so concurrent 401s don't push /login multiple times.
  static bool _handlingUnauthorized = false;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Throws if the HTTP response status is not 200.
  static void _checkStatus(http.Response response) {
    if (response.statusCode == 401) {
      _handleUnauthorized();
      throw UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  static void _handleUnauthorized() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    // Fire-and-forget: clear creds, route to login, show a snack.
    () async {
      try {
        await AuthService.clearAll();
      } catch (_) {}
      final nav = navigatorKey?.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil('/login', (_) => false);
      }
      scaffoldMessengerKey?.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('انتهت الجلسة، الرجاء تسجيل الدخول مجدداً'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      _handlingUnauthorized = false;
    }();
  }

  /// Detects 401 (triggers global logout + throws UnauthorizedException),
  /// then runs [jsonDecode] off the UI thread.
  static Future<Map<String, dynamic>> _decode(http.Response response) {
    if (response.statusCode == 401) {
      _handleUnauthorized();
      throw UnauthorizedException();
    }
    return compute(_parseJson, response.body);
  }

  // ==================== AUTH ====================

  static Future<Map<String, dynamic>> login(
      String empNo, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'emp_no': empNo, 'password': password}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> setupProfile(
      String email, String newPin) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/setup-profile'),
          headers: await _headers(),
          body: jsonEncode({'email': email, 'new_pin': newPin}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> resetPin(
      String empNo, String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/reset-pin'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'emp_no': empNo, 'email': email}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> changePin(
      String currentPin, String newPin) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/change-pin'),
          headers: await _headers(),
          body: jsonEncode({'current_pin': currentPin, 'new_pin': newPin}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http
        .get(Uri.parse('$baseUrl/profile'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> logout() async {
    final response = await http
        .post(Uri.parse('$baseUrl/logout'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== COVERAGE ====================

  static Future<Map<String, dynamic>> getCoverageRules() async {
    final response = await http
        .get(Uri.parse('$baseUrl/coverage-rules'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== INVOICES ====================

  static Future<Map<String, dynamic>> getInvoices({
    int? cardNo,
    String? fromDate,
    String? toDate,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (cardNo != null) params['card_no'] = cardNo.toString();
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    final uri = Uri.parse('$baseUrl/invoices')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== INSURED CEILING ====================

  static Future<Map<String, dynamic>> getInsuredCeiling(
      {int? cardNo}) async {
    final uri = Uri.parse('$baseUrl/insured-ceiling').replace(
        queryParameters: cardNo != null
            ? {'card_no': cardNo.toString()}
            : null);
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== SUPPORT TICKETS ====================

  static Future<Map<String, dynamic>> getTicketCategories() async {
    final response = await http
        .get(Uri.parse('$baseUrl/ticket-categories'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> createTicket(
      Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/tickets'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> getMyTickets() async {
    final response = await http
        .get(Uri.parse('$baseUrl/my-tickets'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== PROVIDERS ====================

  static Future<Map<String, dynamic>> getProviders({String? type}) async {
    final uri = Uri.parse('$baseUrl/providers').replace(
        queryParameters: type != null ? {'type': type} : null);
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== NOTIFICATIONS ====================

  static Future<Map<String, dynamic>> getUnreadCount() async {
    final response = await http
        .get(Uri.parse('$baseUrl/unread-count'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    final response = await http
        .get(Uri.parse('$baseUrl/notifications'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> markTicketsRead() async {
    final response = await http
        .post(Uri.parse('$baseUrl/mark-tickets-read'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> markInvoicesRead() async {
    final response = await http
        .post(Uri.parse('$baseUrl/mark-invoices-read'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== ANNOUNCEMENTS ====================

  static Future<Map<String, dynamic>> getAnnouncements() async {
    final response = await http
        .get(Uri.parse('$baseUrl/announcements'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    return _decode(response);
  }

  // ==================== LIVE CHAT ====================

  static Future<Map<String, dynamic>> chatGetSession() async {
    final response = await http
        .get(Uri.parse('$baseUrl/chat/session'), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> chatPoll(
      int sessionId, int? lastMessageId) async {
    final uri = Uri.parse('$baseUrl/chat/poll').replace(queryParameters: {
      'session_id': sessionId.toString(),
      if (lastMessageId != null) 'last_message_id': lastMessageId.toString(),
    });
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> chatSendMessage(
      int sessionId, String message) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/chat/send'),
          headers: await _headers(),
          body: jsonEncode({'session_id': sessionId, 'message': message}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> chatUploadFile(
      int sessionId, String filePath, String fileName) async {
    final headers = await _headers();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/chat/upload'),
    );
    req.headers['Authorization'] = headers['Authorization'] ?? '';
    req.headers['Accept'] = 'application/json';
    req.fields['session_id'] = sessionId.toString();
    req.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    final streamed = await req.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> chatCloseSession(int sessionId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/chat/close'),
          headers: await _headers(),
          body: jsonEncode({'session_id': sessionId}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  /// يُستدعى أثناء الانتظار في الطابور - يُرجع position, est_name, est_wait_seconds, status
  static Future<Map<String, dynamic>> chatQueueStatus(int sessionId) async {
    final uri = Uri.parse('$baseUrl/chat/queue/status')
        .replace(queryParameters: {'session_id': sessionId.toString()});
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  /// إرسال تقييم المحادثة الفورية بعد إغلاقها
  static Future<Map<String, dynamic>> rateChatSession(
      int sessionId, int rating, {String? comment}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/chat/rate'),
          headers: await _headers(),
          body: jsonEncode({
            'session_id': sessionId,
            'rating': rating,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          }),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== PROVIDER RATINGS ====================

  /// جلب الزيارات التي لم يُقيَّم عليها بعد
  static Future<Map<String, dynamic>> getPendingRatings() async {
    final response = await http
        .get(Uri.parse('$baseUrl/providers/pending-ratings'),
            headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  /// إرسال تقييم مزود خدمة
  static Future<Map<String, dynamic>> rateProvider({
    required int providerId,
    required String visitDate,
    required int rating,
    String? comment,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/providers/rate'),
          headers: await _headers(),
          body: jsonEncode({
            'provider_id': providerId,
            'visit_date': visitDate,
            'rating': rating,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          }),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  // ==================== PUSH NOTIFICATIONS ====================

  static Future<Map<String, dynamic>> registerFcmToken(
      String fcmToken, String deviceId, String platform) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/notifications/register-token'),
          headers: await _headers(),
          body: jsonEncode({'token': fcmToken, 'platform': platform}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> removeFcmToken(String deviceId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/notifications/remove-token'),
          headers: await _headers(),
          body: jsonEncode({'device_id': deviceId}),
        )
        .timeout(_timeout);
    return _decode(response);
  }
}
