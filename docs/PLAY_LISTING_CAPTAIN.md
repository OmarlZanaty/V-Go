# V.Go Captain — Google Play store listing

Package `com.scooterapp.vgo.v_go_captain` · Play developer `7713040171420463335` · app `4976476479733476910`.
Written from the captain app's own code (`V-GoCaptain/lib/features/*`), not copied from the rider app.

## App name (≤30)
V.Go Captain

## Short description (≤80)
AR: استقبل رحلات V.Go، اتنقل بالملاحة جوه التطبيق، وتابع أرباحك ومستحقاتك.
EN: Get V.Go trip requests, navigate in-app, and track your earnings and dues.

## Full description (AR, ≤4000)
V.Go Captain هو تطبيق الكباتن الرسمي لخدمة V.Go للتنقل بالسكوتر في مصر.

• استقبال الطلبات: فعّل الاتصال وابدأ تستقبل طلبات الرحلات القريبة منك، وشوف نقطة الركوب والوجهة قبل ما تقبل.
• ملاحة جوه التطبيق: توجيه صوتي بالعربي خطوة بخطوة للراكب ولوجهة الرحلة، من غير ما تخرج من التطبيق.
• أرباحك قدامك: ملخص يومي وأسبوعي لرحلاتك وأرباحك.
• المستحقات والتحصيل: اعرف المستحق عليك وسدده بتحويل محفظة (فودافون كاش، اتصالات كاش، إنستاباي) وتابع حالة كل تحويل.
• التحقق من الحساب: ارفع البطاقة والرخص والفيش الجنائي مرة واحدة، وتابع حالة المراجعة.
• إشعارات فورية بالطلبات الجديدة وتحديثات الحساب.
• زر طوارئ (SOS) أثناء الرحلة، ودعم فني من جوه التطبيق.

الموقع: التطبيق بيستخدم موقعك في الخلفية فقط وإنت متصل أو في رحلة، عشان يوصلك الطلبات القريبة ويتتبع الرحلة. لما تقفل الاتصال بيتوقف التتبع.

حذف الحساب: الإعدادات ← حذف الحساب، أو https://vgo-eg.com/delete-account.html
سياسة الخصوصية: https://vgo.almobarmg.com/privacy

## Full description (EN)
V.Go Captain is the official captain app for V.Go, the e-scooter ride service in Egypt.

• Trip requests: go online and receive nearby ride requests, with pickup and destination shown before you accept.
• In-app navigation: Arabic turn-by-turn voice guidance to the rider and to the destination, without leaving the app.
• Earnings at a glance: daily and weekly summary of your trips and earnings.
• Dues and collection: see what you owe and settle it by wallet transfer (Vodafone Cash, Etisalat Cash, InstaPay), and follow each transfer's status.
• Account verification: upload your ID, licences and criminal-record certificate once and follow the review.
• Instant notifications for new requests and account updates.
• In-trip SOS button and in-app support.

Location: the app uses your location in the background only while you are online or on a trip, to send you nearby requests and track the trip. Going offline stops tracking.

Delete account: Settings → Delete account, or https://vgo-eg.com/delete-account.html
Privacy policy: https://vgo.almobarmg.com/privacy

## Category / contact
- Category: **Maps & Navigation** (alt: Auto & Vehicles)
- Contact email: the developer account email (scooterzscooterz5@gmail.com) unless the owner names another
- Website: https://vgo-eg.com

## Graphics still needed
- App icon 512×512: from the captain launcher icon (`website/assets/img/captain-icon.png` upscaled, or the source in `V-GoCaptain/assets`).
- Feature graphic 1024×500: crop of `website/assets/img/og-captain.jpg` once Codex generates it.
- Phone screenshots (≥2, 1080×2400 OK): the existing `shot_*.png` are NOT usable (403 route error, "connecting", empty map). Need clean ones from a working, verified captain account: home online, a trip request, navigation, earnings, dues/collection.

## Data safety answers (from code)
Collected (all encrypted in transit, none sold, none used for ads):
- Personal info: name, phone number, email (optional, Google sign-in) — account management, app functionality, fraud prevention.
- Photos: profile photo + verification documents (image_picker) — account management, fraud prevention/safety.
- Government ID: national ID / licences / criminal record photos (counts under Personal info → Other / Photos).
- Location: precise, incl. background while online — app functionality.
- Financial info: earnings/dues records, wallet-transfer references (no card data) — app functionality.
- App activity: trips/in-app actions — app functionality, analytics (none).
- Messages: in-app support/chat — app functionality, customer support.
- App info & performance: crash logs (Firebase Crashlytics) — analytics/diagnostics.
- Device IDs: FCM push token — app functionality (notifications).
Shared with third parties: none beyond processors (Google/Firebase as service providers are not "sharing").
Account creation: phone OTP / Google sign-in. Deletion: in app + https://vgo-eg.com/delete-account.html
