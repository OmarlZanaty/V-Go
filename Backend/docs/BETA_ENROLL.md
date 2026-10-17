# V.Go Captain beta enrolment

The backend queues website signups. The external `infra/beta-sync/sync.js` daemon
adds their emails to the Captain closed-track email list through Play Console,
then acknowledges them. This module does not call the Play API or send tester
invitation emails. The original Firebase App Distribution fallback is deliberately
omitted; delayed signups receive the configured APK link in the enrollment response.

## Environment

Read directly from environment variables at startup; restart after changing them.
No production appsettings file is needed.

| Variable | Default / purpose |
| --- | --- |
| `BETA_SYNC_KEY` | Required to enable daemon access; provision a strong shared secret in both backend and daemon. Never place it in website code. |
| `GOOGLE_OAUTH_CLIENT_ID` | Audience for server-verified Google ID tokens. Missing configuration returns 503 for token enrollment; typed-email enrollment still works. |
| `BETA_PLAY_URL` | `https://play.google.com/store/apps/details?id=com.scooterapp.vgo.v_go_captain` |
| `BETA_APK_URL` | `https://vgo.almobarmg.com/downloads/vgo-captain.apk` |
| `BETA_TARGET_TESTERS` | Positive integer, default `20`. Invalid values fall back to 20. |

The existing SQL Server connection, Hangfire storage, and Firebase credentials
remain required by the application. Startup applies migration
`20261017120000_Beta_Enrolment`, which only creates `BetaTesters`, `AppSettings`,
and their indexes. No existing tables change. IDs are 32-character strings;
timestamps are UTC and status values on the wire are lowercase strings.

## Routes

All responses below are plain JSON, without the project's generic response wrapper.

| Method and exact path | Access / contract |
| --- | --- |
| `POST /api/beta/enroll` | Anonymous; `{email?, idToken?, source?, app?}` → `{playSynced, delayed, status, alreadyEnrolled, playUrl, downloadUrl}`. |
| `GET /api/beta/enroll/status?email=...` | Anonymous; exactly `{registered, synced, rejected, delayed}`. |
| `GET /api/beta/sync/pending` | `X-Sync-Key`; `{testers:[{id,email}]}`. Up to 100 unsynced rows, oldest enrollment first, excluding dropped/rejected. Stamps heartbeat best-effort, including empty polls. |
| `POST /api/beta/sync/done` | `X-Sync-Key`; `{ids:["..."]}` (1–100) → `{updated: count}`; sets synced, clears error, stamps last check. |
| `POST /api/beta/sync/failed` | `X-Sync-Key`; `{id, reason?}` → `{ok:true}`; records `not_a_google_account`. Also accepts the current daemon's `refused` flag (see below). Unknown ID returns 404. |
| `GET /api/beta/status` | Admin JWT; `{invited, optedIn, installed, dropped, synced, target, daemonOnline, lastPoll}`. |
| `GET /api/beta/testers?page=1&pageSize=50` | Admin JWT; `{testers, total, page, pageSize}`; pageSize 1–100, newest first. |
| `PATCH /api/beta/testers/{id}` | Admin JWT; `{status:"invited\|opted_in\|installed\|dropped"}` → `{ok:true}`. Unknown ID returns 404. |
| `POST /api/beta/testers/{id}/retry-sync` | Admin JWT; clears errors/attempts, revives dropped, returns `{playSynced:false}`. Unknown ID returns 404. |

Missing, wrong, or unconfigured sync keys return **404**, including malformed
request bodies. Keys are compared through fixed-length SHA-256 hashes using a
constant-time comparison. No application JWT is required for the daemon.

Enrollment accepts all valid email domains, including Workspace. Addresses are
trimmed and lowercased; dots and `+tags` are preserved. A supplied `idToken` takes
precedence over `email`, including when the token is invalid or empty. Verification
checks Google's signature, issuer, lifetime, audience, and verified-email flag.
`app` is accepted for website compatibility; this queue always serves Captain.
`source` defaults to `landing` and is stored on first enrollment.

