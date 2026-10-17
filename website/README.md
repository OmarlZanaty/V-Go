# V.Go rider and captain website

Static Arabic-first pages with an English toggle. No build step. Runtime external resources are Google Fonts and Google Identity Services only.

## Serving

Caddy serves this directory as the static root of https://vgo-eg.com. Route /api/* to the backend and /downloads/* to release storage before the static file handler. Captain activation calls POST /api/beta/enroll and GET /api/beta/enroll/status on the same origin. APK URLs are /downloads/vgo-client.apk and /downloads/vgo-captain.apk; the binaries are not bundled here. Do not return index.html for missing API or download paths.

| App | Google Play | App Store | APK |
| --- | --- | --- | --- |
| V.Go (rider) | https://play.google.com/store/apps/details?id=com.scooterapp.vgo | https://apps.apple.com/app/id6820955516 | /downloads/vgo-client.apk |
| V.Go Captain | Activation modal, package com.scooterapp.vgo.v_go_captain | https://apps.apple.com/app/id6820956040 | /downloads/vgo-captain.apk |

Rider Play links are plain anchors with no activation handler. Captain Play buttons keep class js-play-activate and data-app="captain". CONFIG continues to apply only to captain activation. Both apps have download cards in the hero and final section; all direct store and APK links work without JavaScript.

Edit index.html, privacy.html, delete-account.html and assets/js/i18n.js directly. The old _author.py generator predates hand edits and is not the source of truth. No build step is needed.

## Public CONFIG (assets/js/config.js)

| Constant | Value |
| --- | --- |
| API_BASE | '' (same origin) |
| PACKAGE | com.scooterapp.vgo.v_go_captain |
| GOOGLE_CLIENT_ID | 792221536894-fmupld3v24c6q6d3pv029kk4nhv0lb78.apps.googleusercontent.com |
| SOURCE | site-captain |
| WHATSAPP | '' — TODO: V.Go support WhatsApp |
| CONTACT_EMAIL | '' — TODO: V.Go privacy contact email |
| ACTIVATION_SECONDS | 90 |
| RESYNCED_SECONDS | 45 |
| POST_SYNC_SECONDS | 10 |
| POLL_MS | 2000 |
| MAX_HOLD_SECONDS | 75 |
| MAX_EXTRA_EMAILS | 3 |
| REQUEST_TIMEOUT_MS | 15000 |

WhatsApp takes international digits without +. While empty, its link stays hidden without a wa.me/ href, and delay copy offers retry/APK instead. While CONTACT_EMAIL is empty, the privacy page offers the real in-app Support section and hides the email link.

Before serving, confirm https://vgo-eg.com is an authorized JavaScript origin on the supplied OAuth client. No secret belongs in these static files.

## Activation contract

Ported from Cairo Shuttle Bus website/assets/js/store-activate.js and #actOverlay, following BETA_ENROLL_SYSTEM.md section 1 and PORTING.md section 3.

- One Tap first; never render a GIS fallback button.
- Typed-email fallback immediately in in-app browsers, otherwise after 2.5 seconds. All deadlines use Date.now() and are rechecked on visibilitychange.
- One primary address and up to three removable extras, trimmed and deduplicated. Sequential POSTs carry source: site-captain and either email or idToken.
- Status polls every two seconds after the preceding poll completes. All submitted addresses must sync. Rejected addresses immediately return to correction, identifying the address.
- Wait ten full seconds after sync confirmation, including returning accounts. Never automatically open a store on a timer.
- A fresh Android tap opens intent://details?id=PACKAGE#Intent;scheme=market;package=com.android.vending;end, followed by market://details?id=PACKAGE after 2.5 seconds if handoff was not observed. Never fall back to the Play website on Android. Desktop uses a user-tapped listing link; closed-test availability may differ there.
- The 75-second spinner cap starts before POST enrollment and is checked before the 90-second estimate. If sync arrives near the cap, the spinner stops at 75 seconds while the full propagation wait finishes. Unsynced visitors see retry/APK/support, never a false activation success.
- Delayed responses are explained immediately without promising email delivery the API did not confirm.
- 15-second request timeouts, cancellation and generation guards prevent stale responses from changing a closed/reopened modal. Escape, focus containment and focus restoration are supported.

Token enrollment must return the resolved email; the server must verify the token. Typed email is an enrollment request, not authentication. Existing daemon/backend retry, rejected-account and delayed behavior remain backend responsibilities.

## Source-grounded content

Captain copy is based on auth, home, trips, navigation, finance, collection, notifications, profile, verification, shell and pubspec. Earnings are part of Finance. No fixed income, immediate approval, instant payout or coverage claims are made.

Rider copy is based on V-Go/lib/features/client, map, trips, auth, onboarding and settings, plus V-Go/pubspec.yaml. Destination search/map pins, fare quotes, live captain position/ETA and trip history are present in the app. docs/PROMOTIONS_API.md documents free rides, percentage/amount discounts and promo codes; availability is qualified by offer terms and account eligibility. Backend/Masafet_Elseka.Infrastructure/Services/PaymentService/PaymentService.cs configures Paymob card and wallet methods; the site qualifies those by checkout availability.

App palette: #DCE01E, #030407, restrained #FE7600. The captain icon comes from the Captain iOS asset catalog; rider-icon.png comes from V-Go/assets/images/icon.png, matching the rider launcher mark. design/branding/logo-mark.svg is AL MOBARMG's developer mark, so it is not used for V.Go identity.

See ARTWORK.md for generated image prompts and provenance. Each WebP targets less than 300 KB. OG includes a 1200 × 630 JPEG. Below-the-fold images have lazy loading, dimensions and bilingual alt text.

## Verification

JavaScript syntax: node --check assets/js/*.js (run per file). Development-only browser checks live in qa/check.cjs; use an existing puppeteer-core installation through PUPPETEER_MODULE and an existing Chrome through CHROME_PATH. These checks mock enrollment; they never send real signup requests. qa/results.json records the result.

Additional checks: `python qa/check-static.py http://127.0.0.1:4191` validates local HTTP assets, image decoding and aspect ratios, translations, download links, and preservation of the committed activation code. It requires Pillow. `node qa/check-i18n.cjs` exercises the actual language runtime against the elements declared by all three pages, including unavailable localStorage and pages without OG metadata. Neither replaces browser layout checks.

For the rider update, static checks and language runtime checks passed against the local server. Browser verification could not run in this workspace: Puppeteer reported `spawn EPERM`, and automatic approval review rejected a headless Chrome launch as `blocked by policy`. The extended browser checks are ready, but 360px overflow, rendered language appearance, browser console output and modal interactions remain unverified for this update.

Live GIS origin configuration, backend/daemon enrollment and Android intent handoff still need an end-to-end check on the production origin and a real Android device. No commit, push or deployment is part of this task.
