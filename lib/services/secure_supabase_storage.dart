import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureSupabaseStorage extends LocalStorage {
  SecureSupabaseStorage({
    required this.storage,
    required this.key,
    LocalStorage? legacy,
  }) : legacy = legacy ?? SharedPreferencesLocalStorage(persistSessionKey: key);
  final FlutterSecureStorage storage;
  final String key;
  final LocalStorage legacy;
  @override
  Future<void> initialize() async {
    await legacy.initialize();
    final existing = await storage.read(key: key);
    final old = await legacy.accessToken();
    if (existing == null && old != null) {
      await storage.write(key: key, value: old);
      if (await storage.read(key: key) != old) {
        throw StateError('Session migration verification failed');
      }
    }
    if (old != null) await legacy.removePersistedSession();
  }

  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<void> persistSession(String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> removePersistedSession() async {
    await storage.delete(key: key);
    await legacy.removePersistedSession();
  }
}
