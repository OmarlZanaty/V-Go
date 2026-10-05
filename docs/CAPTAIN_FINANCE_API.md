# Captain finance & verification — API contract

Base URL: `https://vgo.almobarmg.com/api/` (staging: `http://127.0.0.1:8090/api/` on the server).
Auth: `Authorization: Bearer <JWT>`. JSON is camelCase.

Every endpoint below answers with the same envelope:

```json
{ "isSuccess": true,  "message": "…", "data": { … } }
{ "isSuccess": false, "message": "Arabic error to show the user", "errors": null }
```

Paged results (`data`) look like:
```json
{ "data": [ … ], "totalCount": 42, "pageNumber": 1, "pageSize": 20, "totalPages": 3, "hasNextPage": true, "hasPreviousPage": false }
```
Query params for paging: `pageNumber`, `pageSize` (max 100).

## Money model

Each captain has a ledger. **Balance = sum of entries.**
- **Balance > 0** → the company owes the captain (card trips).
- **Balance < 0** → the captain owes the company (company commission on cash trips).

| Entry `type` | Sign | When |
|---|---|---|
| `TripCashCommission` | − | Cash trip ended: captain kept the fare, owes the commission |
| `TripCardEarning` | + | Card/wallet trip paid: company holds the fare, owes the captain `fare − commission` |
| `TripCorrection` | ± | A trip's settlement changed (e.g. cash refused, later paid online) |
| `Settlement` | + | Captain paid his debt via Paymob |
| `Payout` | − | Company transferred the captain's balance to InstaPay/wallet |
| `Adjustment` | ± | Manual bonus/penalty by an admin, with a reason |

Card earnings and cash commission net off automatically.

**Cash limit:** when the debt (`-balance`) reaches `cashLimit`, the captain can't go online or accept trips (enforced by the server). `cashLimit = 0` disables it. A warning is pushed at `warningPercent` of the limit.

**Online eligibility codes** (`code`): `BLOCKED`, `SUSPENDED`, `KYC_PENDING`, `KYC_UNDER_REVIEW`, `KYC_REJECTED`, `DOCS_OVERDUE`, `CASH_LIMIT`. `message` is Arabic and ready to show.

## Realtime (tripHub, `/tripHub`)

- `DriverFinanceUpdated` → `{ "balance": -320.5 }` — refresh the finance screen.
- `DriverOnlineBlocked` → `{ "canGoOnline": false, "code": "CASH_LIMIT", "message": "…" }` — the captain was taken offline. If he has no active trip, switch the app offline and explain why (settle → finance screen; KYC codes → verification screen).

The driverHub also sends `DriverOnlineBlocked` to the caller when `UpdateDriverStatus(isAvailable: true)` is refused; the server then treats him as offline.

---

## Captain endpoints (role `Driver`)

### `GET DriverFinance/me/summary`
```json
{
  "driverId": "…", "driverName": "Ahmed",
  "balance": -320.50, "owedToCompany": 320.50, "owedToDriver": 0,
  "companyCommissionPercent": 10, "cashLimit": 1000, "warningPercent": 80,
  "limitUsedPercent": 32.05, "isNearLimit": false, "isLocked": false,
  "today":  { "trips": 3, "grossFare": 150, "companyCommission": 15, "driverNet": 135, "cashCollected": 100, "onlineCollected": 50 },
  "week":   { … }, "month": { … }, "allTime": { … },
  "payoutMethod": "InstaPay", "payoutAccount": "01012345678", "payoutAccountName": "Ahmed Ali", "payoutUpdatedAt": "2026-10-05T18:00:00",
  "verificationStatus": "Approved",
  "eligibility": { "canGoOnline": true, "code": null, "message": null }
}
```

### `GET DriverFinance/me/ledger?pageNumber=1&pageSize=20&type=`
Items:
```json
{ "id": 12, "type": "TripCashCommission", "amount": -5.00,
  "tripId": "…", "tripFare": 50.00, "commissionPercent": 10, "commissionAmount": 5.00, "driverNet": 45.00,
  "tripPaymentMethod": "Cash", "paymentId": null,
  "description": "عمولة الشركة على رحلة كاش: 50 ج.م × 10%",
  "reference": null, "attachmentUrl": null, "createdByName": null, "createdAt": "2026-10-05T18:01:00" }
```
`attachmentUrl` (payouts) is an API path like `DriverFinance/ledger/12/attachment` (GET with the bearer token).

### `GET DriverFinance/me/eligibility`
`{ "canGoOnline": false, "code": "CASH_LIMIT", "message": "…" }` — call before going online.

### `PUT DriverFinance/me/payout-account`
Body: `{ "method": "InstaPay" | "MobileWallet", "account": "01012345678" | "name@instapay", "accountName": "Ahmed Ali", "password": "<current password>" }`.
Wallet = Egyptian mobile (11 digits). InstaPay = mobile or `xxx@instapay`. Admins are notified of every change.

