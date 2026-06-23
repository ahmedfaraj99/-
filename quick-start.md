# Quick Start — نظام التصميم

## الإعداد السريع

```html
<!-- 1. أضف الخط -->
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800;900&display=swap" rel="stylesheet">

<!-- 2. أضف ملف نظام التصميم -->
<link rel="stylesheet" href="design-system.css">
```

---

## استخدام CSS Variables

```css
/* ✅ صح — استخدم المتغيرات دائماً */
.my-card {
  background: var(--g-blue);
  box-shadow: var(--sh-blue);
  border-radius: var(--r-22);
  padding: var(--sp-5xl);
}

/* ❌ خطأ — لا تكتب القيم مباشرة */
.my-card {
  background: linear-gradient(145deg, #1d4ed8, #3b82f6);
}
```

---

## إضافة بطاقة خدمة جديدة

```html
<!-- اختر اللون: blue | emerald | teal | violet | rose | slate -->
<div class="grid-item blue rise-in rise-in-g1">
  <svg viewBox="0 0 24 24"><!-- أيقونتك --></svg>
  <span>اسم الخدمة</span>
</div>
```

لإضافة لون جديد تماماً:

```css
/* في design-system.css */
:root {
  --color-amber:    #f59e0b;
  --color-amber-dk: #78350f;
  --g-amber:  linear-gradient(145deg, #78350f, #f59e0b);
  --sh-amber: 0 8px 28px rgba(245,158,11,0.35), inset 0 1px 0 rgba(255,255,255,0.12);
}

.grid-item.amber {
  background: var(--g-amber);
  box-shadow: var(--sh-amber);
}
```

---

## إضافة حركة جديدة

```css
/* 1. عرّف الـ keyframe */
@keyframes slideFromRight {
  from { opacity: 0; transform: translateX(30px); }
  to   { opacity: 1; transform: translateX(0); }
}

/* 2. أنشئ utility class */
.slide-from-right {
  animation: slideFromRight 0.5s var(--spring) both;
}

/* 3. استخدمها مع تأخير */
.slide-from-right.delay-1 { animation-delay: var(--d-header); }
.slide-from-right.delay-2 { animation-delay: var(--d-balance); }
```

---

## استخدام design-tokens.json في Figma

1. ثبّت إضافة **Tokens Studio for Figma**
2. افتح الإضافة → Import → JSON
3. ارفع ملف `design-tokens.json`
4. ستظهر جميع الألوان والمسافات والتأثيرات تلقائياً

---

## قواعد يجب اتباعها دائماً

```
✅ استخدم CSS Variables فقط — لا قيم ثابتة (hardcoded)
✅ استخدم transform بدل top/left للحركات
✅ أضف will-change: transform للعناصر المتحركة
✅ استخدم cubic-bezier(0.34, 1.56, 0.64, 1) للـ hover effects
✅ الخط دائماً 'Cairo', sans-serif
✅ الاتجاه دائماً RTL على الـ body أو Directionality

❌ لا تستخدم backdrop-filter داخل قوائم متمررة
❌ لا تستخدم Spring easing على exit animations
❌ لا تضيف border مرئية — اعتمد على box-shadow فقط للعمق
❌ لا تتجاوز 6 عناصر في الشبكة 3×2
```

---

## مرجع سريع للظلال

```css
/* حسب اللون */
blue    → var(--sh-blue)
emerald → var(--sh-emerald)
teal    → var(--sh-teal)
violet  → var(--sh-violet)
rose    → var(--sh-rose)

/* أزرار CTA */
normal → var(--sh-btn)
hover  → var(--sh-btn-hv)

/* غلاف الهاتف */
phone  → var(--sh-phone)
```

---

## مرجع سريع للتأخيرات

```css
animation-delay: var(--d-status);   /* 50ms  — أول عنصر */
animation-delay: var(--d-header);   /* 120ms */
animation-delay: var(--d-balance);  /* 200ms */
animation-delay: var(--d-section);  /* 280ms */
animation-delay: var(--d-g1);       /* 360ms — عناصر الشبكة */
animation-delay: var(--d-g6);       /* 560ms — آخر عنصر */
animation-delay: var(--d-bottom);   /* 420ms — زر CTA */
```
