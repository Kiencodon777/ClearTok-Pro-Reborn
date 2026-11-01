# Diagnostic web companion

Build with `node scripts/build_diagnostic_web.cjs`. Open `build/diagnostic-web/index.html`.
The versioned web ZIP is also attached to each GitHub Release; extract it and open index.html.

Paste mobile logs to classify empty responses, HTTP failures, and readback outcomes. Click the transport test button to exercise the exact JavaScript extracted from mobile with mocked responses. No TikTok requests or uploads occur in this tool.

This companion cannot inspect a running iPhone or operate TikTok from another origin. Mobile logs must be copied explicitly. Device verification still requires the native app. A passing simulation does not establish live API correctness.
