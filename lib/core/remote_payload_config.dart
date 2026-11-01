import 'dart:convert';
import 'package:http/http.dart' as http;

class RemotePayloadConfig {
  static const String fallbackScanEndpoint = 'https://www.tiktok.com/api/repost/item_list/';
  static const String fallbackDeleteEndpoint = 'https://www.tiktok.com/tiktok/v1/upvote/delete';
  static const String remoteConfigUrl = 'https://raw.githubusercontent.com/Kiencodon777/ClearTok-Pro-Reborn/main/config/remote_payload.json';

  String scanEndpoint = fallbackScanEndpoint;
  String deleteEndpoint = fallbackDeleteEndpoint;
  int aid = 1988;
  int defaultDelayMs = 700;
  bool allowFastMode = true;

  Future<void> syncConfig() async {
    try {
      final res = await http.get(Uri.parse(remoteConfigUrl)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        scanEndpoint = data['scan_endpoint'] ?? fallbackScanEndpoint;
        deleteEndpoint = data['delete_endpoint'] ?? fallbackDeleteEndpoint;
        aid = data['aid'] ?? 1988;
        defaultDelayMs = data['default_delay_ms'] ?? 700;
        allowFastMode = data['allow_fast_mode'] ?? true;
      }
    } catch (_) {}
  }

  /// Extracts user profile directly from TikTok React Hydration context using raw Dart string
  String buildExtractUserScript() {
    return r'''
      (function() {
        try {
          const userFromUniversalData = (data) => {
            const user = data?.__DEFAULT_SCOPE__?.['webapp.app-context']?.user;
            return (user && user.secUid) ? user : null;
          };

          const candidates = [
            globalThis['__$UNIVERSAL_DATA$__'],
            globalThis['__UNIVERSAL_DATA_FOR_REHYDRATION__'],
            globalThis['__$UNIVERSAL_DATA__']
          ];

          for (const d of candidates) {
            if (d) {
              const u = userFromUniversalData(d);
              if (u) return JSON.stringify({status: 'ok', user: u});
            }
          }

          const raw = document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.textContent;
          if (raw) {
            try {
              const u = userFromUniversalData(JSON.parse(raw));
              if (u) return JSON.stringify({status: 'ok', user: u});
            } catch (_) {}
          }

          if (globalThis['SIGI_STATE']?.UserModule?.users) {
            const users = globalThis['SIGI_STATE'].UserModule.users;
            const first = Object.values(users)[0];
            if (first && first.secUid) {
              return JSON.stringify({status: 'ok', user: first});
            }
          }

          return JSON.stringify({status: 'not_logged_in'});
        } catch (e) {
          return JSON.stringify({status: 'error', error: e.toString()});
        }
      })();
    ''';
  }

  /// High-fidelity scan script reconstructed directly from libapp.so
  String buildScanScript({required int cursor, required String secUid, int count = 30}) {
    return '''
      (async function() {
        try {
          const endpoint = '$scanEndpoint';
          const params = new URLSearchParams();
          params.append('aid', '$aid');
          params.append('count', '$count');
          params.append('cursor', '$cursor');
          params.append('secUid', '$secUid');
          params.append('coverFormat', '2');
          params.append('needPinnedItemIds', 'true');
          params.append('post_item_list_request_type', '0');

          const response = await fetch(endpoint + '?' + params.toString(), {
            method: 'GET',
            credentials: 'include',
            headers: {
              'Accept': 'application/json, text/plain, */*'
            }
          });

          const raw = await response.text();
          return raw;
        } catch(e) {
          return JSON.stringify({status_code: -1, error: e.toString()});
        }
      })();
    ''';
  }

  /// High-fidelity un-repost script reconstructed from libapp.so
  String buildDeleteScript({required String itemId, required String csrfToken}) {
    return '''
      (async function() {
        try {
          const resp = await fetch('$deleteEndpoint', {
            method: 'POST',
            credentials: 'include',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'x-secsdk-csrf-token': '$csrfToken',
              'Accept': 'application/json, text/plain, */*'
            },
            body: 'item_id=' + encodeURIComponent('$itemId')
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
