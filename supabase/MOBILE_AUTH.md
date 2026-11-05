# Mobile Auth implementation and validation

Date: 2026-11-05 (Asia/Saigon). Source implementation complete; native acceptance PARTIAL.
No commit, push, release publication, database migration or real TikTok write was performed.

## Delivered behavior

- Liquid Glass login, registration, email-verification guidance/resend, forgot/reset password,
  profile/plan/expiry, device revocation confirmation and ClearTok-only logout.
- Shared account session controller handles initial validation, duplicate requests, stale
  responses after logout/account changes, token refresh without removing approved content,
  recovery precedence and permission denial. Server 401/403 invalidates access and stops batches.
- Auth callback listener is established before Hive/remote-config startup finishes. Only the
  exact cleartok://auth-callback URI with Auth parameters is handed to the Supabase SDK;
  the gate remains blocked until the SDK reports signed-in or password recovery.
- Profile opens as a Navigator route from the Studio menu. The floating account overlay was
  removed; tests confirm the existing WebView State and size survive opening/closing profile.
- Existing Hive data and TikTok cookies are not cleared by account actions. Device UUID uses
  the existing shared-preferences key. No account-data migration was introduced.
- Shared colors/glass shader/buttons/credits/logo reused. Keyboard scrolling, 440dp maximum
  form width, 48dp targets, password visibility/autofill, large type, semantics and Reduce Motion.
- Android disables Flutter's duplicate deep-link handler; existing scheme/host/activity remain.
  iOS packaging configures the same scheme and FlutterDeepLinkingEnabled=false idempotently.

## Files and interfaces

- lib/ui/screens/cleartok_account_screen.dart: existing ClearTokAccountGate(child:...) remains
  compatible; optional session parameter and openAccount(context) added for early boot/profile.
- lib/services/cleartok_account_session.dart and cleartok_account.dart: state/operations,
  sanitized errors, exact callback predicate and access-invalidated notification.
- lib/main.dart: early SDK callback/session wiring; optional accountSession on ClearTokApp.
- RepostStudioScreen menu, TikTokDeletionEngine listener/error cancellation, shared glass
  Reduce Motion behavior, AndroidManifest.xml and scripts/build_obfuscated.py are connected.
- Test fixtures use the existing Supabase SDK with HTTP/PKCE/JSON fixtures. Existing transitive
  yet_another_json_isolate 2.1.1 is explicitly declared as a dev dependency for the SDK test seam;
  no Flutter, Supabase or runtime package version was upgraded.

## Executed checks

| Check | Result |
| --- | --- |
| Full Flutter regression | PASS: 50 tests |
| Node/backend regression | PASS: 32 tests |
| Python regression | PASS: 9 tests, including Android callback/iOS plist preservation |
| Analyzer: active main/UI/widgets/Auth/engine/tests | PASS: no issues |
| Formatter check | PASS |
| git diff --check | PASS |
| Dart/assets debug bundle with public staging configuration | PASS |
| Auth preview | build/ui-previews/cleartok-login.png, rendered with real test fonts |

Auth cases include form validation/visibility, signup/verification/resend, recovery,
loading, generic network/auth errors, repeated submit, logout while check is pending,
token refresh, early callback hold, 403, own-device revocation, profile lifecycle,
large text/keyboard/landscape and stopping the next mocked TikTok write without
removing unprocessed cache items.

Broad analysis of all lib/ui still reports the existing unused Dashboard field and two
getCookie errors plus async-context lint in dashboard_screen.dart. It was not changed.

## Native acceptance (not substituted by widget tests)

| Test | Android | iOS |
| --- | --- | --- |
| Native email/password login | NOT TESTED | NOT TESTED |
| Restart/session restoration | NOT TESTED | NOT TESTED |
| Email verification callback | NOT TESTED | NOT TESTED |
| Password recovery callback, cold/warm start | NOT TESTED | NOT TESTED |
| Logout/login and permissions/device denial | NOT TESTED | NOT TESTED |
| Native WebView preservation/cookie persistence | NOT TESTED | NOT TESTED |

Android debug APK was attempted in build/mobile-auth-validation/project, using a copy
of the source and the same Flutter-create scaffolding/desugaring configuration as CI.
It failed before app compilation: Gradle 8.14 / installed Java 25.0.4.1 caused
IllegalArgumentException at org.jetbrains.kotlin.com.intellij.util.lang.JavaVersion.parse.
Stacktrace: build/mobile-auth-validation/gradle-failure.log. JDK 17 is required by CI;
no global JDK/Gradle/Flutter setting was changed to work around this failure.
Android production also still needs an approved compatible production signer.
iOS build/runtime is unavailable on this Windows host and requires macOS/Xcode.
No new installable APK/IPA is delivered or claimed to work on-device.

## Next native verification

1. Use a disposable source copy and JDK 17/Android SDK as configured in release.yml;
   generate Android scaffolding and apply its notification desugaring step. Build debug
   with the staging public URL/key, then install only on an authorized test device/emulator.
2. On macOS use the same Flutter version/scaffolding/iOS deployment target as release.yml.
   Before a simulator debug build, configure the generated plist using
   scripts.build_obfuscated.configure_ios_callback(Path('ios/Runner/Info.plist')).
   Production packaging already calls this helper. Keep Bundle Identifier/signing unchanged.
3. Run the native matrix above with manually entered test credentials. Do not record
   callback query/fragment contents, passwords, cookies or tokens. Default staging email
   delivery has a 2/hour limit and no custom SMTP; delivery/recovery remain unverified.
4. Mark native acceptance PASS only after runtime evidence exists on each platform.
   Existing no-commit/push/publish restriction still applies to running revised remote CI.

## Rollback

Revert only this mobile Auth patch, preserving earlier backend/Phase-1/developer diffs.
Restore the previous account gate and its caller/native callback changes together.
No database/Hive migration or reverse migration is needed. Do not reset the whole
workspace, clear TikTok cookies or delete local data to roll back the UI.
