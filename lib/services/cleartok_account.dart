import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClearTokAccount {
  static SupabaseClient? client;
  static bool initFailed = false;
  static final accessInvalidated = ValueNotifier<int>(0);

  static bool get isGuestMode =>
      initFailed || client?.auth.currentSession == null;

  static final quota =
      ValueNotifier<({String user, bool unlimited, int remaining})?>(null);

  static Future<Map<String, dynamic>> check({String? feature}) =>
      _request('register_device', {if (feature != null) 'feature': feature});

  static Future<Map<String, dynamic>> reserveOperation(
    String feature,
    String id,
  ) => _request('reserve_operation', {'feature': feature, 'operation_id': id});

  static Future<Map<String, dynamic>> settleOperation(
    String feature,
    String id,
    String outcome,
  ) => _request('settle_operation', {
    'feature': feature,
    'operation_id': id,
    'outcome': outcome,
  });

  static Future<Map<String, dynamic>> _request(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final api = client;
    if (api == null) throw StateError('ClearTok chưa được cấu hình');
    final user = api.auth.currentSession?.user.id;
    if (user == null) throw StateError('Cần đăng nhập ClearTok');
    final id = await _installationId();
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final shortTag = id.length >= 4 ? id.substring(id.length - 4) : id;
    const appVersion = String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '2.5.0',
    );
    try {
      final response = await api.functions.invoke(
        'account',
        body: {
          'action': action,
          'payload': {
            ...payload,
            'device_id': id,
            if (action == 'register_device') ...{
              'platform': isIos ? 'ios' : 'android',
              'device_name':
                  'LapinTokk ${isIos ? "iOS" : "Android"} (#$shortTag)',
              'app_version': appVersion,
            },
          },
        },
      );
      if (api != client || api.auth.currentUser?.id != user) {
        throw StateError('Tài khoản đã thay đổi');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      final profile = data['profile'];
      final unlimited = action == 'register_device'
          ? data['effective_plan'] == 'premium' ||
                (profile is Map && profile['role'] == 'admin')
          : quota.value?.user == user && quota.value!.unlimited;
      final remaining = data['quota_remaining'];
      quota.value = (
        user: user,
        unlimited: unlimited && remaining == null,
        remaining: remaining is int ? remaining : 0,
      );
      if (action == 'reserve_operation' &&
          (data['status'] != 'reserved' ||
              !(remaining is int && remaining >= 0 ||
                  unlimited &&
                      data.containsKey('quota_remaining') &&
                      remaining == null))) {
        throw StateError('Máy chủ chưa xác nhận hạn mức');
      }
      return data;
    } on FunctionException catch (error) {
      if (api == client && api.auth.currentUser?.id == user) {
        if (error.status == 401 || error.status == 403) {
          quota.value = null;
          accessInvalidated.value++;
        } else if (error.status == 409 &&
            error.details is Map &&
            error.details['code'] == 'QUOTA_EXHAUSTED') {
          quota.value = (user: user, unlimited: false, remaining: 0);
        }
      }
      rethrow;
    }
  }

  static String newOperationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<String> _installationId() async {
    final preferences = await SharedPreferences.getInstance();
    var id = preferences.getString('cleartok_installation_id');
    if (id == null) {
      id = newOperationId();
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
