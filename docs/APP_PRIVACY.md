# إجابات قسم App Privacy في App Store Connect

App Store Connect → التطبيق → **App Privacy** → **Get Started**

**Do you or your third-party partners collect data from this app?** → **Yes**
(لأن الحساب الاختياري يحفظ البريد والبيانات في Supabase. بدون حساب لا يُجمع شيء.)

## أنواع البيانات التي تختارها

| الفئة | النوع | الاستخدام | مرتبط بهوية المستخدم؟ | للتتبع؟ |
|---|---|---|---|---|
| Contact Info | **Email Address** | App Functionality | Yes | No |
| User Content | **Other User Content** (المهام، العادات، الالتزامات، الجلسات) | App Functionality | Yes | No |
| Health & Fitness | **Health** (سجلات النوم اليدوية) | App Functionality | Yes | No |

> اختيار «Health» لسجلات النوم احتياطي — Apple تعتبر بيانات النوم صحية غالبًا، والإفصاح الزائد أسلم من الناقص.

**لا تختر:** Location, Contacts, Identifiers, Usage Data, Diagnostics, Purchases, Financial Info, Browsing History.

- Tracking: **No** لكل الأنواع.
- Third-party advertising / Analytics: **لا شيء**.

## ملاحظات
- تقويم Apple يُقرأ على الجهاز فقط ولا يُرسل → **لا يُعد جمعًا للبيانات**.
- اختيارات حظر التطبيقات رموز خاصة من Apple على الجهاز → **لا تُجمع**.
- التذكيرات محلية → **لا تُجمع**.
