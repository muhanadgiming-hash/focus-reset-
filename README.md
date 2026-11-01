# Focus Reset

تطبيق iPhone للصحة الرقمية والإنتاجية وتنظيم الحياة — مبني بـ Flutter، يدعم العربية (RTL) والإنجليزية، والوضع الفاتح والداكن.
**لا يستخدم أي ذكاء اصطناعي**: كل منطق التطبيق قواعد وخوارزميات تقليدية.

---

## حالة المراحل

| المرحلة | المحتوى | الحالة |
|---|---|---|
| 1 | هيكل المشروع، نظام التصميم، كل الواجهات والتنقل، اللغتان، التهيئة الأولية | ✅ |
| 2 | تخزين المهام والعادات والالتزامات + محرك Smart Life Scheduler + اختباراته | ✅ |
| 3 | Supabase: الحسابات، المزامنة، حذف الحساب | ✅ |
| 4 | الإشعارات، Apple Calendar، المنطقة الزمنية الدقيقة | ✅ |
| 5 | حظر التطبيقات عبر FamilyControls / ManagedSettings (بعد موافقة Apple) | ✅ (يعمل بعد الموافقة) |
| 6 | التجهيز للنشر: الأذونات بالعربية، Privacy Manifest، نصوص المتجر، سياسة الخصوصية، الرفع عبر Codemagic | ✅ هذه النسخة |

### ما يعمل في المرحلة 2
- **المهام:** إضافة/تعديل/حذف (مع تراجع)، مدة، أولوية، موعد نهائي، تكرار، ربط بهدف أو عادة، وقت مرن أو ثابت، تعليم كمكتملة ✓، تأجيل للغد، إيجاد وقت جديد. المهام المتكررة تعود تلقائيًا بعد إكمالها.
- **الالتزامات الثابتة:** مناوبات، رحلات، اجتماعات، مواعيد — مع وقت الاستعداد والتنقل والراحة بعدها، والمنطقة الزمنية (UTC±) للرحلات، ودعم ما يمتد بعد منتصف الليل.
- **Smart Life Scheduler** (`lib/domain/scheduling/rule_based_scheduler.dart`): جدولة بالقيود لـ 7 أيام قادمة. لا يحرّك الثابت، يحمي النوم (+30 د قبله وبعده)، يترك فواصل وسقفًا يوميًا 70%، يقدّم المهم والمستعجل، يراعي وقتك المفضل، يُبقي الأوقات الصالحة ولا ينقل إلا المتعارض، ويعرض ما لم يجد له وقتًا مع السبب. **كل تغيير يُعرض في شاشة مراجعة ولا يُطبّق إلا بموافقتك.**
- **العادات:** إنشاء من قوالب أو مخصصة، يوميًا/أيام محددة/عدد مرات أسبوعيًا، تسجيل سريع (+)، سلسلة الاستمرارية.
- **التركيز:** كل جلسة تُحفظ وتُربط بمهمة.
- **النوم:** تسجيل يدوي، رسم أسبوعي، متوسط.
- **التقارير:** نسب الإنجاز، التركيز، العادات، مقارنة بالأسبوع الماضي، أكثر أوقات اليوم إنتاجية — من بياناتك فقط.
- البيانات محفوظة على الجهاز (`LocalPlannerRepository`) وتنتقل إلى Supabase في المرحلة 3 دون تغيير الواجهات.

### الاختبارات
- `test/scheduler_test.dart` — اختبار لكل قاعدة من قواعد الجدولة والتعارضات وإعادة الجدولة.
- `test/domain_logic_test.dart` — التكرار، العادات، الإحصائيات، تقسيم الرحلات الليلية، JSON.
- `test/fixed_blocks_test.dart`، `test/l10n_parity_test.dart`، `test/app_smoke_test.dart`.

---

## المرحلة 6 — الاختبار والنشر

| الملف | المحتوى |
|---|---|
| `docs/RELEASE_GUIDE.md` | خطوات الرفع إلى App Store من Windows خطوة بخطوة |
| `docs/STORE_LISTING.md` | الاسم والوصف والكلمات المفتاحية (عربي/إنجليزي) + ملاحظات المراجعة |
| `docs/APP_PRIVACY.md` | إجابات قسم الخصوصية في App Store Connect |
| `docs/privacy-policy.html` | صفحة سياسة الخصوصية (عربي/إنجليزي) للنشر على رابط عام |
| `docs/QA_CHECKLIST.md` | قائمة اختبار يدوي على الآيفون عبر TestFlight |
| `ios_resources/` | نصوص الأذونات بالعربية والإنجليزية + `PrivacyInfo.xcprivacy` (تُضاف تلقائيًا عبر `scripts/ios_extras.rb`) |

