import 'dart:convert';
import 'package:http/http.dart' as http;

class RemotePayloadConfig {
  static const String fallbackScanEndpoint = 'https://www.tiktok.com/api/repost/item_list/';
  static const String fallbackDeleteEndpoint = 'https://www.tiktok.com/tiktok/v1/upvote/delete';
  
  // URL hosting dynamic updates when TikTok changes their internal schemas
  static const String remoteConfigUrl = 'https://raw.githubusercontent.com/Kiencodon777/ClearTok-Pro-Reborn/main/config/remote_payload.json';

  String scanEndpoint = fallbackScanEndpoint;
  String deleteEndpoint = fallbackDeleteEndpoint;
  int aid = 1988;
  int defaultDelayMs = 700;
  bool allowFastMode = true;

  Future<void> syncConfig() async {
    try {
      final res = await http.get(Uri.parse(remoteConfigUrl)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        scanEndpoint = data['scan_endpoint'] ?? fallbackScanEndpoint;
        deleteEndpoint = data['delete_endpoint'] ?? fallbackDeleteEndpoint;
        aid = data['aid'] ?? 1988;
        defaultDelayMs = data['default_delay_ms'] ?? 700;
        allowFastMode = data['allow_fast_mode'] ?? true;
      }
    } catch (_) {
      // Graceful fallback to baked-in defaults if offline
    }
  }

  String buildScanScript({required int cursor, required String secUid}) {
    return '''
      (async function() {
        try {
          const url = '$scanEndpoint?aid=$aid&count=30&cursor=$cursor&secUid=' + encodeURIComponent('$secUid') + '&coverFormat=2&needPinnedItemIds=true&post_item_list_request_type=0';
          const resp = await fetch(url, {
            method: 'GET',
            headers: {
              'Accept': 'application/json, text/plain, */*'
            },
            credentials: 'include'
          });
          const text = await resp.text();
          return text;
        } catch(e) {
          return JSON.stringify({status_code: -1, error: e.toString()});
        }
      })();
    ''';
  }

  String buildDeleteScript({required String itemId, required String csrfToken}) {
    return '''
      (async function() {
        try {
          const resp = await fetch('$deleteEndpoint', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'x-secsdk-csrf-token': '$csrfToken'
            },
            body: 'item_id=' + encodeURIComponent('$itemId'),
            credentials: 'include'
          });
          const text = await resp.text();
          return text;
        } catch(e) {
          return JSON.stringify({status_code: -1, error: e.toString()});
        }
      })();
    ''';
  }
}
