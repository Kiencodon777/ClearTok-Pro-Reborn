# Phase 1 TLS fixture

Run `python test/tls_fixture.py --openssl <path-to-openssl>` on the host. The
process prints the temporary CA path and logs accepted HTTP requests by port and
path. Stop with Ctrl+C. Certificates and private keys are ephemeral test data.

| Port | Certificate | Expected with fixture CA trusted |
| --- | --- | --- |
| 18443 | Fixture CA, localhost / 127.0.0.1 / 10.0.2.2 | Load |
| 18444 | Fixture CA, expired | Reject before HTTP request |
| 18445 | Fixture CA, wrong hostname | Reject before HTTP request |
| 18446 | Self-signed leaf | Reject before HTTP request |
| 18447 | Leaf from another CA | Reject before HTTP request |

The valid server exposes `/endpoint`, `/redirect-http` (to port 18080) and
`/redirect-external` (to `example.invalid`). Check the log for absence of
requests on ports 18444–18447. Host tests do not establish WebView behavior.

Android emulator reaches the host at `https://10.0.2.2:18443/endpoint`; install
the printed CA on an isolated test emulator and configure a **test-only** app
network security config to trust user certificates. Modern Android apps do not
trust user CAs by default. Do not ship this configuration. A physical device
needs host reachability and a certificate SAN matching its host address.

On macOS, run this fixture on the Mac and use
`https://127.0.0.1:18443/endpoint` in the iOS Simulator. Install its CA only in
the isolated simulator, for example `xcrun simctl keychain booted add-root-cert
<printed-ca-path>`. Build a separate iOS simulator test target from the Flutter
checkout using `flutter create --org com.cleartok --project-name
cleartok_reborn --platforms=ios .` in a disposable copy, then `flutter build ios
--simulator --debug --no-codesign`. Run a test-only WebView harness against the
fixture, record navigation and server logs, and reset that simulator afterwards.

The production origin policy deliberately blocks these fixture origins. A
separate debug-only WebView harness is still needed; do not add the fixture CA
or its origin to production. The fixture alone does not test popup, native
redirect handling, app resume, or TikTok login. Never enter real credentials.
