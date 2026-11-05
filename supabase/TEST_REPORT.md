# Staging verification report

Status: PARTIAL. Updated 2026-11-05 (Asia/Saigon). Base commit: 93b1850;
implementation remains in the uncommitted working tree. No commit, push,
GitHub Release, update-feed publication or TikTok account write was performed.

## Verified

| Check | Result | Evidence / limit |
| --- | --- | --- |
| Node regression | PASS | 32 tests on November 5, including PostgreSQL RLS, account handler and staging workflow |
| Python regression | PASS | 9 tests on November 5, including native Auth callback/plist preservation, signer rejection and packaging |
| Flutter regression | PASS | 50 tests on November 5, including mobile Auth/session/UI and WebView profile-route preservation |
| Active Flutter analyzer | PASS | main, active UI/widgets, Auth/session service, deletion engine and tests on November 5; legacy Dashboard getCookie errors remain separate |
| Obfuscated extension | PASS | Production build with staging public configuration; 8 Node tests on November 4 |
| Staging database | PASS | Three migrations applied through Dashboard SQL; all six application tables have RLS enabled |
| Hosted RLS/RPC fixture | PASS | staging_rls_check.sql executed on November 4: A/B isolation, role/Premium denial, device limit/revoke, expired Premium, suspension and audit. Transaction ended with ROLLBACK |
| Account Edge Function | PASS | Deployed; missing bearer and deliberately invalid bearer both return HTTP 401, rechecked November 5 |
| Auth public settings | PASS | Email provider enabled, signup allowed, email auto-confirm disabled |
| Mobile callback allowlist | PASS | Dashboard confirmed adding cleartok://auth-callback; native callback execution remains untested |
| GitHub staging environment | PASS | SUPABASE_URL and public SUPABASE_PUBLISHABLE_KEY saved through BrowserSkill on November 4 |
| Manual workflow isolation | PASS | Source test verifies staging workflow_dispatch, push-only release, npm ci and separate symbol artifacts |
| Admin browser initial/connection state | PASS | BrowserSkill verified connection form then login form. Fixed author CSS overriding hidden attributes |
| Admin invalid login | PASS | November 5: nonexistent fixture rejected; panel hidden and password field cleared |
| Staging Admin bootstrap | PASS | Owner manually created one test account; verified exact Auth UUID, active profile and confirmed flag. Bootstrap yielded admin/active and exactly one bootstrap_admin audit record |
| Hosted Admin login / Users | PASS | November 5: password entered manually; backend-authenticated Admin Users page returned the test account |
| Hosted Dashboard / Plans / Audit UI | PASS | Dashboard totals read successfully. Granted Premium to the owner's staging test account via UI, then restored Free. Independent SQL verified admin/active/free/active and two premium audit records; Audit Logs displayed the changes |
| Hosted Devices / Feature Flags / search UI | PASS | Devices empty state returned successfully; Feature Flags returned three configured features; Users search returned the matching test account |
| Hosted Admin logout | PASS | November 5: signOut returned to the login form with the administrative panel hidden |

Staging project: cleartok-staging, reference jsxxxbspjmpbaomotgcj,
US East / North Virginia (owner explicitly approved this region).
API: https://jsxxxbspjmpbaomotgcj.supabase.co/functions/v1/account.
JWT verification runs through auth.getUser() in the handler; only the gateway's
legacy-secret verifier is disabled. No service-role key is required by this function.

## BLOCKED / not tested

Mobile Auth UI/flow source is implemented. Detailed results, changed interfaces,
isolated APK build failure and native acceptance matrix: [MOBILE_AUTH.md](MOBILE_AUTH.md).
The Dart/assets debug bundle compiled; an installable APK/IPA is not verified.

- App self-registration, email confirmation, password recovery, refresh/session
  restoration and the remaining full Admin UI mutations are not verified.
  One persistent test Admin has been
  bootstrapped and logged in through the browser. Premium grant/revoke through
  Admin UI and the corresponding audit records passed; blocked-user/device tests
  currently use the hosted rollback fixture rather than separate live Auth users.
- No custom SMTP is configured. The owner confirmed they do not have an SMTP
  provider. Dashboard default email limit was 2/hour; email delivery is untested.
  Do not disable email confirmation to hide this limitation.
- Chrome/Edge extension installation and Auth UI were not tested in the browser.
  The eight production-directory tests are Node tests, not browser E2E evidence.
- BrowserSkill's November 4 invalid-login attempt was interrupted by an
  unresponsive frame; the November 5 invalid-login retry passed. Successful
  privileged login and Admin mutations remain separate checks.
- Android production is BLOCKED: downloaded v2.3.25 APK was actually signed
  with CN=Android Debug, certificate SHA-256
  23f8da7dba6053958ff7befe98525306c670f4373807ff9f32357fb0e3ce6c1e.
  APK SHA-256: 6cce28cf5285fac52d19d61dca08b6d4b2470cd1a491845c260b1425f422c66d.
  No verified production keystore is configured. Scripts reject debug keys;
  no key, application ID or signing identity was silently replaced.
- iOS obfuscated IPA is BLOCKED on Windows; revised macOS Actions workflow has
  not been uploaded or executed. Native plugins, signatures, post-obfuscation
  operation and re-signing remain unverified.
- No new APK/IPA or native symbol/mapping artifact exists. Workflow tests do not
  prove CI builds work. Uploading the workflow still requires owner approval.
- Concurrent multi-connection enrollment, global Auth session revocation,
  configurable device limits, historical registration charts, user pagination
  and secure native session-storage migration remain outside verified completion.

## Distribution checks and limits

Local extension and Admin archives are under build/staging/dist with SHA-256
sidecars. They are working-tree test builds, not a published release or a clean
commit build. Rebuild after any source change before handing them to a tester.
Archive checks verify CRC and exclude private file names, source maps, environment
files, split symbols and R8 mapping. This is not proof against every possible
embedded secret. No private project key was extracted for these builds.

Local TikTok execution remains bypassable in a modified client. The backend
only authorizes ClearTok requests and never proxies TikTok credentials.
