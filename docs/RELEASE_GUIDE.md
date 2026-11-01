# دليل الرفع إلى App Store — من Windows عبر Codemagic

كل الخطوات تتم من المتصفح. لا تحتاج جهاز Mac.

---

## 0) قبل البدء
- حساب **Apple Developer Program** مدفوع (اشتراك سنوي) باسمك أو باسم منشأة.
- آخر بناء **iOS · Verify** في Codemagic أخضر.
- استضافة صفحة **سياسة الخصوصية** على رابط عام (انظر الخطوة 6).

---

## 1) اختر معرّف التطبيق (Bundle ID)
اختر معرّفًا فريدًا لا يتغير بعد النشر، مثل: `com.yourname.focusreset`

غيّره في ملف `codemagic.yaml` في **3 أماكن**:
- `BUNDLE_ID` تحت `definitions → env → vars`
- `bundle_identifier` تحت `ios-release → ios_signing`
- `BUNDLE_ID` تحت `ios-release → vars`

## 2) سجّل المعرّف في Apple
developer.apple.com → **Certificates, Identifiers & Profiles** → **Identifiers** → **+** → **App IDs** → **App**
- Description: `Focus Reset`
- Bundle ID: **Explicit** ونفس المعرّف من الخطوة 1
- Capabilities: لا شيء إضافي الآن (Family Controls فقط بعد موافقة Apple — انظر README)

## 3) أنشئ التطبيق في App Store Connect
appstoreconnect.apple.com → **Apps** → **+** → **New App**
- Platform: iOS
- Name: `Focus Reset` (إذا كان محجوزًا جرّب `Focus Reset: Plan & Focus`)
- Primary language: Arabic أو English
- Bundle ID: اختر المعرّف
- SKU: `focusreset001`

بعد الإنشاء: **App Information** → انسخ رقم **Apple ID** (أرقام فقط) وضعه في `APP_STORE_APPLE_ID` داخل `codemagic.yaml`.

## 4) مفتاح App Store Connect API (يسمح لـ Codemagic بالتوقيع والرفع)
App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **+**
- Name: `Codemagic` — Access: **App Manager**
- نزّل ملف `.p8` (يُنزَّل مرة واحدة فقط — احفظه)، وانسخ **Issuer ID** و **Key ID**

## 5) اربط المفتاح في Codemagic
Codemagic → **Team settings** (أو Personal account) → **Integrations** → **Developer Portal** → **Manage keys** → **Add key**
- **App Store Connect API key name**: `Focus Reset ASC` (بالضبط — نفس الاسم في `codemagic.yaml`)
- Issuer ID / Key ID / ملف `.p8`

ثم: **Code signing identities** → **iOS certificates** → **Generate certificate** (نوع Apple Distribution).
Codemagic ينشئ ملف التوقيع (Provisioning profile) تلقائيًا عند البناء.

## 6) سياسة الخصوصية والدعم
الملف جاهز: `docs/privacy-policy.html` (عربي + إنجليزي).
1. افتحه وضع بريد الدعم بدل `SUPPORT_EMAIL` (مرتين).
2. انشره على رابط عام مجاني، مثل:
   - مستودع GitHub **عام** منفصل باسم `focus-reset-legal` → ارفع الملف باسم `index.html` → **Settings → Pages → Deploy from branch (main)**
3. ضع الرابط في App Store Connect: **App Privacy → Privacy Policy URL** و **Support URL**.

## 7) أول رفع إلى TestFlight
1. ارفع التعديلات (codemagic.yaml بعد تغيير المعرّف والرقم) إلى GitHub.
2. Codemagic → **Start new build** → Workflow: **iOS · TestFlight release**.
3. بعد النجاح (≈ 20–40 دقيقة) يظهر البناء في App Store Connect → **TestFlight** خلال دقائق إلى ساعة.
4. أجب عن سؤال التشفير إن ظهر: **None of the algorithms mentioned above** (التطبيق يستخدم HTTPS فقط — ومُعلن مسبقًا في Info.plist).
5. **Internal Testing** → أضف نفسك → ثبّت تطبيق **TestFlight** على الآيفون وجرّب. استخدم `docs/QA_CHECKLIST.md`.

## 8) الإرسال للمراجعة
App Store Connect → التطبيق → **iOS App 1.0**:
- النصوص: من `docs/STORE_LISTING.md`
- لقطات الشاشة: آيفون 6.9" (1320×2868) — 3 على الأقل (التقطها من TestFlight)
- **App Privacy**: الإجابات في `docs/APP_PRIVACY.md`
- **Age Rating**: كل الإجابات «None/No» → 4+
- **Build**: اختر البناء من TestFlight
- **App Review Information → Notes**: انسخ ملاحظات المراجعة من `docs/STORE_LISTING.md`
- **Submit for Review**

## أسباب رفض شائعة — وتم التعامل معها
| المتطلب | الحالة |
|---|---|
| حذف الحساب من داخل التطبيق | ✅ الإعدادات ← الحساب والمزامنة ← حذف الحساب |
| شرح أسباب الأذونات | ✅ بالعربي والإنجليزي |
| ملف Privacy Manifest | ✅ `PrivacyInfo.xcprivacy` |
| لا ادعاءات طبية | ✅ تنبيه في شاشة النوم |
| ميزات غير مكتملة ظاهرة | ✅ حظر التطبيقات يوضح أنه غير متاح حتى موافقة Apple |
| استخدام التطبيق بدون حساب | ✅ ممكن بالكامل |
