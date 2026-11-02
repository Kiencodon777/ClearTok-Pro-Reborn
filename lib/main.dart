import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/remote_payload_config.dart';
import 'database/local_database.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/widgets/liquid_glass.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  const ClearTokApp(
      {super.key, required this.database, required this.remoteConfig});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClearTok Pro — Reborn',
      debugShowCheckedModeBanner: false,
      theme: clearTokTheme(),
      builder: (context, child) => AmbientBackground(child: child!),
      home:
          MainNavigationScreen(database: database, remoteConfig: remoteConfig),
    );
  }
}
