# Focus Reset

تطبيق iPhone للصحة الرقمية والإنتاجية وتنظيم الحياة — مبني بـ Flutter، يدعم العربية (RTL) والإنجليزية، والوضع الفاتح والداكن.
**لا يستخدم أي ذكاء اصطناعي**: كل منطق التطبيق قواعد وخوارزميات تقليدية.

---

## حالة المراحل

| المرحلة | المحتوى | الحالة |
|---|---|---|
| 1 | هيكل المشروع، نظام التصميم، كل الواجهات والتنقل، اللغتان، التهيئة الأولية | ✅ هذه النسخة |
| 2 | تخزين المهام والعادات والالتزامات + محرك Smart Life Scheduler + اختباراته | ⏳ |
| 3 | Supabase: الحسابات، المزامنة، حذف الحساب | ⏳ |
| 4 | الإشعارات، Apple Calendar، المنطقة الزمنية الدقيقة | ⏳ |
| 5 | حظر التطبيقات عبر FamilyControls / ManagedSettings / DeviceActivity (بعد موافقة Apple) | ⏳ |
| 6 | التوقيع والرفع إلى TestFlight / App Store Connect | ⏳ (الإعداد جاهز في `codemagic.yaml`) |

### ما يعمل فعليًا في المرحلة 1
- التهيئة الأولية (7 خطوات) وحفظ الملف الشخصي على الجهاز، وتعديله لاحقًا من الإعدادات.
- تبديل اللغة (عربي/إنجليزي/حسب النظام) مع قلب الاتجاه الكامل، وتبديل المظهر (فاتح/داكن/حسب النظام).
- **الأوقات المحمية** محسوبة من بياناتك الحقيقية: النوم، الدوام الثابت، وقت التنقل — مع تقسيم صحيح للنوم والمناوبات الليلية عبر منتصف الليل (`lib/domain/scheduling/fixed_blocks.dart` + اختبارات).
- الجدول اليومي (Timeline) والأسبوعي يعرضان هذه الأوقات.
- مؤقّت التركيز يعمل بالكامل (تركيز/استراحة/إيقاف مؤقت/سجل الجلسات خلال التشغيل الحالي) ودقيق حتى عند الخروج من التطبيق.
- تعديل أوقات النوم من شاشة النوم.
- حذف كل البيانات المحلية من الإعدادات.

### ما هو مصمَّم لكن غير مفعّل بعد (يظهر للمستخدم بوضوح)
نماذج إضافة المهام والعادات والالتزامات وتسجيل النوم مكتملة التصميم والتحقق، لكن **الحفظ** يُفعَّل في المرحلة 2؛ عند الضغط على «حفظ» يظهر تنبيه صريح بذلك. الإحصائيات تعرض أصفارًا و«—» ولا تعرض أي بيانات وهمية.

---

## هيكل المشروع

```
lib/
├── main.dart                     نقطة البداية
├── app/                          MaterialApp + حالة التطبيق (اللغة، المظهر، الملف الشخصي)
├── core/
│   ├── l10n/                     الترجمة (strings_en / strings_ar) — بلا توليد كود
│   ├── theme/                    الألوان الدلالية، الخطوط، المسافات
│   ├── utils/                    أدوات الوقت والتاريخ
│   └── widgets/                  مكوّنات مشتركة (بطاقات، أزرار، رسوم بيانية، نوافذ)
├── data/
│   ├── models/                   UserProfile, TaskItem, Commitment, Habit, FocusSession, SleepEntry
│   ├── repositories/             واجهات المستودعات + التنفيذ المحلي (Supabase لاحقًا)
│   └── services/                 التخزين المحلي
├── domain/
│   └── scheduling/               محرك الجدولة — Dart خالص، مستقل عن الواجهة، قابل للاختبار
└── features/                     الشاشات: auth, onboarding, shell, home, scheduler,
                                  tasks, habits, focus, sleep, progress, settings
test/                             اختبارات الترجمة، الأوقات المحمية، والواجهة
scripts/prepare_ios.sh            يولّد مجلد ios ويضبطه على جهاز Codemagic
codemagic.yaml                    سير عمل التحقق + سير عمل الإصدار
```

