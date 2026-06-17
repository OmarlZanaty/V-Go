# V-Go System Audit

Scope: backend (.NET), client app (V-Go), captain app (V-GoCaptain), and the
in-app admin/dispatcher/accountant sections (there is no separate web dashboard).

Severity: 🔴 high · 🟠 medium · 🟡 low. Status updated as items are fixed.

> **Pre-authorization (Visa Auth & Capture) is intentionally excluded** — owner is
> reworking the normal Visa pay flow separately. Items #1/#7/#11 below are parked.

## 🔴 High

| # | Finding | Location | Status |
|---|---------|----------|--------|
| 1 | Visa pre-auth dormant (no Paymob Auth integration / API key) | PaymentService | **Parked** (owner) |
| 2 | `GetFileUrl` throws `NotImplementedException` (latent crash) | CloudinaryService.cs:128 | ✅ Fixed |
| 3 | Forgot-password OTP reset never tested end-to-end | AuthService.ResetPhonePassword | Needs runtime test |
| 4 | Legacy passwordless account: first login adopts any typed password (takeover risk) | AuthService.LoginWithPhone | Accepted trade-off (documented) |

## 🟠 Medium

| # | Finding | Location | Status |
|---|---------|----------|--------|
| 5 | Trip cancellation captures no reason | Trip entity / cancel flow | In progress |
| 6 | Capture-failure has no admin retry/settle UI | accountant section | **Parked** (pre-auth) |
| 7 | Captain/client Terms & Privacy is placeholder text | terms_view.dart | Needs legal content |
| 8 | No saved-cards management UI (tokens stored, not manageable) | client app | Tracked (large) |
| 9 | No driver document approval before captain goes online | captain signup / admin | Tracked (large) |
| 10 | Pre-auth expiry void doesn't notify rider/driver | PreAuthExpiryService | **Parked** (pre-auth) |
| 11 | Auth endpoints not rate-limited (brute force + phone enumeration) | AuthController | In progress |

## 🟡 Low / polish

| # | Finding | Location | Status |
|---|---------|----------|--------|
| 12 | Zero automated tests anywhere | whole repo | Tracked (large) |
| 13 | Some Identity validation messages were English | Identity | ✅ Fixed (Arabic describer + relaxed policy) |
| 14 | Builders fall through to blank `SizedBox.shrink()` for unexpected states | map/payment views | In progress |
| 15 | Push notifications carry `type` payloads but no tap-routing | notifications | Tracked |

## Notes
- "Admin dashboard" is the `features/admin`, `features/dispatcher`, `features/accountant`
  sections inside the client app — no separate web project exists.
- Backend deploys to Cloud Run (`vgo-api`); migrations auto-apply on startup.
