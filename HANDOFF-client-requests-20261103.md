# Client requests from the VGO WhatsApp group (2026-11-02) — status

Source: VGO group, messages of 2026-11-02 from "Saso" (+20 10 18090910).
Code fixes are in commit `ae0956c` on `captain-maplibre-pilot`.

| # | Request | Status |
| --- | --- | --- |
| 1 | Captain activation stuck on "التفعيل متأخر حاليًا" | Diagnosed — needs a Play Console action (below) |
| 2 | Video proving the captain gets several offers at once | Code is done; needs a fresh captain build |
| 3 | Trip complete for the captain, still open for the rider | Fixed + backend deployed |
| 4 | The trip rating disappears | Fixed + backend deployed |
| 5 | Pin shows "Suez Governorate" instead of the street | Fixed (app build needed) |
| 6 | Route line missing or on a different path | Fixed (app build needed) |
| 7 | Instagram link in the app and on the website | Site live; app build needed |

## 1. Captain activation — the daemon, not the site

`BetaService.EnrollStatusAsync` reports `delayed` when the beta-sync daemon's heartbeat is older
than 90 s. The daemon (`D:\Projects\Cairo Shuttle Bus\infra\beta-sync`) has been failing on the V.Go
source since **2026-10-31 16:18Z** — every cycle logs

```
[vgo] tester table did not render — reloading once
prewarm failed: Waiting for selector `button[aria-label="Edit email list vgo-captain-web"]` ... 120000ms exceeded
```

Its Chrome is still signed in and parked on the right page ("Release track | V.Go Captain"), the
Testers tab renders, but the email-lists area shows only "Create email list": the list
**`vgo-captain-web` is no longer on that track**, so no tester can ever be added. Last successful
ack: `mostafasalaheldin32@gmail.com`, 2026-10-31 15:56Z.

Owner action: re-create or re-attach `vgo-captain-web` on the V.Go Captain closed track, or point
`config.local.json` → source `vgo` → `testersUrl` at the list that is actually selected there.

Worth doing afterwards: make the daemon stop stamping that source's heartbeat after N consecutive
prewarm failures, so the site reports the outage instead of telling captains "delayed" for days.

## 2–7. What shipped

- **#3** `V-GoCaptain/lib/core/services/realtime_service.dart` — `ConfirmCashPayment` and
  `ReportPaymentRefused` now pass `checkResult: true`. A refused confirmation was swallowed, so the
  captain's panel closed while the rider stayed locked on "الدفع نقدًا يؤكده الكابتن".
  `PaymentService.ConfirmCashPaymentByDriverAsync` now treats an already-paid trip as success, so a
  retry re-notifies the rider.
- **#4** The live completion screen was the only place to rate. `TripDetailsDTO.IsRatedByMe` (set in
  `TripService.GetByUserId`) plus `V-Go/lib/features/trips/presentation/widgets/trip_rating_section.dart`
  put the rating on the trip's own page until it is submitted.
- **#5** `MapService.reverseGeocodeOsm` (Photon → Nominatim → nearest Suez gazetteer place) sits
  between Google and the device geocoder in `MapRepo.getAddressFromCoordinates`.
- **#6** `MapBloc`: moving a pin clears the old line and forces a recalculation past the 3 s GPS
  throttle; a late answer from a slow provider is dropped instead of being drawn.
- **#7** Instagram `https://www.instagram.com/v.go.eg` in both apps' settings and in the site footer
  (ar/en). Facebook, TikTok and WhatsApp Business are still waiting on links from the client.

## Still to do

- Play Console: item 1 above.
- Builds: rider and captain AABs/APKs through Codemagic so #2, #5, #6 and #7 reach the phones.
- Old trips keep the address they were saved with, so "Suez Governorate" stays in their history.
