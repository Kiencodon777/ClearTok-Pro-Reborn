import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
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
    return Scaffold(
      backgroundColor: Colors.transparent,
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
      ),
      bottomNavigationBar: LiquidGlassContainer(
        key: const ValueKey('creator-dock'),
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        borderRadius: 28,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              glass.GlassTabBar.bottom(
                selectedIndex: _currentIndex,
                onTabSelected: (idx) => setState(() => _currentIndex = idx),
                horizontalPadding: 4,
                verticalPadding: 0,
                barHeight: 64,
                barBorderRadius: 24,
                glowOpacity: .08,
                glowBlurRadius: 8,
                quality: glass.GlassQuality.premium,
                backgroundQuality: glass.GlassQuality.minimal,
                settings: glass.LiquidGlassSettings.ios27Dark.copyWith(
                  glassColor: Colors.transparent,
                  blur: 0,
                  thickness: 0,
                ),
                indicatorSettings: glass.LiquidGlassSettings.ios27Dark,
                indicatorColor: ClearTokColors.pink.withValues(alpha: .20),
                selectedIconColor: ClearTokColors.cyan,
                selectedLabelColor: Colors.white,
                unselectedIconColor: ClearTokColors.secondary,
                unselectedLabelColor: ClearTokColors.secondary,
                tabs: [
                  const glass.GlassTab(
                    icon: Icon(Icons.public_outlined),
                    activeIcon: Icon(Icons.public),
                    label: 'TikTok Web',
                  ),
                  glass.GlassTab(
                    icon: Badge(
                      isLabelVisible: widget.database
                          .getAllReposts()
                          .isNotEmpty,
                      label: Text('${widget.database.getAllReposts().length}'),
                      backgroundColor: ClearTokColors.cyan,
                      textColor: Colors.black,
                      child: const Icon(Icons.dashboard_outlined),
                    ),
                    activeIcon: Badge(
                      isLabelVisible: widget.database
                          .getAllReposts()
                          .isNotEmpty,
                      label: Text('${widget.database.getAllReposts().length}'),
                      backgroundColor: ClearTokColors.cyan,
                      textColor: Colors.black,
                      child: const Icon(Icons.dashboard_rounded),
                    ),
                    label: 'Studio Reposts',
                  ),
                  const glass.GlassTab(
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
