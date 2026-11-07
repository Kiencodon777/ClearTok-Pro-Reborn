import 'dart:convert';
import 'package:http/http.dart' as http;

class RemotePayloadConfig {
  static const String fallbackScanEndpoint =
      'https://www.tiktok.com/api/repost/item_list/';
  static const String fallbackDeleteEndpoint =
      'https://www.tiktok.com/tiktok/v1/upvote/delete';
  static const String remoteConfigUrl =
      'https://raw.githubusercontent.com/Kiencodon777/ClearTok-Pro-Reborn/main/config/remote_payload.json';

  String scanEndpoint = fallbackScanEndpoint;
  String deleteEndpoint = fallbackDeleteEndpoint;
  int aid = 1988;
  int defaultDelayMs = 700;
  bool allowFastMode = true;

  static bool isValidTikTokEndpoint(Object? value) {
    if (value is! String || value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'www.tiktok.com' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        uri.path.startsWith('/');
  }

  void applyFromMap(Map<String, dynamic> data) {
    final candidateScan = data['scan_endpoint'];
    if (isValidTikTokEndpoint(candidateScan)) {
      scanEndpoint = (candidateScan as String).trim();
    }
    final candidateDelete = data['delete_endpoint'];
    if (isValidTikTokEndpoint(candidateDelete)) {
      deleteEndpoint = (candidateDelete as String).trim();
    }
    final rawAid = data['aid'];
    if (rawAid is int && rawAid > 0) {
      aid = rawAid;
    } else if (rawAid is String) {
      final parsedAid = int.tryParse(rawAid);
      if (parsedAid != null && parsedAid > 0) aid = parsedAid;
    }
    final rawDelay = data['default_delay_ms'];
    if (rawDelay is int && rawDelay >= 150 && rawDelay <= 10000) {
      defaultDelayMs = rawDelay;
    }
    final rawFast = data['allow_fast_mode'];
    if (rawFast is bool) {
      allowFastMode = rawFast;
    }
  }

  Future<void> syncConfig() async {
    try {
      final res = await http
          .get(Uri.parse(remoteConfigUrl))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.bodyBytes.length <= 16384) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          applyFromMap(decoded);
        }
      }
    } catch (_) {}
  }
}
