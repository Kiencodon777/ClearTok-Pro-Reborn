import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClearTokAccount {
  static SupabaseClient? client;
  static bool initFailed = false;
  static final accessInvalidated = ValueNotifier<int>(0);

  static bool get isGuestMode =>
      initFailed || (client != null && client!.auth.currentSession == null);

  static Future<Map<String, dynamic>> check({String? feature}) async {
    final api = client;
    if (api == null) throw StateError('ClearTok chưa được cấu hình');
    if (api.auth.currentSession == null) {
      throw StateError('Cần đăng nhập ClearTok');
    }
    final id = await _installationId();
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final shortTag = id.length >= 4 ? id.substring(id.length - 4) : id;
    const appVersion = String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '2.4.0',
    );
    final response = await api.functions
        .invoke(
          'account',
          body: {
            'action': 'register_device',
            'payload': {
              if (feature != null) 'feature': feature,
              'device_id': id,
              'platform': isIos ? 'ios' : 'android',
              'device_name':
                  'LapinTokk ${isIos ? "iOS" : "Android"} (#$shortTag)',
              'app_version': appVersion,
            },
          },
        )
        .catchError((Object error) {
          if (error is FunctionException &&
              (error.status == 401 || error.status == 403)) {
            accessInvalidated.value++;
          }
          throw error;
        });
    if (response.status != 200) {
      throw StateError('Tài khoản không được phép truy cập');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<String> _installationId() async {
    final preferences = await SharedPreferences.getInstance();
    var id = preferences.getString('cleartok_installation_id');
    if (id == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      id =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      await preferences.setString('cleartok_installation_id', id);
    }
    return id;
  }
}

bool isClearTokAuthCallback(Uri uri) {
  if (uri.scheme != 'cleartok' ||
      uri.host != 'auth-callback' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !['', '/'].contains(uri.path)) {
    return false;
  }
  try {
    final parameters = {
      ...uri.queryParameters,
      ...Uri.splitQueryString(uri.fragment),
    };
    return [
      'code',
      'access_token',
      'error',
      'error_code',
      'error_description',
    ].any(parameters.containsKey);
  } on FormatException {
    return false;
  }
}
