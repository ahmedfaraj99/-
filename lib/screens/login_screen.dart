import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/design_system.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empNoController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePin      = true;
  bool _isResetting     = false;
  final _resetEmpCtrl   = TextEditingController();
  final _resetEmailCtrl = TextEditingController();

  @override
  void dispose() {
    _empNoController.dispose();
    _pinController.dispose();
    _resetEmpCtrl.dispose();
    _resetEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        _empNoController.text.trim(),
        _pinController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await AuthService.saveToken(result['token']);
        await AuthService.saveUser(result['user']);

        try {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await ApiService.registerFcmToken(fcmToken, 'device_id', 'android');
          }
        } catch (e) {
          debugPrint('Error registering FCM token on login: $e');
        }
        
        if (result['requires_setup'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        _showError(result['message'] ?? 'خطأ في تسجيل الدخول');
      }
    } catch (e) {
      _showError('تعذّر الاتصال بالخادم. تأكد من اتصال الإنترنت.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: DesignSystem.bodyTextStyle),
        backgroundColor: DesignSystem.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: DesignSystem.bodyTextStyle.copyWith(color: Colors.white)),
        backgroundColor: DesignSystem.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showForgotPinDialog() {
    _resetEmpCtrl.clear();
    _resetEmailCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor: DesignSystem.bgPhone,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [
              const Icon(Icons.lock_reset_rounded, color: DesignSystem.blue, size: 22),
              const SizedBox(width: 10),
              Text('نسيت الرمز السري',
                  style: DesignSystem.headingStyle.copyWith(fontSize: 17)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('أدخل رقمك الوظيفي والبريد الإلكتروني المسجّل',
                  style: DesignSystem.bodyTextStyle
                      .copyWith(color: DesignSystem.textMuted, fontSize: 13)),
              const SizedBox(height: 18),
              TextField(
                controller: _resetEmpCtrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                style: DesignSystem.bodyTextStyle,
                decoration: InputDecoration(
                  labelText: 'الرقم الوظيفي',
                  labelStyle: DesignSystem.bodyTextStyle
                      .copyWith(color: DesignSystem.textMuted),
                  prefixIcon: const Icon(Icons.badge_outlined,
                      color: DesignSystem.blue, size: 20),
                  filled: true,
                  fillColor: DesignSystem.bgPrimary,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: DesignSystem.borderPrimary)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resetEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                style: DesignSystem.bodyTextStyle,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  labelStyle: DesignSystem.bodyTextStyle
                      .copyWith(color: DesignSystem.textMuted),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: DesignSystem.blue, size: 20),
                  filled: true,
                  fillColor: DesignSystem.bgPrimary,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: DesignSystem.borderPrimary)),
                ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء',
                    style: DesignSystem.bodyTextStyle
                        .copyWith(color: DesignSystem.textMuted)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: DesignSystem.ctaGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  onPressed: _isResetting
                      ? null
                      : () async {
                          final emp   = _resetEmpCtrl.text.trim();
                          final email = _resetEmailCtrl.text.trim();
                          if (emp.isEmpty || email.isEmpty) return;
                          setDlg(() => _isResetting = true);
                          final nav = Navigator.of(ctx);
                          try {
                            final res = await ApiService.resetPin(emp, email);
                            nav.pop();
                            if (!mounted) return;
                            if (res['success'] == true) {
                              _showSuccess(
                                  res['message'] ?? 'تم إعادة تعيين الرمز بنجاح');
                            } else {
                              _showError(
                                  res['message'] ?? 'تعذّر إعادة تعيين الرمز');
                            }
                          } catch (_) {
                            nav.pop();
                            if (!mounted) return;
                            _showError('تعذّر الاتصال بالخادم');
                          } finally {
                            if (mounted) setDlg(() => _isResetting = false);
                          }
                        },
                  child: _isResetting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('إعادة تعيين',
                          style: DesignSystem.buttonTextStyle
                              .copyWith(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: Stack(
          children: [
            // Background subtle glow
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DesignSystem.teal.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DesignSystem.amber.withOpacity(0.04),
                ),
              ),
            ),
            
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 60),

                      // ── Heart Icon (مطابق للمقترح) ──
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: DesignSystem.tealGradient,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: DesignSystem.teal.withOpacity(0.30),
                                offset: const Offset(0, 12),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms).scale(
                          begin: const Offset(0.85, 0.85),
                          curve: DesignSystem.springCurve),

                      const SizedBox(height: 24),

                      // ── Title (Gold) ──
                      Text(
                        'صندوق البريقة للتأمين الصحي',
                        textAlign: TextAlign.center,
                        style: DesignSystem.hugeNumberStyle.copyWith(
                          fontSize: 20,
                          letterSpacing: -0.3,
                          color: DesignSystem.amber,
                          height: 1.4,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                      const SizedBox(height: 6),

                      // ── Slogan ──
                      Text(
                        'صحتك تهمنا',
                        style: DesignSystem.bodyTextStyle.copyWith(
                          color: DesignSystem.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: 40),

                      // Input Card — flat clean Medical Calm
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DesignSystem.bgBody,
                          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
                          border: Border.all(color: DesignSystem.borderPrimary),
                          boxShadow: DesignSystem.cardShadow,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(0),
                          decoration: const BoxDecoration(),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _empNoController,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(color: DesignSystem.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'الرقم الوظيفي',
                                  prefixIcon: const Icon(Icons.badge_outlined, color: DesignSystem.blue),
                                  hintText: 'أدخل رقمك الوظيفي',
                                  hintStyle: DesignSystem.bodyTextStyle.copyWith(color: DesignSystem.textSubtle),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                              ),
                              Divider(color: DesignSystem.borderPrimary),
                              TextFormField(
                                controller: _pinController,
                                obscureText: _obscurePin,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(color: DesignSystem.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'الرمز السري',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: DesignSystem.blue),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: DesignSystem.textSubtle,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                      const SizedBox(height: 30),

                      // Login Button with CTA Gradient
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
                          gradient: DesignSystem.ctaGradient,
                          boxShadow: DesignSystem.ctaShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text('تسجيل الدخول', style: DesignSystem.buttonTextStyle),
                        ),
                      ).animate().fadeIn(delay: 500.ms).scale(),

                      const SizedBox(height: 16),

                      // Forgot PIN
                      TextButton.icon(
                        onPressed: _showForgotPinDialog,
                        icon: const Icon(Icons.lock_reset_rounded,
                            size: 16, color: DesignSystem.textSubtle),
                        label: Text('نسيت الرمز السري؟',
                            style: DesignSystem.bodyTextStyle.copyWith(
                                color: DesignSystem.textSubtle, fontSize: 13)),
                      ).animate().fadeIn(delay: 560.ms),

                      const SizedBox(height: 24),

                      // Info Note
                      Text(
                        'إذا كانت هذه أول مرة تدخل فيها للتطبيق، الرمز السري هو نفس رقمك الوظيفي.',
                        textAlign: TextAlign.center,
                        style: DesignSystem.bodyTextStyle.copyWith(
                          color: DesignSystem.textSubtle,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 600.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
