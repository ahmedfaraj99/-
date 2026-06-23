import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/design_system.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  Future<void> _submitSetup() async {
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (email.isEmpty || pin.isEmpty || confirmPin.isEmpty) {
      _showMsg('الرجاء تعبئة جميع الحقول', isError: true);
      return;
    }
    if (!email.contains('@')) {
      _showMsg('الرجاء إدخال بريد إلكتروني صحيح', isError: true);
      return;
    }
    if (pin != confirmPin) {
      _showMsg('الرموز السرية غير متطابقة', isError: true);
      return;
    }
    if (pin.length < 4 || pin.length > 8) {
      _showMsg('يجب أن يكون الرمز السري بين 4 و 8 أرقام', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.setupProfile(email, pin);
      if (response['success'] == true) {
        if (!mounted) return;
        _showMsg('تم استكمال إعداد الحساب بنجاح!');
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        if (!mounted) return;
        _showMsg(response['message'] ?? 'حدث خطأ غير معروف', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMsg('خطأ في الاتصال بالخادم', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: DesignSystem.bodyTextStyle),
      backgroundColor: isError ? DesignSystem.rose : DesignSystem.emerald,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // --- ICON ---
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: DesignSystem.tealGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: DesignSystem.avatarShadow,
                  ),
                  child: const Icon(Icons.shield_outlined,
                      size: 40, color: Colors.white),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),
                Text(
                  'إعداد الحساب',
                  style: DesignSystem.hugeNumberStyle.copyWith(
                    fontSize: 24,
                    letterSpacing: 0,
                    color: DesignSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لحماية حسابك، يرجى إدخال بريدك الإلكتروني\nوتعيين رمز سري جديد بدلاً من الافتراضي',
                  textAlign: TextAlign.center,
                  style: DesignSystem.smallTextStyle.copyWith(
                    color: DesignSystem.textMuted,
                    height: 1.6,
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 48),

                // --- INPUTS ---
                _buildField('البريد الإلكتروني', _emailController, Icons.email_outlined).animate().fadeIn(delay: 300.ms).slideX(),
                const SizedBox(height: 20),
                _buildField('الرمز السري الجديد', _pinController, Icons.lock_outline_rounded, isPin: true, obscure: _obscurePin, toggle: () => setState(() => _obscurePin = !_obscurePin)).animate().fadeIn(delay: 400.ms).slideX(),
                const SizedBox(height: 20),
                _buildField('تأكيد الرمز السري', _confirmPinController, Icons.lock_reset_rounded, isPin: true, obscure: _obscureConfirmPin, toggle: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin)).animate().fadeIn(delay: 500.ms).slideX(),

                const SizedBox(height: 48),

                // --- SUBMIT BUTTON ---
                _buildSubmitBtn().animate().fadeIn(delay: 600.ms).scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {bool isPin = false, bool obscure = false, VoidCallback? toggle}) {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.bgBody,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        border: Border.all(color: DesignSystem.borderPrimary),
      ),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: isPin ? TextInputType.number : TextInputType.emailAddress,
        style: DesignSystem.bodyTextStyle.copyWith(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: DesignSystem.bodyTextStyle.copyWith(
              color: DesignSystem.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: DesignSystem.teal, size: 20),
          suffixIcon: toggle != null
              ? IconButton(
                  icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: DesignSystem.textSubtle, size: 20),
                  onPressed: toggle)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSubmitBtn() {
    return Container(
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        color: DesignSystem.teal,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
        boxShadow: DesignSystem.ctaShadow,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitSetup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusCTA)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text('حفظ وإكمال الدخول',
                style: DesignSystem.buttonTextStyle.copyWith(fontSize: 14)),
      ),
    );
  }
}
