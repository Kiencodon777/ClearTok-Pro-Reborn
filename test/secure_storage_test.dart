import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cleartok_reborn/database/local_database.dart';
import 'package:cleartok_reborn/services/secure_supabase_storage.dart';

class MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  bool failWrites = false;
  bool dropWrites = false;
  String? failKey;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (dropWrites) return;
    if (failWrites || key == failKey) throw StateError('write failed');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class Legacy extends LocalStorage {
  String? value;
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => value;
  @override
  Future<bool> hasAccessToken() async => value != null;
  @override
  Future<void> persistSession(String value) async {
    this.value = value;
  }

  @override
  Future<void> removePersistedSession() async {
    value = null;
  }
}

void main() {
  for (final secure in [false, true]) {
    test('session migration secure existing: $secure', () async {
      final storage = MemoryStorage();
      final legacy = Legacy()..value = 'old';
      if (secure) storage.values['session'] = 'new';
      final adapter = SecureSupabaseStorage(
        storage: storage,
        key: 'session',
        legacy: legacy,
      );
      await adapter.initialize();
      await adapter.initialize();
      expect(await adapter.accessToken(), secure ? 'new' : 'old');
      expect(legacy.value, isNull);
    });
  }
  test('failed session migration preserves plaintext for retry', () async {
    final storage = MemoryStorage()..failWrites = true;
    final legacy = Legacy()..value = 'old';
    final adapter = SecureSupabaseStorage(
      storage: storage,
      key: 'session',
      legacy: legacy,
    );
    await expectLater(adapter.initialize(), throwsStateError);
    expect(legacy.value, 'old');
    storage.failWrites = false;
    await adapter.initialize();
    expect(await adapter.accessToken(), 'old');
  });
  test('session readback failure keeps legacy token', () async {
    final storage = MemoryStorage()..dropWrites = true;
    final legacy = Legacy()..value = 'old';
    await expectLater(
      SecureSupabaseStorage(
        storage: storage,
        key: 'session',
        legacy: legacy,
      ).initialize(),
      throwsStateError,
    );
    expect(legacy.value, 'old');
  });
  test('fresh session remains empty', () async {
    final adapter = SecureSupabaseStorage(
      storage: MemoryStorage(),
      key: 'session',
      legacy: Legacy(),
    );
    await adapter.initialize();
    expect(await adapter.hasAccessToken(), false);
  });
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cleartok-migration');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('all five legacy boxes migrate and reopen without data loss', () async {
    for (final name in LocalDatabase.boxNames) {
      final box = await Hive.openBox(name);
      await box.put('fixture', {
        'nested': [1, true, 'personal-data'],
      });
      await box.close();
    }
    final storage = MemoryStorage();
    final db = LocalDatabase(storage: storage);
    await db.init();
    for (final name in LocalDatabase.boxNames) {
      expect(await Hive.boxExists(name), false);
      expect(Hive.box('${name}_secure_v2').get('fixture'), {
        'nested': [1, true, 'personal-data'],
      });
    }
    await db.dispose();
    await LocalDatabase(storage: storage).init();
  });
  test(
    'partial migration retries and missing key never opens empty database',
    () async {
      final legacy = await Hive.openBox(LocalDatabase.repostBoxName);
      await legacy.put('id', {'value': 'private'});
      await legacy.close();
      final storage = MemoryStorage()..failWrites = true;
      await expectLater(
        LocalDatabase(storage: storage).init(),
        throwsStateError,
      );
      expect(await Hive.boxExists(LocalDatabase.repostBoxName), true);
      storage.failWrites = false;
      final db = LocalDatabase(storage: storage);
      await db.init();
      await db.dispose();
      storage.values.remove('cleartok_hive_key_v1');
      await expectLater(
        LocalDatabase(storage: storage).init(),
        throwsStateError,
      );
    },
  );
  test('marker failure retains legacy box and retry completes', () async {
    final legacy = await Hive.openBox(LocalDatabase.repostBoxName);
    await legacy.put('fixture', {'value': 'private'});
    await legacy.close();
    final storage = MemoryStorage()
      ..failKey = '${LocalDatabase.repostBoxName}_secure_v2_migrated';
    await expectLater(LocalDatabase(storage: storage).init(), throwsStateError);
    expect(await Hive.boxExists(LocalDatabase.repostBoxName), true);
    storage.failKey = null;
    final db = LocalDatabase(storage: storage);
    await db.init();
    expect(await Hive.boxExists(LocalDatabase.repostBoxName), false);
    await db.dispose();
  });
  test('count does not decode 10000 cached records', () async {
    final db = LocalDatabase(storage: MemoryStorage());
    await db.init();
    await Hive.box(
      '${LocalDatabase.repostBoxName}_secure_v2',
    ).putAll({for (var i = 0; i < 10000; i++) i: 'not a model'});
    expect(db.repostCount, 10000);
    await db.dispose();
  });
}
