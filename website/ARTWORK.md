# V.Go website artwork

All shipped artwork is V.Go brand photography supplied by the client. The 18 originals were exported from
the client's Google Drive folder "v-go website" on 2026-11-02 and live in `website/_src/` (gitignored —
they are 1.6-3.2 MB each; re-download them from Drive if the folder is missing).

Earlier generated 3D artwork and its prompts were dropped with this swap: no shipped file is generated
any more, so the prompts no longer described anything on the site.

## Pipeline

`_images.json` maps each site slot to its source file; `python _optimize.py` fits and exports every slot
into `assets/img/`. Sizes follow the width/height attributes in `index.html`:

| Slot kind | Output |
| --- | --- |
| `og-*` | 1200 x 630 JPEG, quality 88 |
| anything containing `feature-` or `step-` (captain and rider cards) | 800 x 600 WebP |
| `earnings-finance` | 1200 x 800 WebP |
| heroes and `cta-city-night` | 1536 x 1024 WebP |

WebP quality starts at 85 and steps down until the file is under 300,000 bytes. `captain-icon.png` and
`favicon.png` are still regenerated from the captain app icon at the end of the script.

## Source -> slot

| Source (`_src/`) | Slot | Subject |
| --- | --- | --- |
| book-and-track.png | hero-vgo-rider.webp | captain riding a lime-yellow scooter on a sunlit street |
| pick-route-request.png | rider-feature-route.webp | hand holding a phone with the rider app home screen |
| payment-options.png | rider-feature-payment.webp | rider handing the fare to a captain |
| ride-offers.png | rider-feature-offers.webp | black V.Go "offer for you" card |
| download-register.png | rider-step-account.webp, step-download.webp | phone showing the app sign-up screen |
| where-to-today.png | rider-step-book.webp | rider picking a destination on the map |
| meet-captain.png | rider-step-meet.webp | rider meeting his captain in front of a mosque |
| extra-v-go1.png | hero-cairo-captain.webp | captain beside his parked scooter on a quiet street |
| trip-requests.png | feature-trip-requests.webp | new trip request beside V.Go keys and an agreement |
| turn-by-turn-navigation.png | feature-navigation.webp | glowing route with distance pins along the road |
| earnings-accounts.png | feature-earnings.webp, earnings-finance.webp | laptop and phone with the earnings dashboard |
| trip-accounting.png | feature-collection.webp | notebook of trip notes beside V.Go cards |
| sign-documents.png | feature-verification.webp | V.Go contract with a pen, ready to sign |
| notifications.png | feature-notifications.webp | phone with V.Go notification cards |
| complete-documents.png | step-verification.webp | captain holding his phone with the app open |
| go-online.png | step-first-trip.webp | captain on his scooter in a city square |
| why-drive-vgo.png | cta-city-night.webp | captain riding past the Suez governorate building |
| cover.png | og-vgo.jpg, og-captain.jpg | V.Go street billboard, "من هنا لهناك V.Go معاك" |

`cta-city-night.webp` keeps its filename for HTML stability although the photo is no longer a night scene.
`rider-icon.png` and `captain-icon.png` are app icons, not photography, and were left untouched.

## Alt text

Every slot's Arabic and English alt text was rewritten to describe the real photo. The strings live in
three places that must stay in sync: `index.html`, `_author.py` (page generator) and
`assets/js/i18n.js` (keys `alt.<slot>`, both the `ar` and `en` blocks).
