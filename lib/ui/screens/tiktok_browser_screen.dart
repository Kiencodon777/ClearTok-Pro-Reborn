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
  bool _desktopMode = true;
  bool _switchingMode = false;
  bool _redirectedFromLogin = false;

  // EXACT desktop macOS User-Agent recovered from ClearTok's webview_transport.dart
  static const String desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const String _loginInputStabilizerJs = r'''
(function() {
  if (window.__lapinInputStabilizerInstalled) return;
  window.__lapinInputStabilizerInstalled = true;
  function stabilizeViewport() {
    var isLogin = location.pathname.indexOf('/login') !== -1 &&
                  location.pathname.indexOf('/qrcode') === -1;
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

  final String _initialUrl =
      'https://www.tiktok.com/login/phone-or-email/email/?lang=en&tt_not_installed=true';

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
              child: const Icon(
                Icons.desktop_mac,
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
                        : 'Cần đăng nhập tài khoản',
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
                : 'Chuyển sang máy tính',
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
                _webViewController?.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri('https://www.tiktok.com/login/qrcode'),
                  ),
                );
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
          initialSettings: InAppWebViewSettings(
            userAgent: desktopUserAgent,
            preferredContentMode: UserPreferredContentMode.DESKTOP,
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
            supportMultipleWindows: false,
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
          onWebViewCreated: (controller) {
            _webViewController = controller;
            _client = TikTokClient(
              webViewController: controller,
              remoteConfig: widget.remoteConfig,
            );
            widget.onClientReady(controller, _client!);
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
            await _evaluateUserSession(currentUrl: url);
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
      _redirectedFromLogin = false;
      widget.onUserStatusChanged(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã xóa cookie bị chặn! Anh có thể đăng nhập lại hoặc chọn Đăng nhập bằng mã QR nhé.',
          ),
        ),
      );
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(_initialUrl),
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
          },
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
    final isLogin =
        urlStr.contains('/login') && !urlStr.contains('/qrcode');
    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(
          useWideViewPort: _desktopMode && !isLogin,
          loadWithOverviewMode: _desktopMode && !isLogin,
          supportZoom: !isLogin,
        ),
      );
      await controller.evaluateJavascript(source: _loginInputStabilizerJs);
      await controller.evaluateJavascript(
        source: TikTokClient.mainWorldBridgeJs,
      );
    } catch (_) {}
  }

  Future<void> _evaluateUserSession({WebUri? currentUrl}) async {
    if (_client == null) return;
    final profile = await _client!.extractLiveUserProfile();
    if (profile != null && profile.secUid.isNotEmpty) {
      widget.onUserStatusChanged(profile);
      final urlStr =
          currentUrl?.toString() ??
          ((await _webViewController?.getUrl())?.toString() ?? '');
      if (urlStr.contains('/login') &&
          !_redirectedFromLogin &&
          _webViewController != null) {
        _redirectedFromLogin = true;
        await _webViewController!.loadUrl(
          urlRequest: URLRequest(
            url: WebUri('https://www.tiktok.com/@${profile.uniqueId}'),
          ),
        );
      }
    }
  }

  Future<void> _toggleBrowserMode() async {
    final controller = _webViewController;
    if (controller == null) return;
    setState(() => _switchingMode = true);
    final nextDesktop = !_desktopMode;
    try {
      final currentUrl = (await controller.getUrl())?.toString() ?? '';
      final isLogin =
          currentUrl.contains('/login') && !currentUrl.contains('/qrcode');
      final agent = nextDesktop
          ? desktopUserAgent
          : await InAppWebViewController.getDefaultUserAgent();
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
      await controller.reload();
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
