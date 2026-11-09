import 'package:flutter/material.dart';
import '../widgets/studio_chrome_slide.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../api/tiktok_client.dart';
import '../../core/remote_payload_config.dart';
import '../../database/local_database.dart';
import 'repost_studio_screen.dart';
import 'tiktok_browser_screen.dart';
import 'processed_history_screen.dart';
import 'diagnostic_log_screen.dart';
import '../../services/app_updates.dart';
import '../widgets/project_credits.dart';
import '../widgets/liquid_glass.dart';

class MainNavigationScreen extends StatefulWidget {
  final LocalDatabase database;
  final RemotePayloadConfig remoteConfig;

  const MainNavigationScreen({
    super.key,
    required this.database,
    required this.remoteConfig,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppUpdates.check(context, widget.database);
    });
  }

  int _currentIndex = 0;
  bool _studioChromeVisible = true;
  InAppWebViewController? _webViewController;
  TikTokClient? _client;
  TikTokUserProfile? _currentUser;

  void _openUrlInTikTokWeb(String url) {
    setState(() {
      _currentIndex = 0;
    });
    final controller = _webViewController;
    if (controller != null && url.isNotEmpty) {
      try {
        controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final repostCount = widget.database.repostCount;
    final processedCount = widget.database.totalDeletedCount;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 80;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      extendBody: _currentIndex == 1 || _currentIndex == 2,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: _currentIndex == 1 || _currentIndex == 2,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0: Fullscreen TikTok Web Browser
            TikTokBrowserScreen(
              remoteConfig: widget.remoteConfig,
              currentUser: _currentUser,
              onClientReady: (controller, client) {
                setState(() {
                  _webViewController = controller;
                  _client = client;
                });
              },
              onUserStatusChanged: (user) {
                setState(() {
                  _currentUser = user;
                });
              },
              onNavigateToStudio: () {
                setState(() => _currentIndex = 1);
              },
            ),

            // Tab 1: LapinTokk Studio / Reposts, Un-Like, Un-Follow Manager
            RepostStudioScreen(
              active: _currentIndex == 1,
              onChromeVisibilityChanged: (visible) {
                if (mounted) setState(() => _studioChromeVisible = visible);
              },
              database: widget.database,
              client: _client,
              currentUser: _currentUser,
              onSwitchToBrowser: () {
                setState(() => _currentIndex = 0);
              },
              onOpenInTikTokWeb: _openUrlInTikTokWeb,
            ),

            // Tab 2: Processed History (Reposts, Un-Liked, Un-Followed)
            ProcessedHistoryScreen(
              database: widget.database,
              onOpenInTikTokWeb: _openUrlInTikTokWeb,
            ),

            // Tab 3: Diagnostic Log
            const DiagnosticLogScreen(),
          ],
        ),
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : StudioChromeSlide(
              visible: _currentIndex != 1 || _studioChromeVisible,
              bottom: true,
              child: SafeArea(
                key: const ValueKey('creator-dock'),
                top: false,
                minimum: const EdgeInsets.only(bottom: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GBoxLiquidDock(
                      selectedIndex: _currentIndex,
                      onTabSelected: (idx) => setState(() {
                        _currentIndex = idx;
                        _studioChromeVisible = true;
                      }),
                      items: [
                        const GBoxDockItem(
                          icon: Icon(Icons.public_rounded),
                          activeIcon: Icon(Icons.public_rounded),
                          label: 'TikTok Web',
                        ),
                        GBoxDockItem(
                          icon: Badge(
                            isLabelVisible: repostCount > 0,
                            label: Text('$repostCount'),
                            backgroundColor: ClearTokColors.neonCyan,
                            textColor: Colors.black,
                            child: const Icon(Icons.grid_view_rounded),
                          ),
                          activeIcon: Badge(
                            isLabelVisible: repostCount > 0,
                            label: Text('$repostCount'),
                            backgroundColor: ClearTokColors.neonCyan,
                            textColor: Colors.black,
                            child: const Icon(Icons.grid_view_rounded),
                          ),
                          label: 'Studio Reposts',
                        ),
                        GBoxDockItem(
                          icon: Badge(
                            isLabelVisible: processedCount > 0,
                            label: Text('$processedCount'),
                            backgroundColor: ClearTokColors.pink,
                            textColor: Colors.white,
                            child: const Icon(Icons.history_edu_rounded),
                          ),
                          activeIcon: Badge(
                            isLabelVisible: processedCount > 0,
                            label: Text('$processedCount'),
                            backgroundColor: ClearTokColors.pink,
                            textColor: Colors.white,
                            child: const Icon(Icons.history_edu_rounded),
                          ),
                          label: 'Đã Xử Lý',
                        ),
                        const GBoxDockItem(
                          icon: Icon(Icons.receipt_long_rounded),
                          activeIcon: Icon(Icons.receipt_long_rounded),
                          label: 'Log',
                        ),
                      ],
                    ),
                    if (_currentIndex == 1) const ProjectCreditFooter(),
                  ],
                ),
              ),
            ),
    );
  }
}