Every repeat signup resets `playSynced`, clears **all** errors (including rejection),
resets attempts, and changes dropped to invited. Other lifecycle statuses remain.
`sync/done` and `sync/failed` increment `syncAttempts` once per report; the daemon's
internal browser retries are not visible to the backend. The current daemon sends
`refused:true` only when Play explicitly refuses an address, and `refused:false`
when browser automation fails. Explicit false records the reason and leaves the row
retryable, avoiding a false "not a Google account" message. Legacy requests omitting
the flag retain the documented rejection-marker behavior.

`delayed` on enrollment means no valid poll within 90 seconds. Status polling returns
delayed only for a registered, unsynced, non-rejected tester. Missing or malformed
heartbeats are offline. The heartbeat value is stored as an ISO-8601 UTC timestamp
under `AppSettings.beta_sync_last_poll`.

Enrollment has a 10-request/minute/IP fixed window; the existing global
100-request/minute/IP limiter also applies. The existing forwarded-header middleware
supplies the client IP. Keep the API behind its trusted edge proxy as in the existing
deployment. Anonymous enrollment routes have `AllowAnonymous`, no global authorization
filter requires a login, and `BlockedUserMiddleware` passes unauthenticated visitors.
The website calls relative `/api/beta/...` URLs on `https://vgo.almobarmg.com`; same-origin
requests need no CORS change. Send these public requests without an application bearer token.

## Point the daemon at V.Go

In the daemon's private, gitignored configuration, add a source with:

- `name`: `vgo-captain`
- `apiBase`: `https://vgo.almobarmg.com` (no trailing slash)
- `routePrefix`: `/api/beta`
- `syncKey`: the backend's `BETA_SYNC_KEY`, supplied privately
- `listName`: the exact existing email-list name selected on the V.Go Captain closed track
- `testersUrl`: the exact Play Console URL of that track's **Testers** tab

Do not guess `testersUrl` or `listName`. Confirm the daemon's signed-in Google account
has access to this app and the track uses an email list, not a Google Group. Restart
the daemon after configuring it. Its current request and response shapes work without
modifying `sync.js`; it passes each returned string ID back unchanged.

Check the admin status endpoint for `daemonOnline:true`, enroll a controlled test
address, then check the public status endpoint for `synced:true` and verify actual
membership in Play Console. A successful database acknowledgment alone is not proof
of continued list membership; repeat enrollment deliberately asks the daemon to check again.

## Watchdog and troubleshooting

Hangfire runs `beta-sync-watchdog` every minute. It logs and attempts one FCM push to
each active admin device per outage after 90 seconds without a poll, including when
no poll has ever arrived. The `beta_sync_outage_alerted` setting survives restarts;
a Hangfire distributed lock prevents overlapping jobs across instances. A successful
poll clears the flag, even between watchdog ticks. Push failures are logged, without
repeated attempts during the same outage. Missing admin device registrations mean only
the warning is emitted. Firebase App Distribution is not used.

If delayed, check the daemon host, login session, source configuration, and its logs.
If rejected, correct the account and re-enroll or use admin retry-sync. Installed and
opted-in lifecycle states require manual admin updates; Play membership does not prove
installation. Dropping a tester prevents queued additions; it does not remove an email
already present in the Play Console list.

## Validation

From `Backend/` with a .NET 9 SDK:

```powershell
dotnet build
dotnet test tests/Masafet_Elseka.Tests/Masafet_Elseka.Tests.csproj
```

Or from the repository root with Docker:

```powershell
docker run --rm -v "D:/Projects/V-Go/Backend:/src" -w /src mcr.microsoft.com/dotnet/sdk:9.0 dotnet build
docker run --rm -v "D:/Projects/V-Go/Backend:/src" -w /src mcr.microsoft.com/dotnet/sdk:9.0 dotnet test tests/Masafet_Elseka.Tests/Masafet_Elseka.Tests.csproj
```

The test project is not in the existing solution, so run it explicitly. Tests use
EF's in-memory provider and ASP.NET TestServer; they do not contact Google, FCM,
SQL Server, or Play Console. Validate the hand-authored migration on a disposable
SQL Server before deployment. No SDK or Docker executable was available in the
implementation sandbox, so compilation, test execution, and live integration remain
unverified there.
