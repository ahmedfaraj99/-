import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import '../screens/home_screen.dart';
import '../screens/family_screen.dart';
import '../screens/providers_screen.dart';
import '../screens/support_screen.dart';
import '../screens/profile_screen.dart';

/// 🌿 Bottom Navigation موحَّد لكل الشاشات
/// يستخدم 5 أزرار: الرئيسية، العائلة، المزودين، الدعم، حسابي
class AppBottomNav extends StatelessWidget {
  /// 0=Home, 1=Family, 2=Providers, 3=Support, 4=Profile
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    final Widget target = switch (index) {
      0 => const HomeScreen(),
      1 => const FamilyScreen(),
      2 => const ProvidersScreen(),
      3 => const SupportScreen(),
      _ => const ProfileScreen(),
    };
    // Replace stack root so back button doesn't keep pushing screens
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => target,
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.bgBody,
        border: const Border(
          top: BorderSide(color: DesignSystem.borderPrimary, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, -1),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, 0,
                  iconActive: Icons.home_rounded,
                  iconInactive: Icons.home_outlined,
                  label: 'الرئيسية'),
              _navItem(context, 1,
                  iconActive: Icons.groups_rounded,
                  iconInactive: Icons.groups_outlined,
                  label: 'العائلة'),
              _navItem(context, 2,
                  iconActive: Icons.local_hospital_rounded,
                  iconInactive: Icons.local_hospital_outlined,
                  label: 'المزودين'),
              _navItem(context, 3,
                  iconActive: Icons.support_agent_rounded,
                  iconInactive: Icons.support_agent_outlined,
                  label: 'الدعم'),
              _navItem(context, 4,
                  iconActive: Icons.person_rounded,
                  iconInactive: Icons.person_outline_rounded,
                  label: 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index, {
    required IconData iconActive,
    required IconData iconInactive,
    required String label,
  }) {
    final bool active = currentIndex == index;
    final Color color = active ? DesignSystem.teal : DesignSystem.textSubtle;

    return Expanded(
      child: InkWell(
        onTap: () => _onTap(context, index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? iconActive : iconInactive, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                  fontFamily: 'Cairo',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? DesignSystem.teal : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
