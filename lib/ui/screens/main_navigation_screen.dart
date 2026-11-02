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

  const MainNavigationScreen(
      {super.key, required this.database, required this.remoteConfig});

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
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
      bottomNavigationBar: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LiquidGlassContainer(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                borderRadius: 28,
                child: MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: NavigationBar(
                      height: 68,
                      animationDuration:
                          MediaQuery.of(context).disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                      selectedIndex: _currentIndex,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      indicatorColor: ClearTokColors.pink.withOpacity(0.2),
                      onDestinationSelected: (idx) {
                        setState(() => _currentIndex = idx);
                      },
                      destinations: [
                        // Keep tab order in sync with IndexedStack.
                        const NavigationDestination(
                          icon: Icon(Icons.public_outlined,
                              color: ClearTokColors.muted),
                          selectedIcon:
                              Icon(Icons.public, color: ClearTokColors.pink),
                          label: 'TikTok Web',
                        ),
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible:
                                widget.database.getAllReposts().isNotEmpty,
                            label: Text(
                                '${widget.database.getAllReposts().length}'),
                            backgroundColor: ClearTokColors.cyan,
                            textColor: Colors.black,
                            child: const Icon(Icons.dashboard_outlined,
                                color: ClearTokColors.muted),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible:
                                widget.database.getAllReposts().isNotEmpty,
                            label: Text(
                                '${widget.database.getAllReposts().length}'),
                            backgroundColor: ClearTokColors.cyan,
                            textColor: Colors.black,
                            child: const Icon(Icons.dashboard_rounded,
                                color: ClearTokColors.cyan),
                          ),
                          label: 'Studio Reposts',
                        ),
                        const NavigationDestination(
                            icon: Icon(Icons.receipt_long), label: 'Log'),
                      ],
                    ))),
            if (_currentIndex == 1) const ProjectCreditFooter(),
          ])),
    );
  }
}
