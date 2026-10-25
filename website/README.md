# V.Go rider and captain website

Static Arabic-first pages with an English toggle. No build step. Runtime external resources are Google Fonts and Google Identity Services only.

## Serving

Caddy serves this directory as the static root of https://vgo-eg.com. Route /api/* to the backend before the static file handler. Captain activation calls POST /api/beta/enroll and GET /api/beta/enroll/status on the same origin. Do not return index.html for missing API paths. Serve HTML, JavaScript and CSS with `Cache-Control: no-cache` so phones revalidate updates; the current asset cache key is `20261025d`.

| App | Google Play | App Store |
| --- | --- | --- |
| V.Go (rider) | https://play.google.com/store/apps/details?id=com.scooterapp.vgo | https://apps.apple.com/app/id6820955516 |
| V.Go Captain | Activation, then the Play Store app (intent://details?id=com.scooterapp.vgo.v_go_captain) | https://apps.apple.com/app/id6820956040 |

Rider Play links are plain anchors. Captain Play buttons keep class js-play-activate and data-app="captain". CONFIG applies only to captain activation. Both apps have store cards in the hero and final section. Direct store links work without JavaScript; captain Play activation requires JavaScript.

Edit index.html, privacy.html, delete-account.html and assets/js/i18n.js directly. The legacy _author.py generator predates the dual-app layout and is not the source of truth. Its activation markup, translations, privacy explanation and asset versions are updated, but running it still replaces the page layout with its legacy captain layout. No generation step is needed for these changes.

## Public CONFIG (assets/js/config.js)

| Constant | Value |
| --- | --- |
| API_BASE | '' (same origin) |
| PACKAGE | com.scooterapp.vgo.v_go_captain |
| GOOGLE_CLIENT_ID | 792221536894-fmupld3v24c6q6d3pv029kk4nhv0lb78.apps.googleusercontent.com |
| SOURCE | site-captain |
| WHATSAPP | '' — TODO: V.Go support WhatsApp |
| CONTACT_EMAIL | '' — TODO: V.Go privacy contact email |
| POST_SYNC_SECONDS | 10 |
| POLL_MS | 2000 |
| MAX_HOLD_SECONDS | 300 |
| REQUEST_TIMEOUT_MS | 15000 |

WhatsApp takes international digits without +. While empty, its link stays hidden without a wa.me/ href. While CONTACT_EMAIL is empty, the privacy page offers the in-app Support section and hides the email link.

Before serving, confirm https://vgo-eg.com is an authorized JavaScript origin on the supplied OAuth client. No secret belongs in these static files.

## Activation contract

- Captain Play opens the modal. The visitor taps the visible Google-rendered button to open account selection directly from that user gesture. GIS uses classic popup UX with use_fedcm_for_button=false; auto_select and button_auto_select are false.
- There is an intentional extra Google-button tap: [Google does not support programmatically starting its ID-token button flow from a custom button](https://developers.google.com/identity/gsi/web/guides/offerings). Do not simulate clicks on hidden Google controls. Choosing another account and retrying return to that visible Google button.
- The selected email is displayed prominently with a bilingual reminder to match the phone's Google Play account. Choosing the account submits enrollment immediately. No confirmation screen, account text fields or extra-account controls exist.
- POST /api/beta/enroll carries exactly {idToken, source: "site-captain", app: "captain"}. The browser decodes the token to display the chosen account and poll its status; the backend verifies the token. The enrollment response has no email field.
- GET /api/beta/enroll/status?email=...&app=captain polls every two seconds after the preceding request completes. Only playSynced=true from enrollment or synced=true from status advances to the propagation wait. A rejected account returns to account selection.
- Ten seconds after sync (including returning accounts), Android gets one intent: launch targeting the Play Store app, with no market: retry or web fallback. Chrome may show its own "Continue to Google Play Store?" bar because the timer has no fresh user gesture. Our "Open Google Play" button stays hidden for eight seconds and appears only if the page remains visible without a hand-off; its tap retries the intent. Desktop goes to the web listing. [Chrome documents the user-gesture restriction](https://developer.chrome.com/docs/android/intents); there is no reliable zero-tap timer launch.
- During working, propagation and opening, #actStatus is hidden and the large #actWarn.act-stay message is visible. Delayed/holdlong and manual-fallback statuses remain visible; errors use #actErr. Recovery from a delayed response restores the main message. The manual fallback hides it.
- The 300-second cap starts before enrollment. Unsynced visitors see retry and optional support. Sync near the cap stops the spinner at 300 seconds while the main message and full ten-second propagation wait remain.
- API responses never control download navigation. Delayed responses do not promise email delivery.
- Requests time out after 15 seconds. Generation guards and cancellation prevent stale requests from changing a closed/reopened modal. GIS button state also rejects credentials from older chooser attempts.
- GIS loading failures show retry. GIS has no button-popup cancellation callback, so retry remains visible throughout account selection; after 60 seconds without a credential, the chooser attempt expires with a retry message. In-app browsers are directed to Chrome.
- Escape, focus containment and focus restoration are supported. Credentials are held only in memory and discarded after submission or dismissal.
- performance.now() records buttonClick, accountChosen, enrollResponse, synced and playRedirect. The automatic Play hand-off logs one “[vgo-activate] timings ms: ...” line with elapsed milliseconds since the original Play click. Logs contain no account or token data.

## Source-grounded content

Captain copy is based on auth, home, trips, navigation, finance, collection, notifications, profile, verification, shell and pubspec. Earnings are part of Finance. No fixed income, immediate approval, instant payout or coverage claims are made.

Rider copy is based on V-Go/lib/features/client, map, trips, auth, onboarding and settings, plus V-Go/pubspec.yaml. Destination search/map pins, fare quotes, live captain position/ETA and trip history are present in the app. docs/PROMOTIONS_API.md documents free rides, percentage/amount discounts and promo codes; availability is qualified by offer terms and account eligibility. Backend/Masafet_Elseka.Infrastructure/Services/PaymentService/PaymentService.cs configures Paymob card and wallet methods; the site qualifies those by checkout availability.

App palette: #DCE01E, #030407, restrained #FE7600. The captain icon comes from the Captain iOS asset catalog; rider-icon.png comes from V-Go/assets/images/icon.png, matching the rider launcher mark. design/branding/logo-mark.svg is AL MOBARMG's developer mark, so it is not used for V.Go identity.

See ARTWORK.md for generated image prompts and provenance. Each WebP targets less than 300 KB. OG includes a 1200 × 630 JPEG. Below-the-fold images have lazy loading, dimensions and bilingual alt text.

## Verification

Run from the repository root:

```text
node --check website/assets/js/config.js
node --check website/assets/js/i18n.js
node --check website/assets/js/store-activate.js
python website/qa/check-static.py
node website/qa/check-i18n.cjs
node website/qa/check-activation.cjs
```

Static checks require Pillow and run without network when no server URL is supplied. They check local assets (including cache query keys), image decoding, translation coverage, store links, the large stay-message class and generator parity. An optional local server URL also checks HTTP assets. The language check exercises all three pages. The activation check runs the real script with a fake DOM, clock, GIS and enrollment service; it covers immediate enrollment, payloads, quiet statuses, delayed recovery, propagation, the exact eight-second fallback, visibility hand-off, deadlines, retries, stale work and timing privacy without contacting Google or the backend.

qa/check.cjs contains browser layout and interaction checks with mocked GIS/enrollment. Use an existing puppeteer-core through PUPPETEER_MODULE and Chrome through CHROME_PATH. It writes local screenshots and qa/results.json. Offline checks do not verify Chrome's native app-launch prompt.

Live GIS account selection, authorized-origin settings, backend enrollment, rendered mobile/desktop layout and the closed-testing Play handoff remain unverified. Check the production origin on Android Chrome and desktop with real tester accounts.

For architecture, daemon operation and reuse in another project, see [Play beta activation system](../docs/PLAY_BETA_ACTIVATION_SYSTEM.md).
