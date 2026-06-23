# 🚀 دليل البدء السريع (Quick Start Guide)

## 1. استيراد المكتبة
### للويب (Web):
أضف الرابط التالي في ملفك:
```html
<link rel="stylesheet" href="style.css">
```

### للموبايل (Flutter):
استخدم فئة `DesignSystem` الموجودة في `lib/theme/design_system.dart`.

## 2. استخدام المكونات
### البطاقة الرئيسية (Mesh Card):
استخدم الـ class `balance-card` في HTML أو دالة `_buildMeshCard` في Flutter للحصول على تدرج الـ 3 طبقات.

### الأزرار المتوهجة (CTA):
أضف تأثير الـ `shimmer` للحصول على اللمعة المتحركة:
```html
<button class="cta-button">
    <div class="shimmer-layer"></div>
    نص الزر
</button>
```

## 3. نصائح للأداء
- استخدم `transform: translate` بدلاً من `top/left` للتحريكات.
- قلل من عدد طبقات الـ `backdrop-filter` في الصفحات الطويلة.
- اعتمد على `CSS Variables` لتغيير الثيم بدلاً من كتابة الأكواد يدوياً.
