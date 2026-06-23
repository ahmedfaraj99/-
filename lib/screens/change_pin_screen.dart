import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../theme/design_system.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.changePin(
        _currentPinCtrl.text.trim(),
        _newPinCtrl.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم تغيير الرمز السري بنجاح', style: DesignSystem.bodyTextStyle),
          backgroundColor: DesignSystem.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'حدث خطأ', style: DesignSystem.bodyTextStyle),
          backgroundColor: DesignSystem.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذّر الاتصال بالخادم', style: DesignSystem.bodyTextStyle),
        backgroundColor: DesignSystem.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        body: SafeArea(child: Column(
          children: [
            // ── TOP BAR — flat ──
            Padding(
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
                    child: Text('تغيير الرمز السري',
                        style: DesignSystem.headingStyle.copyWith(fontSize: 17)),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // ── FORM ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: DesignSystem.tealGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: DesignSystem.avatarShadow,
                        ),
                        child: const Icon(Icons.lock_reset_rounded,
                            size: 40, color: Colors.white),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 28),

                      Text(
                        'حافظ على أمان حسابك بتغيير رمزك السري بانتظام.',
                        textAlign: TextAlign.center,
                        style: DesignSystem.bodyTextStyle.copyWith(
                            color: DesignSystem.textMuted, height: 1.6),
                      ).animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 36),

                      _pinField(
                        controller: _currentPinCtrl,
                        label: 'الرمز السري الحالي',
                        obscure: _obscureCurrent,
                        onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                        delay: 200,
                      ),

                      const SizedBox(height: 16),

                      _pinField(
                        controller: _newPinCtrl,
                        label: 'الرمز السري الجديد',
                        obscure: _obscureNew,
                        onToggle: () => setState(() => _obscureNew = !_obscureNew),
                        validator: (v) =>
                            (v == null || v.length < 4) ? 'يجب أن يكون 4 أرقام على الأقل' : null,
                        delay: 300,
                      ),

                      const SizedBox(height: 16),

                      _pinField(
                        controller: _confirmPinCtrl,
                        label: 'تأكيد الرمز الجديد',
                        obscure: _obscureConfirm,
                        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) =>
                            v != _newPinCtrl.text ? 'الرمزان غير متطابقان' : null,
                        delay: 400,
                      ),

                      const SizedBox(height: 36),

                      // Submit button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: DesignSystem.teal,
                          borderRadius: BorderRadius.circular(DesignSystem.radiusCTA),
                          boxShadow: DesignSystem.ctaShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(DesignSystem.radiusCTA)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text('حفظ الرمز الجديد',
                                  style: DesignSystem.buttonTextStyle),
                        ),
                      ).animate().fadeIn(delay: 500.ms).scale(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    required int delay,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.bgBody,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        border: Border.all(color: DesignSystem.borderPrimary),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        style: DesignSystem.bodyTextStyle.copyWith(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: DesignSystem.bodyTextStyle.copyWith(
              color: DesignSystem.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: DesignSystem.teal, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: DesignSystem.textSubtle,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms);
  }
}
