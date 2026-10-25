# Play beta activation system

## Purpose

Let a visitor install a closed-testing Google Play app from its website in roughly
15–20 seconds after choosing a Google account, assuming a warm daemon and healthy
backend. This is the observed activation target, not a guarantee or download time.
The selected account must match the account used in the phone's Play Store.

## Components and data flow

1. The website opens the captain modal. The visitor taps the Google Identity
   Services (GIS) button; its classic popup returns an `idToken`.
2. The page immediately posts `{idToken, source, app}` to `/api/beta/enroll`.
   The backend verifies the token and queues the email. The page polls
   `/api/beta/enroll/status?email=...&app=captain` every two seconds after the
   preceding request completes. See [backend contract](../Backend/docs/BETA_ENROLL.md).
3. The local daemon at
   `D:\Projects\Cairo Shuttle Bus\infra\beta-sync\sync.js` polls each enabled
   source's `<apiBase><routePrefix>/sync/pending` on a two-second cycle. Backend
   polls run in parallel with a four-second timeout. Cycles skip while console
   work is busy; the two-second interval is not a latency guarantee.
4. Puppeteer drives Chrome using a persistent Play Console login. A warm tab per
   source opens the closed track's Testers page, adds the email to its email list,
   saves, reopens the list to verify it, then acknowledges `/sync/done`.
   Console edits are serialized through the shared browser.
5. On `playSynced: true` from enrollment or `synced: true` from status, the page
   waits `POST_SYNC_SECONDS = 10`, then attempts to open the Play Store app.
   Android gets one `intent://details?id=<PACKAGE>#Intent;scheme=market;package=com.android.vending;end`.
   Desktop uses the web listing. API download URLs do not control navigation.

During normal progress, the large bilingual stay message is shown and routine
status text is hidden. Delays, errors and the manual fallback remain visible.
Chrome may require a tap on its native launch bar. Only after eight seconds,
if the page stayed visible with no hand-off, does the website offer its own
"Open Google Play" button. There is no timed `market:` retry.

## Configuration and operation

`config.local.json` in the daemon directory overrides defaults by source `name`:

| Field | Purpose |
| --- | --- |
| `name` | Unique source identifier, such as `vgo`. |
| `apiBase` | Backend origin. |
| `routePrefix` | Endpoint prefix, `/api/beta` for V.Go. |
| `listName` | Exact Play Console email-list name, selected for the closed track. |
| `testersUrl` | Closed track's **Testers tab URL**, not a public testing link. |
| `syncKey` | Secret matching the backend; sent as `X-Sync-Key`. Keep it out of site assets and logs. |

Top-level `pollMs` is `2000`; `chromePath` and `userDataDir` select Chrome and its
persistent profile. A top-level `syncKey` can supply a source without its own key.
Blank required fields disable a source through `mergeSources()` without deleting
code. As of 2026-10-25, `csb` and `samafox` have `testersUrl: ""` because their apps
are approved; `vgo` remains configured.

- Install the daemon dependencies and sign its dedicated Chrome profile into
  Play Console. The login needs access to the app and permission to manage testing
  tracks; V.Go uses a different developer account from the other sources.
- Launch `run-hidden.vbs`; it hides the console running `run-beta-sync.bat`.
  The batch file runs `node sync.js` and restarts it ten seconds after exit.
  Chrome itself remains headed so an operator can complete login when needed.
- `beta-sync.lock` holds the daemon PID to prevent two instances sharing one
  Chrome profile. Config is read at startup: restart the existing daemon after
  editing it; launching another instance does not reload the running one.
- Inspect `beta-sync.log` (rotated at 5 MB to `.log.1`) and recent
  `error-*.png` screenshots for failures. Startup logs list enabled/skipped sources.

## Lessons learned

These are project observations, including the timings reported in the handoff;
they should be rechecked for a new app or Chrome version.

- An internal-test link showed a black page to closed testers; use the matching closed track.
- Closed testers on the configured email list installed directly from the Store app, with no opt-in page in this flow.
- Android needs an app scheme (`intent:` / `market:`): these closed-test listings returned 404 on the Play website. This implementation uses only `intent:`.
- Chrome needs a fresh tap to launch the store reliably; the timer produced a "Continue to Google Play Store?" bar. There is no reliable zero-tap workaround for the [documented gesture restriction](https://developer.chrome.com/docs/android/intents).
- FedCM button mode (`use_fedcm_for_button`) blacked out the page on Android; use the classic popup with that flag set to `false`.
- Missing cache headers left phones on an old page; serve HTML/JS/CSS with `Cache-Control: no-cache`, and bump asset query keys when releasing updates.
- The backend enroll response has no email field; retain the token's decoded email for polling, while the backend independently verifies the signed token.
- Backend calls need a four-second timeout and parallel source polling; one dead backend previously delayed everyone (33 seconds reduced to about four).
- Observed timings: enrollment 0.3 seconds, Play Console edit 3–8.5 seconds, propagation wait 10 seconds; polling, user taps and cold tabs can add time.

## Reuse checklist

- [ ] Create an OAuth web client and authorize the site's exact JavaScript origin.
- [ ] Prepare a closed-testing track, release and selected email list; copy its Testers tab URL.
- [ ] Implement token-verifying enrollment/status and authenticated pending/done/failed sync endpoints; provision the same private sync key in backend and daemon.
- [ ] Add the daemon source entry and verify the Chrome login can edit that app's list; restart the existing daemon and check its startup log.
- [ ] Set website `PACKAGE`, `GOOGLE_CLIENT_ID`, `API_BASE` and `SOURCE`; retain the ten-second post-sync wait initially.
- [ ] Proxy `/api/*` to the backend and serve HTML/JS/CSS with `Cache-Control: no-cache`.
- [ ] Test with a fresh Google account in Android Chrome: enroll, verify list membership, wait for sync, accept the launch prompt, and install using that same Play account.
