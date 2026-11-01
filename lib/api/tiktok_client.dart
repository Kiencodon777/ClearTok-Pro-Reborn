import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/remote_payload_config.dart';
import '../models/tiktok_follow_user.dart';
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

  // ─── 1. FETCH REPOSTS ─────────────────────────────────────────────────────
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

    // Robust pagination: check cursor, max_cursor, min_cursor and fallback to last video timestamp
    int nextCursor = int.tryParse(data['cursor']?.toString() ??
            data['max_cursor']?.toString() ??
            data['min_cursor']?.toString() ??
            '') ??
        0;

    if (nextCursor <= 0 && videos.isNotEmpty) {
      final lastTime = videos.last.repostTimestamp;
      if (lastTime > 0) {
        nextCursor = lastTime > 10000000000 ? lastTime : lastTime * 1000;
      }
    }

    final rawHasMore = data['hasMore'] ?? data['has_more'];
    final bool hasMore = (rawHasMore == true ||
            rawHasMore == 1 ||
            rawHasMore == '1' ||
            rawHasMore == 'true') ||
        (itemList.length >= 20 && nextCursor > 0);

    return ScanResult(videos: videos, nextCursor: nextCursor, hasMore: hasMore);
  }

  // ─── 2. FETCH LIKED VIDEOS (FOR MASS UN-LIKE) ─────────────────────────────
  Future<ScanResult> fetchLikedVideosBatch({required int cursor, required String secUid}) async {
    const functionBody = r'''
      try {
        const endpoint = 'https://www.tiktok.com/api/favorite/item_list/';
        const params = new URLSearchParams();
        params.append('aid', String(aid));
        params.append('count', '30');
        params.append('cursor', String(cursor));
        params.append('secUid', String(secUid));
        params.append('coverFormat', '2');

        const response = await fetch(endpoint + '?' + params.toString(), {
          method: 'GET',
          credentials: 'include',
          headers: { 'Accept': '*/*' }
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
        'aid': remoteConfig.aid,
        'cursor': cursor,
        'secUid': secUid,
      },
    );

    if (asyncResult == null || asyncResult.value == null) {
      return ScanResult(videos: [], nextCursor: 0, hasMore: false);
    }

    final raw = asyncResult.value.toString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final itemList = data['itemList'] as List<dynamic>? ?? [];
    final videos = itemList
        .map((item) => TikTokVideo.fromJson(item as Map<String, dynamic>, secUid: secUid))
        .toList();

    int nextCursor = int.tryParse(data['cursor']?.toString() ??
            data['max_cursor']?.toString() ??
            data['min_cursor']?.toString() ??
            '') ??
        0;

    if (nextCursor <= 0 && videos.isNotEmpty) {
      final lastTime = videos.last.repostTimestamp;
      if (lastTime > 0) {
        nextCursor = lastTime > 10000000000 ? lastTime : lastTime * 1000;
      }
    }

    final rawHasMore = data['hasMore'] ?? data['has_more'];
    final bool hasMore = (rawHasMore == true ||
            rawHasMore == 1 ||
            rawHasMore == '1' ||
            rawHasMore == 'true') ||
        (itemList.length >= 20 && nextCursor > 0);

    return ScanResult(videos: videos, nextCursor: nextCursor, hasMore: hasMore);
  }

  // ─── 3. FETCH FOLLOWING USERS (FOR MASS UN-FOLLOW) ────────────────────────
  Future<FollowingScanResult> fetchFollowingUsersBatch({required int cursor, required String secUid}) async {
    const functionBody = r'''
      try {
        const endpoint = 'https://www.tiktok.com/api/user/list/';
        const params = new URLSearchParams();
        params.append('aid', String(aid));
        params.append('count', '30');
        params.append('minCursor', '0');
        params.append('maxCursor', String(cursor));
        params.append('secUid', String(secUid));
        params.append('scene', '21'); // 21 = following list

        const response = await fetch(endpoint + '?' + params.toString(), {
          method: 'GET',
          credentials: 'include',
          headers: { 'Accept': '*/*' }
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
        'aid': remoteConfig.aid,
        'cursor': cursor,
        'secUid': secUid,
      },
    );

    if (asyncResult == null || asyncResult.value == null) {
      return FollowingScanResult(users: [], nextCursor: 0, hasMore: false);
    }

    final raw = asyncResult.value.toString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final userList = data['userList'] as List<dynamic>? ?? [];
    final users = userList
        .map((u) => TikTokFollowUser.fromJson(u as Map<String, dynamic>))
        .toList();

    int nextCursor = int.tryParse(data['maxCursor']?.toString() ??
            data['max_cursor']?.toString() ??
            data['cursor']?.toString() ??
            '') ??
        0;

    if (nextCursor <= 0 && users.isNotEmpty) {
      nextCursor = cursor + users.length;
    }

    final rawHasMore = data['hasMore'] ?? data['has_more'];
    final bool hasMore = (rawHasMore == true ||
            rawHasMore == 1 ||
            rawHasMore == '1' ||
            rawHasMore == 'true') ||
        (userList.length >= 20);

    return FollowingScanResult(users: users, nextCursor: nextCursor, hasMore: hasMore);
  }

  // ─── 4. DELETE SINGLE REPOST ──────────────────────────────────────────────
  Future<DeleteResult> deleteSingleRepost({required String itemId}) async {
    const functionBody = r'''
      try {
        const getCsrf = () => {
          const m = document.cookie.match(/(?:^|;\s*)(?:tt_csrf_token|csrf_token|passport_csrf_token)=([^;]+)/);
          return m ? decodeURIComponent(m[1]) : '';
        };
        const csrf = getCsrf();

        const baseHeaders = {
          'Accept': 'application/json, text/plain, */*'
        };
        if (csrf) {
          baseHeaders['x-secsdk-csrf-token'] = csrf;
        }

        const urlWithAid = deleteEndpoint.includes('?') 
          ? (deleteEndpoint + '&aid=' + String(aid)) 
          : (deleteEndpoint + '?aid=' + String(aid));

        // Format 1 (Standard Web JSON with item_id and type: 1)
        try {
          const jsonHeaders = Object.assign({}, baseHeaders, { 'Content-Type': 'application/json' });
          const resp = await fetch(urlWithAid, {
            method: 'POST',
            credentials: 'include',
            headers: jsonHeaders,
            body: JSON.stringify({
              item_id: String(itemId),
              type: 1
            })
          });

          const raw = await resp.text();
          let parsed = null;
          try { parsed = JSON.parse(raw); } catch(_) {}

          if (parsed && (parsed.status_code === 0 || parsed.status_code === '0')) {
            return JSON.stringify({ success: true, status_code: 0, message: 'ok (json-type1)', raw: raw });
          }
        } catch (_) {}

        // Format 2 (Form URL Encoded with item_id and type=1)
        try {
          const formHeaders = Object.assign({}, baseHeaders, { 'Content-Type': 'application/x-www-form-urlencoded' });
          const resp = await fetch(urlWithAid, {
            method: 'POST',
            credentials: 'include',
            headers: formHeaders,
            body: 'item_id=' + encodeURIComponent(itemId) + '&type=1'
          });

          const raw = await resp.text();
          let parsed = null;
          try { parsed = JSON.parse(raw); } catch(_) {}

          if (parsed && (parsed.status_code === 0 || parsed.status_code === '0')) {
            return JSON.stringify({ success: true, status_code: 0, message: 'ok (form-type1)', raw: raw });
          }
        } catch (_) {}

        // Format 3 (Query Parameters with aid, item_id, and type=1)
        try {
          const queryUrl = urlWithAid + '&item_id=' + encodeURIComponent(itemId) + '&type=1';
          const resp = await fetch(queryUrl, {
            method: 'POST',
            credentials: 'include',
            headers: baseHeaders
          });

          const raw = await resp.text();
          let parsed = null;
          try { parsed = JSON.parse(raw); } catch(_) {}

          if (parsed && (parsed.status_code === 0 || parsed.status_code === '0')) {
            return JSON.stringify({ success: true, status_code: 0, message: 'ok (query-type1)', raw: raw });
          }

          if (parsed) {
            return JSON.stringify({
              success: false,
              status_code: parsed.status_code ?? -1,
              message: parsed.status_msg ?? parsed.error ?? 'API error',
              raw: raw
            });
          }
        } catch (_) {}

        // Format 4 (Fallback query with same-origin credentials)
        const finalUrl = urlWithAid + '&item_id=' + encodeURIComponent(itemId) + '&type=1';
        const finalResp = await fetch(finalUrl, {
          method: 'POST',
          credentials: 'same-origin',
          headers: baseHeaders
        });

        const finalRaw = await finalResp.text();
        let finalParsed = null;
        try { finalParsed = JSON.parse(finalRaw); } catch(_) {}

        if (finalParsed && (finalParsed.status_code === 0 || finalParsed.status_code === '0')) {
          return JSON.stringify({ success: true, status_code: 0, message: 'ok (same-origin)', raw: finalRaw });
        }

        const errCode = finalParsed ? (finalParsed.status_code ?? -1) : finalResp.status;
        const errMsg = finalParsed ? (finalParsed.status_msg ?? finalParsed.error ?? 'Unknown error') : ('HTTP ' + finalResp.status);

        return JSON.stringify({
          success: false,
          status_code: errCode,
          message: errMsg,
          raw: finalRaw
        });
      } catch (e) {
        return JSON.stringify({ success: false, status_code: -1, message: e.toString(), raw: '' });
      }
    ''';

    final asyncResult = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        'deleteEndpoint': remoteConfig.deleteEndpoint,
        'aid': remoteConfig.aid,
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

  // ─── 5. MASS UN-LIKE (BỎ THÍCH VIDEO) ─────────────────────────────────────
  Future<DeleteResult> unlikeVideo({required String awemeId}) async {
    const functionBody = r'''
      try {
        const getNativeFetch = () => {
          try {
            let f = document.getElementById('__tt_clean_frame__');
            if (!f) {
              f = document.createElement('iframe');
              f.id = '__tt_clean_frame__';
              f.style.display = 'none';
              document.body.appendChild(f);
            }
            if (f.contentWindow && f.contentWindow.fetch) {
              return f.contentWindow.fetch.bind(f.contentWindow);
            }
          } catch (_) {}
          return window.fetch.bind(window);
        };

        const nativeFetch = getNativeFetch();

        // 1. Get dynamic CSRF via cookie & handshake
        let csrf = '';
        const m = document.cookie.match(/(?:^|;\s*)(?:tt_csrf_token|csrf_token|passport_csrf_token)=([^;]+)/);
        if (m) csrf = decodeURIComponent(m[1]);

        const primaryUrl = 'https://www.tiktok.com/api/commit/item/digg/?aid=' + String(aid);
        try {
          const pre = await nativeFetch(primaryUrl, {
            method: 'GET',
            credentials: 'include',
            headers: {
              'X-Secsdk-Csrf-Request': '1',
              'X-Secsdk-Csrf-Version': '1.2.8'
            }
          });
          const wareToken = pre.headers.get('x-ware-csrf-token') || pre.headers.get('X-Ware-Csrf-Token');
          if (wareToken) {
            const parts = wareToken.split(',');
            csrf = parts.length > 1 ? parts[1].trim() : parts[0].trim();
          }
        } catch (_) {}

        const buildHeaders = (contentType) => {
          const h = {
            'Accept': 'application/json, text/plain, */*'
          };
          if (contentType) h['Content-Type'] = contentType;
          if (csrf) {
            h['x-secsdk-csrf-token'] = csrf;
            h['x-secsdk-csrf-version'] = '1.2.8';
            h['x-tt-token'] = csrf;
          }
          return h;
        };

        const endpoints = [
          'https://www.tiktok.com/api/commit/item/digg/?aid=' + String(aid),
          'https://www.tiktok.com/aweme/v1/commit/item/digg/?aid=' + String(aid)
        ];

        let lastResult = null;

        for (const ep of endpoints) {
          // Attempt A: Form URL-encoded
          try {
            const resp = await nativeFetch(ep, {
              method: 'POST',
              credentials: 'include',
              headers: buildHeaders('application/x-www-form-urlencoded'),
              body: 'aweme_id=' + encodeURIComponent(awemeId) + '&type=0&channel=tiktok_web'
            });
            const raw = await resp.text();
            let parsed = null;
            try { parsed = JSON.parse(raw); } catch(_) {}
            if (parsed && (parsed.status_code === 0 || parsed.status_code === '0' || parsed.status_code === 200)) {
              return JSON.stringify({ success: true, status_code: 0, message: 'unliked (form)', raw: raw });
            }
            lastResult = { code: parsed ? parsed.status_code : resp.status, msg: parsed ? parsed.status_msg : raw, raw: raw };
          } catch (e) {
            lastResult = { code: -1, msg: e.toString(), raw: '' };
          }

          // Attempt B: JSON payload
          try {
            const resp = await nativeFetch(ep, {
              method: 'POST',
              credentials: 'include',
              headers: buildHeaders('application/json'),
              body: JSON.stringify({ aweme_id: String(awemeId), type: 0, channel: 'tiktok_web' })
            });
            const raw = await resp.text();
            let parsed = null;
            try { parsed = JSON.parse(raw); } catch(_) {}
            if (parsed && (parsed.status_code === 0 || parsed.status_code === '0' || parsed.status_code === 200)) {
              return JSON.stringify({ success: true, status_code: 0, message: 'unliked (json)', raw: raw });
            }
            lastResult = { code: parsed ? parsed.status_code : resp.status, msg: parsed ? parsed.status_msg : raw, raw: raw };
          } catch (_) {}
        }

        return JSON.stringify({
          success: false,
          status_code: lastResult ? lastResult.code : -1,
          message: lastResult ? lastResult.msg : 'Failed to unlike',
          raw: lastResult ? lastResult.raw : ''
        });
      } catch (e) {
        return JSON.stringify({ success: false, status_code: -1, message: e.toString(), raw: '' });
      }
    ''';

    final asyncResult = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        'aid': remoteConfig.aid,
        'awemeId': awemeId,
      },
    );

    if (asyncResult == null || asyncResult.value == null) {
      return DeleteResult(success: false, statusCode: -1, message: 'Null response', rawResponse: '');
    }

    final data = jsonDecode(asyncResult.value.toString()) as Map<String, dynamic>;
    return DeleteResult(
      success: data['success'] == true,
      statusCode: data['status_code'] as int? ?? -1,
      message: data['message']?.toString() ?? '',
      rawResponse: data['raw']?.toString() ?? '',
    );
  }

  // ─── 6. MASS UN-FOLLOW (BỎ THEO DÕI USER) ─────────────────────────────────
  Future<DeleteResult> unfollowUser({required String userId}) async {
    const functionBody = r'''
      try {
        const getNativeFetch = () => {
          try {
            let f = document.getElementById('__tt_clean_frame__');
            if (!f) {
              f = document.createElement('iframe');
              f.id = '__tt_clean_frame__';
              f.style.display = 'none';
              document.body.appendChild(f);
            }
            if (f.contentWindow && f.contentWindow.fetch) {
              return f.contentWindow.fetch.bind(f.contentWindow);
            }
          } catch (_) {}
          return window.fetch.bind(window);
        };

        const nativeFetch = getNativeFetch();

        // 1. Get dynamic CSRF via cookie & handshake
        let csrf = '';
        const m = document.cookie.match(/(?:^|;\s*)(?:tt_csrf_token|csrf_token|passport_csrf_token)=([^;]+)/);
        if (m) csrf = decodeURIComponent(m[1]);

        const primaryUrl = 'https://www.tiktok.com/api/commit/follow/user/?aid=' + String(aid);
        try {
          const pre = await nativeFetch(primaryUrl, {
            method: 'GET',
            credentials: 'include',
            headers: {
              'X-Secsdk-Csrf-Request': '1',
              'X-Secsdk-Csrf-Version': '1.2.8'
            }
          });
          const wareToken = pre.headers.get('x-ware-csrf-token') || pre.headers.get('X-Ware-Csrf-Token');
          if (wareToken) {
            const parts = wareToken.split(',');
            csrf = parts.length > 1 ? parts[1].trim() : parts[0].trim();
          }
        } catch (_) {}

        const buildHeaders = (contentType) => {
          const h = {
            'Accept': 'application/json, text/plain, */*'
          };
          if (contentType) h['Content-Type'] = contentType;
          if (csrf) {
            h['x-secsdk-csrf-token'] = csrf;
            h['x-secsdk-csrf-version'] = '1.2.8';
            h['x-tt-token'] = csrf;
          }
          return h;
        };

        const endpoints = [
          'https://www.tiktok.com/api/commit/follow/user/?aid=' + String(aid),
          'https://www.tiktok.com/aweme/v1/commit/follow/user/?aid=' + String(aid)
        ];

        let lastResult = null;

        for (const ep of endpoints) {
          // Attempt A: Form URL-encoded
          try {
            const resp = await nativeFetch(ep, {
              method: 'POST',
              credentials: 'include',
              headers: buildHeaders('application/x-www-form-urlencoded'),
              body: 'user_id=' + encodeURIComponent(userId) + '&type=0&channel=tiktok_web'
            });
            const raw = await resp.text();
            let parsed = null;
            try { parsed = JSON.parse(raw); } catch(_) {}
            if (parsed && (parsed.status_code === 0 || parsed.status_code === '0' || parsed.status_code === 200)) {
              return JSON.stringify({ success: true, status_code: 0, message: 'unfollowed (form)', raw: raw });
            }
            lastResult = { code: parsed ? parsed.status_code : resp.status, msg: parsed ? parsed.status_msg : raw, raw: raw };
          } catch (e) {
            lastResult = { code: -1, msg: e.toString(), raw: '' };
          }

          // Attempt B: JSON payload
          try {
            const resp = await nativeFetch(ep, {
              method: 'POST',
              credentials: 'include',
              headers: buildHeaders('application/json'),
              body: JSON.stringify({ user_id: String(userId), type: 0, channel: 'tiktok_web' })
            });
            const raw = await resp.text();
            let parsed = null;
            try { parsed = JSON.parse(raw); } catch(_) {}
            if (parsed && (parsed.status_code === 0 || parsed.status_code === '0' || parsed.status_code === 200)) {
              return JSON.stringify({ success: true, status_code: 0, message: 'unfollowed (json)', raw: raw });
            }
            lastResult = { code: parsed ? parsed.status_code : resp.status, msg: parsed ? parsed.status_msg : raw, raw: raw };
          } catch (_) {}
        }

        return JSON.stringify({
          success: false,
          status_code: lastResult ? lastResult.code : -1,
          message: lastResult ? lastResult.msg : 'Failed to unfollow',
          raw: lastResult ? lastResult.raw : ''
        });
      } catch (e) {
        return JSON.stringify({ success: false, status_code: -1, message: e.toString(), raw: '' });
      }
    ''';

    final asyncResult = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {
        'aid': remoteConfig.aid,
        'userId': userId,
      },
    );

    if (asyncResult == null || asyncResult.value == null) {
      return DeleteResult(success: false, statusCode: -1, message: 'Null response', rawResponse: '');
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
