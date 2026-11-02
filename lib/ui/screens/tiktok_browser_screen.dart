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

  // EXACT desktop macOS User-Agent recovered from ClearTok's webview_transport.dart
  static const String desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final String _initialUrl =
      'https://www.tiktok.com/login/phone-or-email/email/?lang=en&tt_not_installed=true';

  @override
  Widget build(BuildContext context) {
    final isLogged = widget.currentUser != null;

    return Scaffold(
      backgroundColor: ClearTokColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const LiquidGlassContainer(
          borderRadius: 0,
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
            onSelected: (value) {
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
      body: Stack(
        children: [
          InAppWebView(
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
              useWideViewPort: true,
              loadWithOverviewMode: true,
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
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _loadProgress = progress / 100.0;
                if (progress >= 100) _isLoading = false;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
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
        ],
      ),
    );
  }

  Future<void> _evaluateUserSession() async {
    if (_client == null) return;
    final profile = await _client!.extractLiveUserProfile();
    if (profile != null && profile.secUid.isNotEmpty) {
      widget.onUserStatusChanged(profile);
    }
  }

  Future<void> _toggleBrowserMode() async {
    final controller = _webViewController;
    if (controller == null) return;
    setState(() => _switchingMode = true);
    final nextDesktop = !_desktopMode;
    try {
      final agent = nextDesktop
          ? desktopUserAgent
          : await InAppWebViewController.getDefaultUserAgent();
      await controller.setSettings(
        settings: InAppWebViewSettings(
          userAgent: agent,
          preferredContentMode: nextDesktop
              ? UserPreferredContentMode.DESKTOP
              : UserPreferredContentMode.MOBILE,
          useWideViewPort: nextDesktop,
          loadWithOverviewMode: nextDesktop,
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
