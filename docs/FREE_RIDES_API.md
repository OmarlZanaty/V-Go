# Free rides promo — API contract

Client request (2026-10-14): the first 100 riders who sign up get their first 2 rides free.
The company pays the captain for those rides.

## Rules (backend is the only source of truth)

- `PricingRule` gets: `FreeRidesEnabled` (bool, default **true**), `FreeRidesPerRider` (int, default 2),
  `FreeRidesRiderLimit` (int, default 100).
- `ApplicationUser` gets `FreeRidesGranted` (int, default 0).
- A rider is granted `FreeRidesPerRider` rides **when a new Client account is created** (every client sign-up
  path: phone register, Google/social sign-in that creates a client, email register), if the promo is enabled
  and fewer than `FreeRidesRiderLimit` users have `FreeRidesGranted > 0`. The count + grant must be atomic
  (e.g. `sp_getapplock` or a serializable transaction) so the limit is never exceeded. Existing accounts are
  not granted retroactively. Staff/captain accounts are never granted.
- Used free rides = trips of that rider (UserTripRole.Client) with `IsFreeRide = true` and status **not**
  Cancelled. A cancelled free trip gives the ride back.
- `Trip` gets `IsFreeRide` (bool, default false). `AddTrip` sets it when `granted - used > 0` and the promo is
  enabled. A free trip is always `PaymentMethod = "Cash"` (no Paymob at all) — the rider pays nothing and the
  captain collects nothing.
- `Trip.Price` stays the real fare (distance × price/km, rounded up). The rider's price for a free trip is 0.
- Ledger: new `LedgerEntryType.TripFreeRideEarning = 8` — the company owes the captain his share
  (`fare − commission`), amount `+share`. Payment rows are ignored for free trips (no cash commission, no
  rider debt / outstanding-debt, no "client refused" path).
- Commission is in **whole pounds**: `commission = Math.Round(fare * percent / 100, 0, MidpointRounding.AwayFromZero)`
  for all new trip ledger entries (fare is already a whole number, so the share is too). Apply the same rounding
  wherever a commission/captain share is computed for display (DriverService, StatisticsService).

## Endpoints

REST JSON is camelCase. SignalR payloads are PascalCase (apps parse both).

### `GET api/Trip/quote` (existing) — add fields
```json
{ "distanceKm": 4.2, "price": 24, "source": "osrm",
  "isFreeRide": true, "riderPrice": 0, "freeRidesLeft": 2 }
```
`isFreeRide`/`freeRidesLeft` are computed for the signed-in rider (false / 0 when anonymous or not eligible).
`riderPrice` = 0 when `isFreeRide`, else `price`.

### `GET api/User/me/free-rides` (new, any signed-in user)
```json
{ "enabled": true, "granted": 2, "used": 1, "remaining": 1 }
```

### Trip payloads — add `isFreeRide` / `IsFreeRide`
`TripResponseDTO`, `TripDetailsDTO`, `DashboardTripDTO`, current-trip responses, and every SignalR payload
that carries a trip/offer to the captain or rider (new trip offer, accepted, started, ended, current trip).

### Admin (role Admin)
- `GET api/FreeRides/admin/settings` →
  `{ "enabled": true, "perRider": 2, "riderLimit": 100, "grantedRiders": 37, "freeRidesUsed": 21, "freeRidesCompleted": 18, "companyCost": 412 }`
  (`companyCost` = sum of `TripFreeRideEarning` ledger amounts.)
- `PUT api/FreeRides/admin/settings` body `{ "enabled": true, "perRider": 2, "riderLimit": 100 }` → same shape as GET.
  Validation: perRider 0–10, riderLimit 0–100000.

## UI copy (Arabic)
- Rider, before booking (quote is free): price line shows `مجانية 🎁` with the real fare struck through, and a
  hint `رحلة مجانية من V-Go — باقي لك N رحلة مجانية`.
- Rider, trip/receipt screens: `0 ج.م — رحلة مجانية`.
- Captain, offer + active trip + end of trip: badge `رحلة مجانية على حساب الشركة`, and at the end
  `متحصّلش فلوس من العميل — نصيبك هيتضاف لرصيدك`. The cash-collection confirmation step is skipped for free trips.
