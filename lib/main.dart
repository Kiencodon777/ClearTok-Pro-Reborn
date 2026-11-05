import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/remote_payload_config.dart';
import 'database/local_database.dart';
import 'services/cleartok_account.dart';
import 'services/cleartok_account_session.dart';
import 'ui/screens/cleartok_account_screen.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/widgets/liquid_glass.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  ClearTokAccountSession? accountSession;
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: FlutterAuthClientOptions(
        detectSessionInUriPredicate: (uri) {
          if (!isClearTokAuthCallback(uri)) return false;
          ClearTokAccount.client = Supabase.instance.client;
          accountSession ??= ClearTokAccountSession(Supabase.instance.client);
          accountSession!.beginCallback();
          return true;
        },
      ),
    );
    ClearTokAccount.client = Supabase.instance.client;
    accountSession ??= ClearTokAccountSession(Supabase.instance.client);
  }

  await Hive.initFlutter();
  final database = LocalDatabase();
  await database.init();
  LiquidSoundHaptics.enabled = database.soundEffectsEnabled;

  final remoteConfig = RemotePayloadConfig();
  await remoteConfig.syncConfig();

  runApp(
    ClearTokApp(
      database: database,
      remoteConfig: remoteConfig,
      accountSession: accountSession,
    ),
  );
}

class ClearTokApp extends StatelessWidget {
  final LocalDatabase database;
  final RemotePayloadConfig remoteConfig;
  final ClearTokAccountSession? accountSession;

  const ClearTokApp({
    super.key,
    required this.database,
    required this.remoteConfig,
    this.accountSession,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LapinTokk',
      debugShowCheckedModeBanner: false,
      theme: clearTokTheme(),
      builder: (context, child) => AmbientBackground(child: child!),
      home: ClearTokAccountGate(
        session: accountSession,
        child: MainNavigationScreen(
          database: database,
          remoteConfig: remoteConfig,
        ),
      ),
    );
  }
}
