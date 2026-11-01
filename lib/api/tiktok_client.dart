import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/remote_payload_config.dart';
import '../models/tiktok_video.dart';

class TikTokUserProfile {
  final String id;
  final String uniqueId;
  final String nickname;
  final String avatarThumb;
  final String secUid;

  TikTokUserProfile({
    required this.id,
    required this.uniqueId,
    required this.nickname,
    required this.avatarThumb,
    required this.secUid,
  });

  factory TikTokUserProfile.fromJson(Map<String, dynamic> json) {
    return TikTokUserProfile(
      id: json['id']?.toString() ?? '',
      uniqueId: json['uniqueId']?.toString() ?? json['unique_id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatarThumb: json['avatarThumb']?.toString() ?? json['avatar_thumb']?.toString() ?? '',
      secUid: json['secUid']?.toString() ?? json['sec_uid']?.toString() ?? '',
    );
  }
}

class ScanResult {
  final List<TikTokVideo> videos;
  final int nextCursor;
  final bool hasMore;

  ScanResult({required this.videos, required this.nextCursor, required this.hasMore});
}

class TikTokClient {
  final InAppWebViewController webViewController;
  final RemotePayloadConfig remoteConfig;

  TikTokClient({required this.webViewController, required this.remoteConfig});

  Future<TikTokUserProfile?> extractLiveUserProfile() async {
    try {
      const functionBody = r'''
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
      ''';

      final asyncResult = await webViewController.callAsyncJavaScript(functionBody: functionBody);
      if (asyncResult == null || asyncResult.value == null) return null;

      final data = jsonDecode(asyncResult.value.toString()) as Map<String, dynamic>;
      if (data['status'] == 'ok' && data['user'] != null) {
        return TikTokUserProfile.fromJson(data['user'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getCookie(String name) async {
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: WebUri('https://www.tiktok.com'));
    for (var c in cookies) {
      if (c.name == name) return c.value;
    }
    return null;
  }

  Future<String> extractCsrfToken() async {
    try {
      const functionBody = r'''
        try {
          const match = document.cookie.match(/s_v_web_id=([^;]+)/);
          if (match) return match[1];
          const ttwid = document.cookie.match(/ttwid=([^;]+)/);
          if (ttwid) return ttwid[1];
          return '';
        } catch(_) {
          return '';
        }
      ''';
      final asyncResult = await webViewController.callAsyncJavaScript(functionBody: functionBody);
      if (asyncResult != null && asyncResult.value != null && asyncResult.value.toString().isNotEmpty) {
        return asyncResult.value.toString();
      }
    } catch (_) {}

    final token = await getCookie('s_v_web_id') ?? await getCookie('ttwid') ?? '';
    return token;
  }

  Future<ScanResult> fetchRepostBatch({required int cursor, required String secUid}) async {
    const functionBody = r'''
      try {
        const endpoint = scanEndpoint;
        const params = new URLSearchParams();
        params.append('aid', String(aid));
        params.append('count', String(count));
        params.append('cursor', String(cursor));
        params.append('secUid', String(secUid));
        params.append('coverFormat', '2');
        params.append('needPinnedItemIds', 'true');
        params.append('post_item_list_request_type', '0');

        const response = await fetch(endpoint + '?' + params.toString(), {
          method: 'GET',
          credentials: 'same-origin',
          headers: {
            'Accept': '*/*'
          }
        });

        const raw = await response.text();
        return raw;
      } catch (e) {
        return JSON.stringify({status_code: -1, error: e.toString()});
      }
    ''';

    final asyncResult = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        'scanEndpoint': remoteConfig.scanEndpoint,
        'aid': remoteConfig.aid,
        'count': 30,
        'cursor': cursor,
        'secUid': secUid,
      },
    );

    if (asyncResult == null) {
      throw Exception('WebView returned null from callAsyncJavaScript');
    }

    if (asyncResult.error != null && asyncResult.error!.isNotEmpty) {
      throw Exception('JavaScript Error: ${asyncResult.error}');
    }

    final rawResult = asyncResult.value;
    if (rawResult == null || rawResult.toString().isEmpty) {
      throw Exception('Empty data returned from TikTok API');
    }

    final data = jsonDecode(rawResult.toString()) as Map<String, dynamic>;
    if (data['status_code'] != 0 && data['status_code'] != null) {
      throw Exception('TikTok Error: ${data['status_code']} - ${data['error'] ?? data['status_msg'] ?? 'API rejected'}');
    }

    final itemList = data['itemList'] as List<dynamic>? ?? [];
    final videos = itemList
        .map((item) => TikTokVideo.fromJson(item as Map<String, dynamic>, secUid: secUid))
        .toList();

    final nextCursor = int.tryParse(data['max_cursor']?.toString() ?? '0') ?? 0;
    final hasMore = data['hasMore'] == true;

    return ScanResult(videos: videos, nextCursor: nextCursor, hasMore: hasMore);
  }

  Future<bool> deleteSingleRepost({required String itemId, required String csrfToken}) async {
    const functionBody = r'''
      try {
        const resp = await fetch(deleteEndpoint, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'x-secsdk-csrf-token': csrfToken,
            'Accept': '*/*'
          },
          body: 'item_id=' + encodeURIComponent(itemId)
        });
        const text = await resp.text();
        return text;
      } catch (e) {
        return JSON.stringify({status_code: -1, error: e.toString()});
      }
    ''';

    final asyncResult = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        'deleteEndpoint': remoteConfig.deleteEndpoint,
        'itemId': itemId,
        'csrfToken': csrfToken,
      },
    );

    if (asyncResult == null || asyncResult.value == null) return false;
    final data = jsonDecode(asyncResult.value.toString()) as Map<String, dynamic>;

    if (data['status_code'] == 0) {
      return true;
    } else if (data['status_code'] == 3002226 || data['status_code'] == 429) {
      throw Exception('RATE_LIMITED');
    } else {
      return false;
    }
  }
}
