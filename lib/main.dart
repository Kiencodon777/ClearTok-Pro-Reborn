import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'core/remote_payload_config.dart';
import 'database/local_database.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/widgets/liquid_glass.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await glass.LiquidGlassWidgets.initialize();

  await Hive.initFlutter();
  final database = LocalDatabase();
  await database.init();

  final remoteConfig = RemotePayloadConfig();
  await remoteConfig.syncConfig();

  runApp(ClearTokApp(database: database, remoteConfig: remoteConfig));
}

class ClearTokApp extends StatelessWidget {
  final LocalDatabase database;
  final RemotePayloadConfig remoteConfig;

  const ClearTokApp({
    super.key,
    required this.database,
    required this.remoteConfig,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClearTok Pro — Reborn',
      debugShowCheckedModeBanner: false,
      theme: clearTokTheme(),
      builder: (context, child) => glass.LiquidGlassWidgets.wrap(
        theme: const glass.GlassThemeData.ios27(brightness: Brightness.dark),
        brightnessResolver: Theme.maybeBrightnessOf,
        child: glass.GlassPage(
          background: const AmbientBackground(child: SizedBox.expand()),
          child: child!,
        ),
      ),
      home: MainNavigationScreen(
        database: database,
        remoteConfig: remoteConfig,
      ),
    );
  }
}
