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

  const ClearTokApp({super.key, required this.database, required this.remoteConfig});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClearTok Pro — Reborn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(backgroundColor: ClearTokColors.surface,
          surfaceTintColor: Colors.transparent, elevation: 0),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: ClearTokColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFE2C55),
          secondary: Color(0xFF25F4EE),
          surface: Color(0xFF161926),
        ),
      ),
      builder: (context, child) => AmbientBackground(child: child!),
      home: MainNavigationScreen(database: database, remoteConfig: remoteConfig),
    );
  }
}