## المرحلة 5 — حظر التطبيقات أثناء التركيز

- `packages/focus_native/ios/Classes/FocusBlocking.swift`: FamilyControls (إذن المستخدم + منتقي التطبيقات من Apple) و ManagedSettings (الحجب).
- يبدأ الحجب مع جلسة التركيز ويُرفع عند انتهائها أو الإيقاف المؤقت أو الإنهاء. إذا أُغلق التطبيق أثناء الجلسة يُرفع الحجب عند فتحه بعد انتهاء الوقت.
- الاختيارات رموز خاصة من Apple تبقى على الجهاز، ولا يراها التطبيق ولا تُرفع.
- **بدون موافقة Apple يظهر للمستخدم أن الميزة غير متاحة بعد — لا ادعاء بأنها تعمل** (`test/blocking_test.dart`).
- لم تُستخدم DeviceActivity (تحتاج Extension منفصلة)؛ البنية جاهزة لإضافتها لاحقًا لرفع الحجب تلقائيًا حتى والتطبيق مغلق.

### للحصول على موافقة Apple (مرة واحدة، يتطلب حساب Apple Developer مدفوع)
1. developer.apple.com → Identifiers → App ID الخاص بالتطبيق → فعّل **Family Controls**.
2. قدّم طلب **Family Controls (Distribution)** من: https://developer.apple.com/contact/request/family-controls-distribution
3. بعد الموافقة: في Codemagic غيّر `FAMILY_CONTROLS` إلى `"true"` (يضيف السكربت ملف الصلاحيات تلقائيًا).

## المرحلة 4 — الإشعارات والتقويم والمنطقة الزمنية

- **Plugin محلي بلغة Swift** في `packages/focus_native` (بدون مكتبات خارجية): UserNotifications + EventKit + TimeZone.
- **التذكيرات** (محلية من الجهاز، لا خادم): قبل المهام المجدولة (المدة قابلة للتعديل)، العادات في وقتها، وقت النوم قبل 30 دقيقة، ونهاية جلسة التركيز/الاستراحة حتى لو التطبيق مغلق. حد iOS (64) محترم. المنطق في `lib/domain/notifications/notification_planner.dart` + اختبارات.
- **تقويم Apple (قراءة فقط)**: مواعيدك تحجز وقتها في الجدول والمحرك لا يضع مهام فوقها. اختيار التقاويم. لا تُعدَّل ولا تُرفع ولا تُزامن.
- **المنطقة الزمنية**: يُقرأ اسمها الحقيقي من iOS (مثل Asia/Riyadh).
- الأذونات تُطلب فقط عند تفعيل الميزة، وإذا رُفضت يظهر زر لفتح إعدادات الآيفون.

## المرحلة 3 — الحسابات والمزامنة (Supabase)

- التطبيق **يعمل أولًا على الجهاز** (offline-first): كل تعديل يُحفظ محليًا فورًا، ثم يُزامن بعد ثانيتين، وعند فتح التطبيق، وعند العودة إليه.
- المزامنة لكل سجل على حدة، والأحدث يفوز. القاعدة نفسها ترفض أي تعديل أقدم من الموجود (`lib/data/sync/sync_engine.dart` + `test/sync_engine_test.dart`).
- تسجيل فوري بالبريد وكلمة المرور **بدون أي رسائل بريد أو رموز تأكيد**.
- حذف الحساب وكل بياناته من داخل التطبيق (شرط Apple)، وتسجيل الخروج يزيل البيانات من الجهاز.
- نسخ كل البيانات بصيغة JSON من شاشة التقارير.
- بدون مفاتيح Supabase يعمل التطبيق كاملًا على الجهاز وتظهر الحسابات «غير مفعّلة».

### الإعداد (مرة واحدة)
1. **Supabase → SQL Editor → New query**: الصق محتوى `supabase/schema.sql` واضغط **Run**.
2. **Authentication → Sign In / Providers → Email**: أطفئ **Confirm email** واحفظ. بذلك يتم التسجيل فورًا ولا تُرسل أي رسالة بريد.
   (لا توجد استعادة لكلمة المرور عبر البريد، والتطبيق ينبّه المستخدم لذلك عند التسجيل.)
3. **Project Settings → API**: انسخ `Project URL` و `anon public` key.
4. **Codemagic → التطبيق → Environment variables**: أنشئ مجموعة باسم `supabase` وأضف فيها:
   - `SUPABASE_URL` = رابط المشروع
   - `SUPABASE_ANON_KEY` = مفتاح anon (فعّل **Secure**)
5. لا تضع مفتاح `service_role` في أي مكان داخل التطبيق أو GitHub.

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
