import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// The SDK exposes this test seam; keep JSON work inside Flutter's fake clock.
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';
import 'package:cleartok_reborn/services/cleartok_account.dart';

class AccountFixture {
  static const userId = '00000000-0000-4000-8000-000000000001';
  final user = <String, dynamic>{
    'id': userId,
    'aud': 'authenticated',
    'email': 'test@example.invalid',
    'created_at': '2026-01-01T00:00:00Z',
  };
  late final SupabaseClient api;
  int checks = 0;
  int writes = 0;
  int logins = 0;
  int revoked = 0;
  bool denied = false;
  bool rateLimited = false;
  bool invalidPassword = false;
  String plan = 'free';
  int remaining = 20;
  final operations = <String, String>{};
  Completer<void>? hold;
  final requestBodies = <Map<String, dynamic>>[];
  AccountFixture() {
    SharedPreferences.setMockInitialValues({});
    api = SupabaseClient(
      'https://test.invalid',
      'fixture-public',
      isolate: _TestJson(),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryStorage(),
      ),
      httpClient: MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        requestBodies.add(body);
        if (request.url.path.endsWith('/token') ||
            request.url.path.endsWith('/verify')) {
          logins++;
          if (invalidPassword) {
            return reply({
              'msg': 'private response must never render',
              'code': 'invalid_credentials',
            }, 400);
          }
          return reply({
            'access_token': 'fixture-not-a-secret',
            'refresh_token': 'fixture-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          });
        }
        if (request.url.path.endsWith('/signup')) return reply(user);
        if (request.url.path.endsWith('/user')) {
          if (request.method == 'PUT') writes++;
          return reply(user);
        }
        if (request.url.path.endsWith('/account')) {
          if (body['action'] == 'revoke_device') {
            revoked++;
            denied = true;
            return reply({'ok': true});
          }
          checks++;
          await hold?.future;
          if (rateLimited) {
            return reply({'error': 'Rate limit exceeded'}, 429);
          }
          if (denied) {
            return reply({'error': 'raw response cookie=never-render'}, 403);
          }
          final id = body['payload']?['operation_id'] as String?;
          if (body['action'] == 'reserve_operation' && id != null) {
            if (!operations.containsKey(id)) {
              if (remaining == 0) {
                return reply({'code': 'QUOTA_EXHAUSTED'}, 409);
              }
              remaining--;
              operations[id] = 'reserved';
            }
            return reply({
              'status': operations[id],
              'quota_remaining': remaining,
            });
          }
          if (body['action'] == 'settle_operation' && id != null) {
            if (operations[id] == 'reserved') {
              operations[id] = body['payload']['outcome'] as String;
              if (operations[id] == 'released') remaining++;
            }
            return reply({
              'status': operations[id],
              'quota_remaining': remaining,
            });
          }
          return reply({
            'profile': user,
            'effective_plan': plan,
            'quota_remaining': plan == 'premium' ? null : remaining,
            'entitlement': {'expires_at': null},
            'devices': [
              {
                'id': 'fixture-device-row',
                'platform': 'android',
                'device_name': 'Thiết bị test',
                'is_active': true,
              },
            ],
          });
        }
        return reply({});
      }),
    );
    ClearTokAccount.client = api;
  }
  http.Response reply(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {
      'content-type': 'application/json',
      'x-supabase-api-version': '2024-01-01',
    },
  );
  Future<void> signedIn() async => api.auth.signInWithPassword(
    email: 'test@example.invalid',
    password: 'fixture-password',
  );
  Future<void> recovery() async => api.auth.verifyOTP(
    email: 'test@example.invalid',
    token: 'fixture-code',
    type: OtpType.recovery,
  );
  Future<void> dispose() async {
    ClearTokAccount.client = null;
    await api.dispose();
  }
}

class _TestJson implements YAJsonIsolate {
  @override
  String? get debugName => 'account-fixture';
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<dynamic> decode(String value) async => jsonDecode(value);
  @override
  Future<String> encode(Object? value) async => jsonEncode(value);
}

class _MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}