### `POST DriverFinance/me/settle`
Creates a Paymob checkout for **exactly** what he owes (the amount is computed server-side; no body).
```json
{ "paymentId": "…", "amount": 320.50, "clientSecret": "…", "publicKey": "…",
  "checkoutUrl": "https://accept.paymob.com/unifiedcheckout/?publicKey=…&clientSecret=…" }
```
Open `checkoutUrl` in an in-app webview (same as the rider app's `custom_payment_web_view.dart`). When Paymob redirects, relay the redirect URL to the existing `POST Payment/confirm-callback` with `{ "query": "<full redirect url>" }`, then poll the status below.

### `GET DriverFinance/me/settle/{paymentId}`
`{ "paymentId": "…", "amount": 320.5, "status": "Pending|Paid|Failed", "credited": true, "balance": 0, "canGoOnline": true }`

### `GET DriverVerification/me`
```json
{ "driverId": "…", "name": "…", "phone": "…", "profilePicture": "https://…",
  "status": "PendingDocuments|UnderReview|Approved|Rejected|Suspended", "note": "reason if rejected/suspended",
  "documentsDeadline": "2026-10-12T18:00:00",
  "documents": [ { "id": "…", "type": "NationalIdFront", "status": "Pending|Approved|Rejected", "expiryDate": null, "rejectionReason": null, "uploadedAt": "…", "reviewedAt": null, "publicUrl": null } ],
  "requiredTypes": ["Selfie","NationalIdFront","NationalIdBack","DriverLicense","VehicleLicense"],
  "missingTypes": ["DriverLicense"],
  "canGoOnline": false, "blockCode": "KYC_PENDING", "blockMessage": "…" }
```
`documentsDeadline` is set only for captains who were working before verification existed: they stay online until that date, then need every document uploaded.

### `POST DriverVerification/me/documents` (multipart/form-data)
Fields: `type` (one of `requiredTypes`), `file` (JPG/PNG/WEBP, ≤ 8 MB), `expiryDate` (`yyyy-MM-dd`, **required** for `DriverLicense` and `VehicleLicense`, must be in the future).
`Selfie` must be taken with the front camera in the app (no gallery); it becomes the captain's public profile photo.
Returns the `DriverDocumentDTO`. Re-uploading a type replaces it and sends it back to review.

---

## Dashboard endpoints

Finance: roles `Admin`, `Accountant`. Verification: roles `Admin`, `Dispatcher`.

| Method & path | Body / query | Returns |
|---|---|---|
| `GET DriverFinance/admin/settings` | | `{ companyCommissionPercent, cashLimit, warningPercent, ledgerStartAt }` |
| `PUT DriverFinance/admin/settings` | `{ companyCommissionPercent: 0-100, cashLimit: >=0, warningPercent: 1-100 }` | settings |
| `GET DriverFinance/admin/overview` | | `{ totalOwedToCompany, totalOwedToDrivers, lockedDrivers, nearLimitDrivers, driversAwaitingPayout, settledThisMonth, paidOutThisMonth, commissionThisMonth }` |
| `GET DriverFinance/admin/drivers` | `search`, `filter` = `locked`/`near`/`owes`/`owed`, paging | paged `{ driverId, name, phone, profilePicture, balance, isLocked, isNearLimit, isAvailable, verificationStatus, payoutMethod, payoutAccount, payoutAccountName, lastEntryAt }` (sorted by balance, biggest debt first) |
| `GET DriverFinance/admin/drivers/{id}/summary` | | same as `me/summary` |
| `GET DriverFinance/admin/drivers/{id}/ledger` | paging, `type` | paged ledger entries |
| `POST DriverFinance/admin/drivers/{id}/adjustments` | `{ amount: ±, reason }` | ledger entry |
| `POST DriverFinance/admin/drivers/{id}/payouts` | multipart: `amount`, `reference`, `note?`, `receipt?` (image/pdf) | ledger entry. Amount can't exceed what the company owes him |
| `GET DriverFinance/admin/settlements` | `status` = `Pending`/`Paid`/`Failed`, paging | paged `{ paymentId, driverId, driverName, driverPhone, amount, status, credited, method, transactionId, createdAt, updatedAt }` |
| `GET DriverFinance/admin/audit` | `targetUserId?`, paging | paged `{ id, actorUserId, actorName, action, targetUserId, targetName, details, createdAt }` |
| `GET DriverFinance/ledger/{entryId}/attachment` | | payout receipt file |
| `GET DriverVerification/admin/queue` | `status` = `needsreview` (default) / `all` / a status name, `search`, paging | paged `{ driverId, name, phone, profilePicture, status, uploadedCount, pendingCount, rejectedCount, lastUploadAt, documentsDeadline, createdAt }` |
| `GET DriverVerification/admin/drivers/{id}` | | same as `DriverVerification/me` |
| `GET DriverVerification/admin/documents/{docId}/file` | | the private image (fetch with the bearer token → blob URL). The selfie uses `publicUrl` instead |
| `POST DriverVerification/admin/documents/{docId}/review` | `{ approve: bool, reason?: string }` (reason required to reject) | document |
| `POST DriverVerification/admin/drivers/{id}/decision` | `{ status: "Approved"|"Rejected"|"Suspended", note? }` (note required unless approving) | verification DTO |

Approving the last pending document of a complete set approves the captain automatically. `Approved` decision approves all pending documents (fails if any are missing or rejected). `Suspended` takes him offline immediately.

Audit `action` values: `FinanceSettingsUpdated`, `LedgerAdjustment`, `PayoutRecorded`, `PayoutAccountChanged`, `DocumentApproved`, `DocumentRejected`, `VerificationApproved`, `VerificationRejected`, `VerificationSuspended`.
