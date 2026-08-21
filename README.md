# نظام المحاسبة - Accounting System

نظام محاسبة وإدارة أعمال متكامل مبني بـ Flutter مع قاعدة بيانات SQLite.

## الميزات

- لوحة تحكم تفاعلية
- إدارة المبيعات والمشتريات
- إدارة العملاء والموردين والعمال
- نظام المدفوعات والمتحصلات
- التقارير المالية (ميزان المراجعة، الميزانية العمومية، قائمة الدخل)
- دعم متعدد اللغات (عربي، إنجليزي، تركي)
- نظام ترخيص وتفعيل

## البنية

```
accounting_system/
├── lib/                    # كود تطبيق Flutter
│   ├── core/               # نماذج أساسية (Money, Errors)
│   ├── data/               # قاعدة البيانات (Drift/SQLite)
│   ├── domain/             # الخدمات المحاسبية والترخيص
│   ├── l10n/               # الترجمة والدعم اللغوي
│   └── presentation/       # واجهة المستخدم
├── server/                 # سيرفر الترخيص
│   ├── bin/server.dart     # نقطة الدخول
│   └── Dockerfile          # للنشر على Render
├── test/                   # الاختبارات
└── windows/                # ملفاتبناء Windows
```

## التشغيل المحلي

### التطبيق
```bash
flutter pub get
flutter run -d windows
```

### سيرفر الترخيص
```bash
cd server
dart pub get
dart bin/server.dart
```

## النشر على Render

1. ارفع الكود على GitHub
2. اتصل بـ [Render.com](https://render.com)
3. أنشأ "New Web Service" واختر المستودع
4. سيقوم Render ببناء السيرفر تلقائياً من `Dockerfile`

## الترخيص

- خدمة الترخيص تعمل على `http://localhost:8080` محلياً
- عند النشر على Render سيكون الرابط: `https://your-service.onrender.com`
- مفتاح الإدارة الافتراضي: `ADMIN_SECRET_KEY_CHANGE_ME`
