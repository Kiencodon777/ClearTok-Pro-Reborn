import 'package:flutter/material.dart';
import '../../api/tiktok_client.dart';
import '../../core/remote_payload_config.dart';
import '../../database/local_database.dart';
import 'repost_studio_screen.dart';
import 'tiktok_browser_screen.dart';
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
  TikTokClient? _client;
  TikTokUserProfile? _currentUser;

  @override
  Widget build(BuildContext context) {
    final repostCount = widget.database.getAllReposts().length;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 80;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      extendBody: _currentIndex == 1,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: _currentIndex == 1,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0: Fullscreen TikTok Web Browser
            TikTokBrowserScreen(
              remoteConfig: widget.remoteConfig,
              currentUser: _currentUser,
              onClientReady: (controller, client) {
                setState(() {
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

            // Tab 1: LapinTokk Studio / Reposts Manager
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
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : LiquidGlassContainer(
              key: const ValueKey('creator-dock'),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              borderRadius: 28,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GBoxLiquidDock(
                      selectedIndex: _currentIndex,
                      onTabSelected: (idx) =>
                          setState(() => _currentIndex = idx),
                      items: [
                        const GBoxDockItem(
                          icon: Icon(Icons.public_outlined),
                          activeIcon: Icon(Icons.public),
                          label: 'TikTok Web',
                        ),
                        GBoxDockItem(
                          icon: Badge(
                            isLabelVisible: repostCount > 0,
                            label: Text('$repostCount'),
                            backgroundColor: ClearTokColors.cyan,
                            textColor: Colors.black,
                            child: const Icon(Icons.dashboard_outlined),
                          ),
                          activeIcon: Badge(
                            isLabelVisible: repostCount > 0,
                            label: Text('$repostCount'),
                            backgroundColor: ClearTokColors.cyan,
                            textColor: Colors.black,
                            child: const Icon(Icons.dashboard_rounded),
                          ),
                          label: 'Studio Reposts',
                        ),
                        const GBoxDockItem(
                          icon: Icon(Icons.receipt_long_outlined),
                          activeIcon: Icon(Icons.receipt_long),
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
