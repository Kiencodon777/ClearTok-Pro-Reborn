import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../api/tiktok_client.dart';
import '../../core/remote_payload_config.dart';

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
  String _currentUrl = '';

  // EXACT desktop macOS User-Agent recovered from ClearTok's webview_transport.dart
  static const String desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final String _initialUrl = 'https://www.tiktok.com/login/phone-or-email/email/?lang=en&tt_not_installed=true';

  @override
  Widget build(BuildContext context) {
    final isLogged = widget.currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161926),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFE2C55).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.desktop_mac, color: Color(0xFF25F4EE), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TikTok Desktop Web',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    isLogged ? '@${widget.currentUser!.uniqueId} (Mục Repost Đã Sẵn Sàng)' : 'Cần đăng nhập tài khoản',
                    style: TextStyle(
                      fontSize: 11,
                      color: isLogged ? const Color(0xFF25F4EE) : Colors.white54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isLogged)
            IconButton(
              icon: const Icon(Icons.person, color: Color(0xFF25F4EE)),
              tooltip: 'Mở trang cá nhân Desktop (Xem mục Repost)',
              onPressed: () {
                final profileUrl = 'https://www.tiktok.com/@${widget.currentUser!.uniqueId}';
                _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(profileUrl)));
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Tải lại trang',
            onPressed: () => _webViewController?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.lock_reset, color: Colors.white70),
            tooltip: 'Về trang đăng nhập',
            onPressed: () {
              _webViewController?.loadUrl(
                urlRequest: URLRequest(url: WebUri(_initialUrl)),
              );
            },
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _loadProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFE2C55)),
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
              return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
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
                _currentUrl = url?.toString() ?? '';
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
                _currentUrl = url?.toString() ?? '';
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
                  controller.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
                }
                return NavigationActionPolicy.CANCEL;
              }

              if (uri.scheme == 'http' || uri.scheme == 'https') {
                return NavigationActionPolicy.ALLOW;
              }

              return NavigationActionPolicy.CANCEL;
            },
          ),

          // Bottom Floating VIP Banner when logged in
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: AnimatedSlide(
              offset: isLogged ? Offset.zero : const Offset(0, 1.5),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2235), Color(0xFF121420)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF25F4EE).withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF25F4EE).withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: widget.currentUser?.avatarThumb.isNotEmpty == true
                          ? NetworkImage(widget.currentUser!.avatarThumb)
                          : null,
                      child: widget.currentUser?.avatarThumb.isEmpty != false
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF25F4EE), size: 14),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.currentUser?.nickname ?? 'Connected',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '@${widget.currentUser?.uniqueId}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFE2C55),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: widget.onNavigateToStudio,
                      child: const Row(
                        children: [
                          Text('Studio', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
}
