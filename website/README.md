# V.Go Captain marketing website

Static Arabic-first pages with an English toggle. No build step. Runtime external resources are Google Fonts and Google Identity Services only.

## Serving

Caddy serves this directory as the static root of https://vgo-eg.com. Route /api/* to the backend and /downloads/* to release storage before the static file handler. The website calls POST /api/beta/enroll and GET /api/beta/enroll/status on the same origin. The APK URL is /downloads/vgo-captain.apk; the binary is not bundled here. Do not return index.html for missing API or download paths.

App Store: https://apps.apple.com/app/id6820956040. Every Play download button has class js-play-activate and data-app="captain".

## Public CONFIG (assets/js/config.js)

| Constant | Value |
| --- | --- |
| API_BASE | '' (same origin) |
| PACKAGE | com.scooterapp.vgo.v_go_captain |
| GOOGLE_CLIENT_ID | 792221536894-qlpar24br7eecn3fkhn4b5jdttjjiqn2.apps.googleusercontent.com |
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

Read: Captain auth, home, trips, navigation, finance, collection, notifications, profile, verification, shell and pubspec. There is no separate earnings implementation in this checkout; earnings are part of Finance. No fixed income, immediate approval, instant payout or coverage claims are made. The phone UI is HTML/CSS and labeled illustrative.

App palette: #DCE01E, #030407, restrained #FE7600. The real black-on-yellow icon comes from the Captain iOS asset catalog. design/branding/logo-mark.svg is AL MOBARMG's developer mark, so it is not used for V.Go identity.

See ARTWORK.md for generated image prompts and provenance. Each WebP targets less than 300 KB. OG includes a 1200 × 630 JPEG. Below-the-fold images have lazy loading, dimensions and bilingual alt text.

## Verification

JavaScript syntax: node --check assets/js/*.js (run per file). Development-only browser checks live in qa/check.cjs; use an existing puppeteer-core installation through PUPPETEER_MODULE and an existing Chrome through CHROME_PATH. These checks mock enrollment; they never send real signup requests. qa/results.json records the result.

Live GIS origin configuration, backend/daemon enrollment and Android intent handoff still need an end-to-end check on the production origin and a real Android device. No commit, push or deployment is part of this task.
