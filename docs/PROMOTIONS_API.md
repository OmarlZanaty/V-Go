# Promotions (offers) — API contract

Replaces the single free-rides setting (2026-10-16). The old offer became promotion #1 (same state,
riders and past free trips). The company always pays the discount: the captain's share is taken from
the full fare.

## Model

- `Promotion`: `title`, `description?`, `type` (1 FreeRide, 2 PercentOff, 3 AmountOff), `value`
  (percent or EGP; 0 for free), `maxDiscount?` (cap for percent), `audience` (1 NewRiders — granted at
  sign-up while it runs, 2 AllRiders — joined on first use, 3 PromoCode — rider enters `code`),
  `ridesPerRider`, `riderLimit?` (null = no limit), `isActive`, `startsAt?`, `endsAt?` (Cairo time).
- `PromotionGrant`: one row per rider who joined an offer; the rider limit counts these rows.
- `Trip.PromotionId`, `Trip.DiscountAmount` (whole pounds). Rider pays `Price - DiscountAmount`.
  `IsFreeRide` = discount covers the whole fare (always Cash, no Paymob).
- A ride is "used" unless the trip is Canceled/Rejected (cancelling gives it back).
- Best offer wins: largest discount, then the one ending first.

## Ledger (captain)

- Free ride: `TripFreeRideEarning` = fare − commission (+).
- Cash with a discount: `TripCashDiscount` (= 9) = discount − commission (the captain collected
  fare − discount).
- Card with a discount: `TripCardEarning` = fare − commission, as without a discount.

## Endpoints (REST camelCase; SignalR PascalCase)

Rider (signed in):
- `GET api/Trip/quote` adds `discount`, `promotionId`, `promotionTitle`, `promotionType`,
  `promotionRidesLeft`; `riderPrice = price - discount`. `isFreeRide`/`freeRidesLeft` kept for old apps.
- `GET api/Promotions/mine` → offers usable now: `id, title, description, type, value, maxDiscount,
  ridesPerRider, ridesUsed, ridesLeft, endsAt, code`.
- `POST api/Promotions/redeem` `{ code }` → `{ message, promotion }`; 404 wrong code, 400 ended /
  full / used up.
- `GET api/User/me/free-rides` (old apps) — computed from free-ride offers.

Trip payloads (DTOs and hub events: new offer, accepted, arrived, started, ended, current trip) carry
`DiscountAmount` and `RiderPrice`.

Admin (role Admin):
- `GET api/Promotions/admin` → list with `isRunning, grantedRiders, ridesUsed, ridesCompleted,
  companyCost` (discounts on completed trips).
- `POST api/Promotions/admin`, `PUT api/Promotions/admin/{id}` (same body as the model),
  `PUT api/Promotions/admin/{id}/active?value=true|false`, `DELETE api/Promotions/admin/{id}`
  (refused once trips used it — stop it instead).
- Reports: `Trip/admin/counts` adds `withOffer`; `DriverFinance/admin/revenue/daily` adds `discounts`
  and its totals are what riders paid.
