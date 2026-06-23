import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🩺 Sky Clinical Design System
/// Palette مستوحى من Apple Health · One Medical:
/// • أبيض نقي كقاعدة — النظافة هي القاعدة
/// • Sky Blue كلون أساسي (الثقة الطبية)
/// • Cyan كلون داعم متوهج
/// • Orange (Apple-style) للأرقام المالية — يلفت الانتباه
/// • ظلال خفيفة جداً بتلوين أزرق بارد
/// • زوايا 16px (كما هي)
class DesignSystem {
  // ━━━ BACKGROUNDS — أبيض نقي + ضباب أزرق ━━━
  static const Color bgPrimary  = Color(0xFFFFFFFF); // أبيض نقي
  static const Color bgDeepDark = Color(0xFFF2F7FC); // Mist — الأقسام المنخفضة
  static const Color bgBody     = Color(0xFFFFFFFF);
  static const Color bgPhone    = Color(0xFFFFFFFF);

  // ━━━ BRAND COLORS — Sky Blue محور كل شيء ━━━
  static const Color blue        = Color(0xFF0066CC); // Primary Sky
  static const Color blueDark    = Color(0xFF003D7A); // Deep Sky
  static const Color cyan        = Color(0xFF5AC8FA); // Cyan متوهج
  static const Color emerald     = Color(0xFF34C759); // Apple Green
  static const Color emeraldDark = Color(0xFF248A3D);
  static const Color teal        = Color(0xFF5AC8FA);
  static const Color tealDark    = Color(0xFF0066CC);
  static const Color violet      = Color(0xFFAF52DE); // Apple Purple soft
  static const Color violetDark  = Color(0xFF7E2BB8);
  static const Color rose        = Color(0xFFFF6B6B); // Soft Coral
  static const Color roseDark    = Color(0xFFDC2626);
  static const Color slate       = Color(0xFF8E8E93); // Apple Gray
  static const Color slateDark   = Color(0xFF3A3A3C);
  static const Color amber       = Color(0xFFFF9500); // Apple Orange — الأرقام المالية

  // ━━━ TEXT — حبر إكلينيكي ━━━
  static const Color textPrimary = Color(0xFF1A1A1A); // Ink
  static const Color textMuted   = Color(0xFF7A8AA0); // Cool muted
  static const Color textSubtle  = Color(0xFFACBAC8);

  // ━━━ BORDERS — أزرق بارد فاتح ━━━
  static const Color borderPrimary = Color(0xFFE5EAF0);
  static const Color borderBright  = Color(0xFFD5DDE5);

  // ━━━ GRADIENTS — sky-centric ━━━
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAFCFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFF0066CC), Color(0xFF5AC8FA)],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF003D7A), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF248A3D), Color(0xFF34C759)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF0066CC), Color(0xFF5AC8FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGradient = LinearGradient(
    colors: [Color(0xFF7E2BB8), Color(0xFFAF52DE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient roseGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient slateGradient = LinearGradient(
    colors: [Color(0xFF3A3A3C), Color(0xFF8E8E93)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ━━━ SHADOWS — خفيفة بتلوين أزرق بارد ━━━
  static List<BoxShadow> glowShadow(Color color, {double opacity = 0.14}) => [
    BoxShadow(
      color: color.withOpacity(opacity),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  static List<BoxShadow> get ctaShadow => [
    BoxShadow(
      color: const Color(0xFF0066CC).withOpacity(0.22),
      offset: const Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  static List<BoxShadow> get avatarShadow => [
    BoxShadow(
      color: const Color(0xFF0066CC).withOpacity(0.20),
      offset: const Offset(0, 4),
      blurRadius: 14,
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F1828).withOpacity(0.05),
      offset: const Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  // ━━━ TYPOGRAPHY — Cairo ━━━
  static TextStyle get hugeNumberStyle => GoogleFonts.cairo(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: amber, // Apple Orange للأرقام المالية
    height: 1.1,
  );

  static TextStyle get headingStyle => GoogleFonts.cairo(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: textPrimary,
  );

  static TextStyle get buttonTextStyle => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: Colors.white,
  );

  static TextStyle get bodyTextStyle => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle get smallTextStyle => GoogleFonts.cairo(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  static TextStyle get labelStyle => GoogleFonts.cairo(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: textMuted,
  );

  // ━━━ RADII — كما هي ━━━
  static const double radiusCTA      = 14.0;
  static const double radiusCard     = 16.0;
  static const double radiusGridItem = 16.0;
  static const double radiusIconBtn  = 12.0;
  static const double radiusAvatar   = 14.0;
  static const double radiusPill     = 12.0;

  // ━━━ ANIMATIONS — أهدأ ━━━
  static const Curve springCurve  = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve easeOutCurve = Cubic(0.16, 1.0, 0.3, 1.0);
}
