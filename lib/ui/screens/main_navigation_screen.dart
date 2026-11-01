import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../api/tiktok_client.dart';
import '../../core/remote_payload_config.dart';
import '../../database/local_database.dart';
import 'repost_studio_screen.dart';
import 'tiktok_browser_screen.dart';
import 'diagnostic_log_screen.dart';
import '../../services/app_updates.dart';

class MainNavigationScreen extends StatefulWidget {
  final LocalDatabase database;
  final RemotePayloadConfig remoteConfig;

  const MainNavigationScreen({super.key, required this.database, required this.remoteConfig});

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
  InAppWebViewController? _webViewController;
  TikTokClient? _client;
  TikTokUserProfile? _currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: IndexedStack(
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

          // Tab 1: ClearTok Studio / Reposts Manager
          RepostStudioScreen(
            database: widget.database,
            client: _client,
            currentUser: _currentUser,
            onSwitchToBrowser: () {
              setState(() => _currentIndex = 0);
            },
          ),
          const DiagnosticLogScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161926),
          border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: const Color(0xFFFE2C55).withOpacity(0.2),
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
          },
          destinations: [
            // Keep tab order in sync with IndexedStack.
            NavigationDestination(
              icon: const Icon(Icons.public_outlined, color: Colors.white54),
              selectedIcon: const Icon(Icons.public, color: Color(0xFFFE2C55)),
              label: 'TikTok Web',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: widget.database.getAllReposts().isNotEmpty,
                label: Text('${widget.database.getAllReposts().length}'),
                backgroundColor: const Color(0xFF25F4EE),
                textColor: Colors.black,
                child: const Icon(Icons.dashboard_outlined, color: Colors.white54),
              ),
              selectedIcon: Badge(
                isLabelVisible: widget.database.getAllReposts().isNotEmpty,
                label: Text('${widget.database.getAllReposts().length}'),
                backgroundColor: const Color(0xFF25F4EE),
                textColor: Colors.black,
                child: const Icon(Icons.dashboard_rounded, color: Color(0xFF25F4EE)),
              ),
              label: 'Studio Reposts',
            ),
            const NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Log'),
          ],
        ),
      ),
    );
  }
}
