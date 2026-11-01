# ClearTok Pro Web · Chrome / Edge

This is the full local web dashboard, packaged as a Manifest V3 extension. It scans and manages Reposts, Likes, and Following using your selected TikTok tab. It is separate from the diagnostic-only web companion.

## Install

1. Extract the `ClearTok-Pro-Web-vX.Y.Z.zip` release asset to a permanent folder.
2. Open `chrome://extensions` or `edge://extensions`. Enable Developer mode.
3. Choose Load unpacked and select the extracted folder containing manifest.json.
4. Click the ClearTok extension action (pin it from the extensions menu if needed).
5. Choose Open TikTok, sign in on TikTok itself, return to Studio, refresh tabs and Connect.
6. Choose Reposts / Likes / Following and scan 50, 100, 200 or All. Search, sort, date-filter, select items and confirm the requested action.

The dashboard provides pause/stop, progress, creator statistics, CSV/JSON export, and a log tab. Pause/stop take effect after the current request finishes. Keep the dashboard open while running. Closing it stops further work; an in-flight request may still complete and must be checked on TikTok before retrying.

Account libraries and history are saved locally in extension storage, separated by account and feature. Logs are limited to 300 events in session storage. No passwords, cookies or CSRF tokens are exported or sent to a backend. Updating or uninstalling an unpacked extension may affect its stored data; export data first.

TikTok's internal endpoints are unsupported and can change or return verification/rate-limit responses. The extension stops when an action is rejected or ambiguous. It does not bypass challenges or automatically replay uncertain writes. It needs desktop Chrome/Edge; this is not an iPhone extension. A successful web test does not prove the iOS WebView is fixed.

## Build / test

From repository root: `node scripts/build_web_extension.cjs`, then `node --test test/web_extension_test.cjs`.
Output: `build/cleartok-web/`. No npm dependencies or server required. Opening index.html outside the extension previews UI only, without TikTok access.
