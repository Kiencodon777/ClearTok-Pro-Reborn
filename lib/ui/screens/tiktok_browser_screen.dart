import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../api/tiktok_client.dart';
import '../../core/remote_payload_config.dart';
import '../../services/diagnostic_log.dart';
import '../widgets/liquid_glass.dart';

class TikTokBrowserScreen extends StatefulWidget {
  final RemotePayloadConfig remoteConfig;
  final Function(InAppWebViewController, TikTokClient) onClientReady;
  final Function(TikTokUserProfile?) onUserStatusChanged;
  final VoidCallback onNavigateToStudio;
  final TikTokUserProfile? currentUser;

  const TikTokBrowserScreen({
    super.key,
    required this.remoteConfig,
    required this.onClientReady,
    required this.onUserStatusChanged,
    required this.onNavigateToStudio,
    this.currentUser,
  });

  @override
  State<TikTokBrowserScreen> createState() => _TikTokBrowserScreenState();
}

class _TikTokBrowserScreenState extends State<TikTokBrowserScreen> {
  InAppWebViewController? _webViewController;
  TikTokClient? _client;
  double _loadProgress = 0.0;
  bool _isLoading = true;
  bool _desktopMode = false;
  bool _switchingMode = false;
  bool _cleanedInitialRiskTokens = false;

  static const String desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const String mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1';

  // Injected BEFORE TikTok's webmssdk.js loads so Passport never flags the WebView
  static const String _stealthFingerprintJs = r'''
(function() {
  try {
    Object.defineProperty(navigator, 'webdriver', {
      get: function() { return false; },
      configurable: true
    });
    var ua = navigator.userAgent || '';
    if (ua.indexOf('Macintosh') !== -1) {
      Object.defineProperty(navigator, 'platform', {
        get: function() { return 'MacIntel'; },
        configurable: true
      });
      Object.defineProperty(navigator, 'vendor', {
        get: function() { return 'Google Inc.'; },
        configurable: true
      });
      Object.defineProperty(navigator, 'maxTouchPoints', {
        get: function() { return 0; },
        configurable: true
      });
    } else if (ua.indexOf('iPhone') !== -1) {
      Object.defineProperty(navigator, 'platform', {
        get: function() { return 'iPhone'; },
        configurable: true
      });
      Object.defineProperty(navigator, 'vendor', {
        get: function() { return 'Apple Computer, Inc.'; },
        configurable: true
      });
      Object.defineProperty(navigator, 'maxTouchPoints', {
        get: function() { return 5; },
        configurable: true
      });
    }
  } catch (_) {}
})();
''';

  static const String _loginInputStabilizerJs = r'''
(function() {
  try {
    // Clear cached risk/rate-limit flags in web storage when on /login
    if (location.pathname.indexOf('/login') !== -1) {
      try {
        var keysToRemove = [];
        for (var i = 0; i < localStorage.length; i++) {
          var k = localStorage.key(i) || '';
          if (k.indexOf('passport') !== -1 || k.indexOf('mssdk') !== -1 ||
              k.indexOf('verify') !== -1 || k.indexOf('risk') !== -1 ||
              k.indexOf('slardar') !== -1 || k.indexOf('tea_cache') !== -1) {
            keysToRemove.push(k);
          }
        }
        keysToRemove.forEach(function(k) { localStorage.removeItem(k); });
        sessionStorage.clear();
      } catch (_) {}
    }
  } catch (_) {}

  if (window.__lapinInputStabilizerInstalled) return;
  window.__lapinInputStabilizerInstalled = true;
  function stabilizeViewport() {
    var isLogin = location.pathname.indexOf('/login') !== -1;
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      if (document.head) document.head.appendChild(meta);
    }
    if (meta && isLogin) {
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    }
    if (isLogin && !document.getElementById('__lapin_login_css')) {
      var style = document.createElement('style');
      style.id = '__lapin_login_css';
      style.textContent =
        'html, body { width: 100% !important; max-width: 100vw !important; min-width: 0 !important; overflow-x: hidden !important; background: #12141d !important; } ' +
        '#app, [id*="login"], [class*="loginContainer"], [class*="LoginContainer"], [class*="modal"] { max-width: 100vw !important; min-width: 0 !important; box-sizing: border-box !important; } ' +
        'input, textarea { font-size: 16px !important; }';
      if (document.head) document.head.appendChild(style);
    }
  }
  stabilizeViewport();
  document.addEventListener('DOMContentLoaded', stabilizeViewport);
  function keepInputVisible(e) {
    var el = e && e.target;
    if (!el || (el.tagName !== 'INPUT' && el.tagName !== 'TEXTAREA')) return;
    stabilizeViewport();
    setTimeout(function() {
      try {
        window.scrollTo(0, Math.max(0, window.scrollY));
        el.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
      } catch (_) {}
    }, 120);
    setTimeout(function() {
      try {
        el.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
      } catch (_) {}
    }, 320);
  }
  document.addEventListener('focusin', keepInputVisible, true);
  document.addEventListener('input', keepInputVisible, true);
})();
''';

