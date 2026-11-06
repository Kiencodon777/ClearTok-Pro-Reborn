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

const _defaultSupabaseUrl = 'https://jsxxxbspjmpbaomotgcj.supabase.co';
const _defaultSupabaseKey = 'sb_publishable_OgS5NTFXDFZ0OTB1DTxDFA_Bh7YDyQ5';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const envUrl = String.fromEnvironment('SUPABASE_URL');
  const envKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final url = envUrl.isNotEmpty ? envUrl : _defaultSupabaseUrl;
  final key = envKey.isNotEmpty ? envKey : _defaultSupabaseKey;
  ClearTokAccountSession? accountSession;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
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
    } catch (_) {
      ClearTokAccount.client = null;
      accountSession = null;
    }
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
    final mainScreen = MainNavigationScreen(
      database: database,
      remoteConfig: remoteConfig,
    );

    return MaterialApp(
      title: 'LapinTokk',
      debugShowCheckedModeBanner: false,
      theme: clearTokTheme(),
      builder: (context, child) => AmbientBackground(child: child!),
      home: ClearTokAccountGate(
        session: accountSession,
        child: mainScreen,
      ),
    );
  }
}
