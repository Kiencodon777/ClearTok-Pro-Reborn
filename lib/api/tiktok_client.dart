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

class DeleteResult {
  final bool success;
  final int statusCode;
  final String message;
  final String rawResponse;

  DeleteResult({
    required this.success,
    required this.statusCode,
    required this.message,
    required this.rawResponse,
  });
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

  /// Robust un-repost implementation supporting query param, form, and json fallbacks
  Future<DeleteResult> deleteSingleRepost({required String itemId}) async {
    const functionBody = r'''
      try {
        // Fallback 1: Query param URL as discovered in libapp.so (POST https://www.tiktok.com/tiktok/v1/upvote/delete?item_id=... with same-origin)
        const urlWithQuery = deleteEndpoint + '?item_id=' + encodeURIComponent(itemId);
        let resp = await fetch(urlWithQuery, {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Accept': '*/*' }
        });

        let raw = await resp.text();
        let parsed = null;
        try { parsed = JSON.parse(raw); } catch(_) {}

        if (parsed && (parsed.status_code === 0 || parsed.status_code === '0')) {
          return JSON.stringify({ success: true, status_code: 0, message: 'ok', raw: raw });
        }

        // Fallback 2: Form URL Encoded Body
        resp = await fetch(deleteEndpoint, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': '*/*'
          },
          body: 'item_id=' + encodeURIComponent(itemId)
        });

        raw = await resp.text();
        parsed = null;
        try { parsed = JSON.parse(raw); } catch(_) {}

        if (parsed && (parsed.status_code === 0 || parsed.status_code === '0')) {
          return JSON.stringify({ success: true, status_code: 0, message: 'ok (form-body)', raw: raw });
        }

        // Fallback 3: JSON payload
        resp = await fetch(deleteEndpoint, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Content-Type': 'application/json',
            'Accept': '*/*'
          },
          body: JSON.stringify({ item_id: itemId })
        });

        raw = await resp.text();
        parsed = null;
        try { parsed = JSON.parse(raw); } catch(_) {}

        if (parsed && (parsed.status_code === 0 || parsed.status_code === '0')) {
          return JSON.stringify({ success: true, status_code: 0, message: 'ok (json-body)', raw: raw });
        }

        const errCode = parsed ? (parsed.status_code ?? -1) : resp.status;
        const errMsg = parsed ? (parsed.status_msg ?? parsed.error ?? 'Unknown error') : ('HTTP ' + resp.status);

        return JSON.stringify({
          success: false,
          status_code: errCode,
          message: errMsg,
          raw: raw
        });
      } catch (e) {
        return JSON.stringify({ success: false, status_code: -1, message: e.toString(), raw: '' });
      }
    ''';

    final asyncResult = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        'deleteEndpoint': remoteConfig.deleteEndpoint,
        'itemId': itemId,
      },
    );

    if (asyncResult == null || asyncResult.value == null) {
      return DeleteResult(success: false, statusCode: -1, message: 'Null response from WebView', rawResponse: '');
    }

    final data = jsonDecode(asyncResult.value.toString()) as Map<String, dynamic>;
    return DeleteResult(
      success: data['success'] == true,
      statusCode: data['status_code'] as int? ?? -1,
      message: data['message']?.toString() ?? '',
      rawResponse: data['raw']?.toString() ?? '',
    );
  }
}
