# Client round 3 (2026-10-15) — API contract

REST JSON is camelCase. SignalR payloads are PascalCase (apps parse both). Admin = role `Admin`
(also allow `Dispatcher` where noted). All amounts in EGP. Dates are Egypt local time (`ToEgyptTime()`).

## A. Support inbox (client item 3: "support messages don't arrive")

Today a rider/captain support chat is assigned to a user with the `Dispatcher` role and only the old
Flutter dispatcher screens show it; the web dashboard (V-Go-Admin) has no support page, and if no
dispatcher exists `CreateSupportChat` cannot assign one. Fix:

- `CreateSupportChatAsync` must succeed even when no dispatcher is available (chat with no
  dispatcher participant). Sending a support message must never fail because of a missing dispatcher.
- Every new support message from a rider/captain is pushed to all Admin + Dispatcher users on
  `SupportChatHub` as `ReceiveSupportMessage` (in addition to the assigned dispatcher, if any).
- A reply from the dashboard reaches the rider/captain live (`ReceiveSupportMessage` on
  `SupportChatHub`, same payload as today) **and** as an FCM push notification
  ("رد من خدمة العملاء", first 100 chars of the message) via the existing notification service.

Endpoints (Admin, Dispatcher):
- `GET api/Chat/admin/support?status=open|closed|all&page=1&pageSize=30` →
  `{ data: [{ chatId, userId, userName, userPhone, userRole: "Client"|"Driver", isOpen, createdAt,
  lastMessage, lastMessageAt, lastMessageFromUser: bool, unreadCount }], totalCount }`, newest activity first.
  `unreadCount` = messages from the user after the last staff reply (no new table needed).
- `GET api/Chat/admin/support/{chatId}/messages?skip=0&take=50` →
  `[{ id, chatId, senderId, senderName, fromStaff: bool, content, sentAt }]` oldest→newest.
- `POST api/Chat/admin/support/{chatId}/reply` body `{ "content": "..." }` → the message DTO above.
  The sender is the signed-in staff user (add them as a chat participant if needed).
- `PUT api/Chat/admin/support/{chatId}/close` and `.../reopen`.
- `GET api/Chat/admin/support/unread-count` → `{ count }` (for a sidebar badge).

Dashboard: new page **«الدعم»** (sidebar item with unread badge): chat list (filter open/closed, search
by name/phone) + conversation pane with reply box; live updates through `SupportChatHub`
(`@microsoft/signalr` is already a dependency; hub path: check Program.cs `MapHub<SupportChatHub>`),
fallback polling every 15 s. Click the phone to open WhatsApp (`https://wa.me/2<phone without leading 0>`).

## B. Trip counts (client item 10)

Counts next to each figure: cash / online (Visa) trips, completed / cancelled.

- `GET api/Trip/admin/counts?from=YYYY-MM-DD&to=YYYY-MM-DD` (both optional; default all time) →
  `{ total, completed, cancelled, active, cash, online, completedCash, completedOnline, cancelledCash, cancelledOnline, free }`
  (`active` = Pending/Accepted/Arrived/InProgress; `free` = IsFreeRide trips; online = PaymentMethod "Visa").
- Finance overview revenue blocks (`revenueToday`, `revenueThisMonth`, `revenueAllTime` in
  `DriverFinance/admin/overview`) gain `cashTrips` and `onlineTrips` next to the existing `trips`.
- Captain balances list (`DriverFinance/admin/drivers`) rows gain `cashTrips`, `onlineTrips`,
  `completedTrips`, `cancelledTrips` (all time, trips where the user is the Driver).

Dashboard: rides page header shows the count chips (الكل / مكتملة / ملغية / جارية / كاش / أونلاين / مجانية)
for the selected date range; finance revenue cards show «كاش (3) · أونلاين (2)»; captain balances
table shows the per-captain counts.

## C. Busy areas for captains (client item 11)

- `GET api/Trip/hotspots?days=7` (Driver, Admin) → `[{ lat, lng, count, level }]`: pickups of trips
  created in the last `days` days (all statuses except those cancelled within 1 minute), grouped on a
  ~400 m grid (round lat/lng to 0.004), top 15 cells with count ≥ 2, `level` 1..3 by count tercile.
  Cache 10 minutes.
- Captain app: on the home map, translucent circles (radius 350 m) in the brand orange/red by level, with
  a small fire badge; refreshed every 10 min while online; a toggle chip «أماكن الطلب» to hide/show.

## D. Daily revenue history (client item 12)

- `GET api/DriverFinance/admin/revenue/daily?from=YYYY-MM-DD&to=YYYY-MM-DD` (default last 30 days) →
  `[{ date, trips, cashTrips, onlineTrips, freeTrips, total, cash, online, companyCommission }]`, one row
  per calendar day (Egypt time, by trip EndTime; completed trips only; include zero days), newest first,
  plus a totals row in `{ days: [...], totals: {...} }`.
- Dashboard finance page: «الإيراد اليومي» table with a date-range picker and CSV export.
