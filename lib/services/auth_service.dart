import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure-first auth storage with SharedPreferences fallback.
///
/// Strategy: try flutter_secure_storage with a hard timeout. If the secure
/// backend is slow/broken on the device (we hit this before on a Realme
/// device that froze on cold start), silently fall back to SharedPreferences
/// so the app still works. The token is the only sensitive value — user
/// profile stays in SharedPreferences since it's non-sensitive cache.
class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey  = 'user_data';
  static const Duration _secureTimeout = Duration(seconds: 3);

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // After one timeout/error we stop trying secure storage for this session.
  static bool _secureDisabled = false;

  static Future<T?> _trySecure<T>(Future<T?> Function() op) async {
    if (_secureDisabled) return null;
    try {
      return await op().timeout(_secureTimeout);
    } catch (_) {
      _secureDisabled = true;
      return null;
    }
  }

  // ── TOKEN ─────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final ok = await _trySecure<bool>(() async {
      await _secure.write(key: _tokenKey, value: token);
      return true;
    });
    final prefs = await SharedPreferences.getInstance();
    if (ok == true) {
      // Remove the plaintext copy once secure write succeeded.
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  static Future<String?> getToken() async {
    final secureVal = await _trySecure<String?>(() => _secure.read(key: _tokenKey));
    if (secureVal != null) return secureVal;

    // Lazy migration: if we still have a plaintext token, move it.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null && !_secureDisabled) {
      final migrated = await _trySecure<bool>(() async {
        await _secure.write(key: _tokenKey, value: legacy);
        return true;
      });
      if (migrated == true) {
        await prefs.remove(_tokenKey);
      }
    }
    return legacy;
  }

  // ── USER (non-sensitive cache) ────────────────────────

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) return jsonDecode(userStr);
    return null;
  }

  static Future<void> clearAll() async {
    await _trySecure<bool>(() async {
      await _secure.delete(key: _tokenKey);
      return true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
