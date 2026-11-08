import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/secure_supabase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/remote_payload_config.dart';
import 'database/local_database.dart';
import 'services/cleartok_account.dart';
import 'services/cleartok_account_session.dart';
import 'services/diagnostic_log.dart';
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
  ClearTokAccount.initFailed = false;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: key,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureSupabaseStorage(
            storage: const FlutterSecureStorage(),
            key: 'sb-${Uri.parse(url).host.split('.').first}-auth-token',
          ),
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
    } catch (e) {
      DiagnosticLog.instance.record(
        'supabase.init',
        -1,
        details: {'error': e.toString()},
      );
      ClearTokAccount.initFailed = true;
      ClearTokAccount.client = null;
      accountSession = null;
    }
  }

  await Hive.initFlutter();
  final database = LocalDatabase();
  try {
    await database.init();
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Không thể mở dữ liệu an toàn. Dữ liệu cũ được giữ lại.',
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await database.init();
                      LiquidSoundHaptics.enabled = database.soundEffectsEnabled;
                      runApp(
                        ClearTokApp(
                          database: database,
                          remoteConfig: const RemotePayloadConfig(),
                          accountSession: accountSession,
                        ),
                      );
                    } catch (_) {}
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }
  LiquidSoundHaptics.enabled = database.soundEffectsEnabled;

  const remoteConfig = RemotePayloadConfig();

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
        allowGuest: true,
        child: mainScreen,
      ),
    );
  }
}