**لماذا لا يوجد مجلد `ios/`؟** لأن المشروع يُكتب على Windows. السكربت `scripts/prepare_ios.sh` يولّد مشروع Xcode على جهاز Mac التابع لـ Codemagic في كل بناء، ثم يضبط: اسم التطبيق، اللغتين، iPhone فقط، الاتجاه العمودي، ومعرّف الحزمة.

---

## التشغيل والاختبار على Windows (اختياري)

1. ثبّت Flutter: https://docs.flutter.dev/get-started/install/windows
2. داخل مجلد المشروع:
   ```powershell
   flutter pub get
   flutter test
   flutter analyze
   ```
3. لمعاينة الواجهات على الكمبيوتر فقط (ليست نسخة المنتج):
   ```powershell
   flutter create --platforms=windows .
   flutter run -d windows
   ```
   > لا ترفع مجلد `windows/` إلى GitHub إن لم تكن تحتاجه — أو احذفه بعد المعاينة.

---

## البناء عبر Codemagic (بدون Mac)

1. ارفع المشروع إلى GitHub (الشرح في الأسفل).
2. ادخل https://codemagic.io وسجّل بحساب GitHub.
3. **Add application** ← اختر المستودع ← **Flutter App** ← سيكتشف `codemagic.yaml` تلقائيًا.
4. شغّل سير العمل **iOS · Verify (no signing)**. يقوم بـ:
   توليد ios ← تثبيت الحزم ← توليد الأيقونات ← `flutter analyze` ← `flutter test` ← `flutter build ios --no-codesign`.
   نجاحه يعني أن المشروع يُبنى فعلًا لـ iPhone وأن كل الاختبارات ناجحة. لا يحتاج حساب Apple Developer.
5. سير العمل **iOS · TestFlight release** مخصص للمرحلة 6 ويتطلب:
   - حساب Apple Developer مدفوع.
   - مفتاح App Store Connect API مضاف في Codemagic باسم `Focus Reset ASC`.
   - تعديل `BUNDLE_ID` و `APP_STORE_APPLE_ID` في `codemagic.yaml`.

### الأسرار
لا توجد أي مفاتيح داخل المشروع. مفاتيح Supabase (المرحلة 3) ستُمرَّر عبر متغيرات Codemagic المشفّرة و `--dart-define`، وملفات `.env` مستثناة في `.gitignore`.

---

## الرفع إلى GitHub من Windows

### الطريقة 1 — GitHub Desktop (الأسهل)
1. فك ضغط `focus_reset.zip` في مكان مثل `C:\Projects\focus_reset`.
2. ثبّت GitHub Desktop: https://desktop.github.com وسجّل الدخول.
3. **File ← Add local repository** ← اختر المجلد ← سيقترح «create a repository» ← وافق.
4. اكتب رسالة مثل `Phase 1` ← **Commit to main** ← **Publish repository** (اترك Private مفعّلًا).

### الطريقة 2 — سطر الأوامر
ثبّت Git من https://git-scm.com/download/win ثم أنشئ مستودعًا فارغًا على github.com باسم `focus-reset` (بدون README)، وبعدها في PowerShell:
```powershell
cd C:\Projects\focus_reset
git init
git add .
git commit -m "Phase 1: project foundation, design system and all screens"
git branch -M main
git remote add origin https://github.com/USERNAME/focus-reset.git
git push -u origin main
```

---

## الخصوصية
- البيانات حاليًا على الجهاز فقط (`shared_preferences`).
- لا إعلانات، لا بيع بيانات، لا خدمات ذكاء اصطناعي، لا تتبّع.
- كل الصلاحيات (التقويم، الإشعارات، Screen Time) ستمر عبر نوافذ أذونات iOS الرسمية.
- يمكن حذف كل البيانات من الإعدادات.