  final String _initialUrl = 'https://www.tiktok.com/login';

  @override
  Widget build(BuildContext context) {
    final isLogged = widget.currentUser != null;

    return Scaffold(
      backgroundColor: ClearTokColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: ClearTokColors.surface,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            color: ClearTokColors.surface,
            border: Border(
              bottom: BorderSide(color: ClearTokColors.border, width: .6),
            ),
          ),
          child: SizedBox.expand(),
        ),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ClearTokColors.pink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _desktopMode ? Icons.desktop_mac : Icons.phone_iphone_rounded,
                color: ClearTokColors.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _desktopMode ? 'TikTok Desktop' : 'TikTok Mobile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    isLogged
                        ? '@${widget.currentUser!.uniqueId} (Mục Repost Đã Sẵn Sàng)'
                        : 'Bấm 🧹 nếu bị báo lỗi quá số lần thử',
                    style: TextStyle(
                      fontSize: 11,
                      color: isLogged
                          ? ClearTokColors.cyan
                          : ClearTokColors.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isLogged)
            IconButton(
              tooltip: 'Fix lỗi đăng nhập (Xóa phiên bị chặn)',
              icon: const Icon(
                Icons.cleaning_services_rounded,
                color: ClearTokColors.warning,
              ),
              onPressed: _switchingMode ? null : _resetFlaggedLoginSession,
            ),
          IconButton(
            tooltip: _desktopMode
                ? 'Chuyển sang điện thoại'
                : 'Chuyển sang máy tính (Quét QR)',
            icon: Icon(_desktopMode ? Icons.phone_android : Icons.desktop_mac),
            onPressed: _switchingMode ? null : _toggleBrowserMode,
          ),
          if (isLogged)
            IconButton(
              tooltip: 'Mở Studio',
              icon: const Icon(Icons.dashboard),
              onPressed: widget.onNavigateToStudio,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: ClearTokColors.secondary),
            tooltip: 'Tải lại trang',
            onPressed: () => _webViewController?.reload(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu trình duyệt',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) async {
              if (value == 'profile') {
                _webViewController?.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri(
                      'https://www.tiktok.com/@${widget.currentUser!.uniqueId}',
                    ),
                  ),
                );
                return;
              }
              if (value == 'reset_session') {
                await _resetFlaggedLoginSession();
                return;
              }
              if (value == 'qr_login') {
                if (!_desktopMode) {
                  await _toggleBrowserMode(targetUrl: 'https://www.tiktok.com/login/qrcode');
                } else {
                  _webViewController?.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri('https://www.tiktok.com/login/qrcode'),
                    ),
                  );
                }
                return;
              }
              _webViewController?.loadUrl(
                urlRequest: URLRequest(url: WebUri(_initialUrl)),
              );
            },
            itemBuilder: (_) => [
              if (isLogged)
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('Mở trang cá nhân'),
                  ),
                ),
              const PopupMenuItem(
                value: 'reset_session',
                child: ListTile(
                  leading: Icon(
                    Icons.cleaning_services_rounded,
                    color: ClearTokColors.warning,
                  ),
                  title: Text('Fix lỗi "Maximum attempts"'),
                  subtitle: Text('Xóa cookie chặn & làm mới phiên'),
                ),
              ),
              const PopupMenuItem(
                value: 'qr_login',
                child: ListTile(
                  leading: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: ClearTokColors.cyan,
                  ),
                  title: Text('Đăng nhập bằng mã QR'),
                ),
              ),
              const PopupMenuItem(
                value: 'login',
                child: ListTile(
                  leading: Icon(Icons.lock_reset),
                  title: Text('Về trang đăng nhập'),
                ),
              ),
            ],
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _loadProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ClearTokColors.pink,
                  ),
                ),
              )
            : null,
      ),
      body: ColoredBox(
        color: ClearTokColors.background,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
          initialUserScripts: UnmodifiableListView<UserScript>([
            UserScript(
              source: _stealthFingerprintJs,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
            UserScript(
              source: _loginInputStabilizerJs,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
            ),
          ]),
          initialSettings: InAppWebViewSettings(
            userAgent: mobileUserAgent,
            preferredContentMode: UserPreferredContentMode.MOBILE,
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            thirdPartyCookiesEnabled: true,
            allowFileAccess: true,
            allowContentAccess: true,
            useWideViewPort: false,
            loadWithOverviewMode: false,
            supportZoom: false,
            transparentBackground: false,
            useHybridComposition: true,
            supportMultipleWindows: true,
            javaScriptCanOpenWindowsAutomatically: true,
            cacheEnabled: true,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            safeBrowsingEnabled: false,
            hardwareAcceleration: true,
            allowsInlineMediaPlayback: true,
            mediaPlaybackRequiresUserGesture: false,
          ),
          onCreateWindow: (controller, createWindowAction) async {
            final targetUrl = createWindowAction.request.url;
            if (targetUrl != null) {
              controller.loadUrl(urlRequest: URLRequest(url: targetUrl));
            }
            return false;
          },
          onReceivedServerTrustAuthRequest: (controller, challenge) async {
            return ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.PROCEED,
            );
          },
          onWebViewCreated: (controller) async {
            _webViewController = controller;
            _client = TikTokClient(
              webViewController: controller,
              remoteConfig: widget.remoteConfig,
            );
            widget.onClientReady(controller, _client!);
            if (widget.currentUser == null && !_cleanedInitialRiskTokens) {
              _cleanedInitialRiskTokens = true;
              await _clearRiskCookiesOnly();
            }
          },
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
            });
            _syncViewportForUrl(controller, url);
          },
          onProgressChanged: (controller, progress) {
            setState(() {
              _loadProgress = progress / 100.0;
              if (progress >= 100) _isLoading = false;
            });
          },
          onUpdateVisitedHistory: (controller, url, isReload) {
            _syncViewportForUrl(controller, url);
          },
          onLoadStop: (controller, url) async {
            setState(() {
              _isLoading = false;
            });
            await _syncViewportForUrl(controller, url);
            await _evaluateUserSession();
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;

            // Prevent Net::ERR_UNKNOWN_URL_SCHEME on Android
            if (uri.scheme == 'tiktok' || uri.scheme.startsWith('snssdk')) {
              final targetUrl = uri.queryParameters['url'];
              if (targetUrl != null && targetUrl.isNotEmpty) {
                controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(targetUrl)),
                );
              }
              return NavigationActionPolicy.CANCEL;
            }

            if (uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationActionPolicy.ALLOW;
            }

            return NavigationActionPolicy.CANCEL;
          },
        ),
      ),
    );
  }

  /// Clears only TikTok's anti-bot rate-limit cookies (`s_v_web_id`, `msToken`,
  /// `passport_csrf_token`, `tt_csrf_token`) while keeping valid session cookies
  /// (`sessionid`, `sid_tt`) intact.
  Future<void> _clearRiskCookiesOnly() async {
    try {
      final cm = CookieManager.instance();
      final domainUrl = WebUri('https://www.tiktok.com');
      final cookies = await cm.getCookies(url: domainUrl);
      final hasSession = cookies.any(
        (c) =>
            (c.name == 'sessionid' ||
                c.name == 'sessionid_ss' ||
                c.name == 'sid_tt') &&
            (c.value?.toString().isNotEmpty ?? false),
      );
      if (hasSession) return;
      for (final name in [
        's_v_web_id',
        'msToken',
        'ttwid',
        'odin_tt',
        'passport_csrf_token',
        'passport_csrf_token_default',
        'tt_chain_token',
      ]) {
        await cm.deleteCookie(url: domainUrl, name: name, domain: '.tiktok.com');
        await cm.deleteCookie(
          url: domainUrl,
          name: name,
          domain: 'www.tiktok.com',
        );
      }
    } catch (_) {}
  }

  /// Full reset when TikTok blocks login with "Maximum number of attempts reached"
  Future<void> _resetFlaggedLoginSession() async {
    final controller = _webViewController;
    if (controller == null) return;
    setState(() => _switchingMode = true);
    try {
      await CookieManager.instance().deleteAllCookies();
      await InAppWebViewController.clearAllCache();
      await controller.evaluateJavascript(
        source:
            'try { localStorage.clear(); sessionStorage.clear(); } catch (_) {}',
      );
      await controller.setSettings(
        settings: InAppWebViewSettings(
          userAgent: mobileUserAgent,
          preferredContentMode: UserPreferredContentMode.MOBILE,
          useWideViewPort: false,
          loadWithOverviewMode: false,
          supportZoom: false,
        ),
      );
      if (!mounted) return;
      setState(() => _desktopMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã xóa cookie chặn & tạo phiên Mobile sạch! Anh đăng nhập lại hoặc dùng Google/SĐT/QR nhé.',
          ),
        ),
      );
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri('https://www.tiktok.com/login'),
          headers: const {'Cache-Control': 'no-cache, no-store, must-revalidate'},
        ),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }

  Future<void> _syncViewportForUrl(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final urlStr = url?.toString() ?? '';
    final isLogin = urlStr.contains('/login') && !urlStr.contains('/qrcode');
    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(
          useWideViewPort: _desktopMode && !isLogin,
          loadWithOverviewMode: _desktopMode && !isLogin,
          supportZoom: !isLogin,
        ),
      );
      await controller.evaluateJavascript(source: _stealthFingerprintJs);
      await controller.evaluateJavascript(source: _loginInputStabilizerJs);
    } catch (_) {}
  }

  Future<void> _evaluateUserSession() async {
    if (_client == null) return;
    final profile = await _client!.extractLiveUserProfile();
    if (profile != null && profile.secUid.isNotEmpty) {
      widget.onUserStatusChanged(profile);
      // Once authenticated, smoothly enable Desktop mode for full Studio API access
      if (!_desktopMode && _webViewController != null) {
        try {
          await _webViewController!.setSettings(
            settings: InAppWebViewSettings(
              userAgent: desktopUserAgent,
              preferredContentMode: UserPreferredContentMode.DESKTOP,
              useWideViewPort: true,
              loadWithOverviewMode: true,
            ),
          );
          if (mounted) setState(() => _desktopMode = true);
        } catch (_) {}
      }
    }
  }

  Future<void> _toggleBrowserMode({String? targetUrl}) async {
    final controller = _webViewController;
    if (controller == null) return;
    setState(() => _switchingMode = true);
    final nextDesktop = !_desktopMode;
    try {
      final currentUrl =
          targetUrl ?? ((await controller.getUrl())?.toString() ?? '');
      final isLogin =
          currentUrl.contains('/login') && !currentUrl.contains('/qrcode');
      final agent = nextDesktop ? desktopUserAgent : mobileUserAgent;
      await controller.setSettings(
        settings: InAppWebViewSettings(
          userAgent: agent,
          preferredContentMode: nextDesktop
              ? UserPreferredContentMode.DESKTOP
              : UserPreferredContentMode.MOBILE,
          useWideViewPort: nextDesktop && !isLogin,
          loadWithOverviewMode: nextDesktop && !isLogin,
        ),
      );
      if (!mounted) return;
      setState(() => _desktopMode = nextDesktop);
      DiagnosticLog.instance.record(
        'browser.mode',
        0,
        details: {'browser_mode': nextDesktop ? 'desktop' : 'mobile'},
      );
      if (targetUrl != null) {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri(targetUrl)),
        );
      } else {
        await controller.reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không đổi được chế độ trình duyệt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }
}
