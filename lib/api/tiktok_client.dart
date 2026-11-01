import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/remote_payload_config.dart';
import '../models/tiktok_follow_user.dart';
import '../models/tiktok_video.dart';
import 'scan_pagination.dart';
import 'following_pagination.dart';
import '../services/diagnostic_log.dart';

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

    final nextCursor = scanNextCursor(data, cursor);
    final hasMore = scanHasMore(data, videos.length, nextCursor != cursor && nextCursor > 0);

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
      throw Exception('Không nhận được dữ liệu Likes từ WebView: ${asyncResult?.error ?? "empty response"}');
    }

    final raw = asyncResult.value.toString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _checkScanResponse(data);
    final itemList = data['itemList'] as List<dynamic>? ?? [];
    final videos = itemList
        .map((item) => TikTokVideo.fromJson(item as Map<String, dynamic>, secUid: secUid))
        .toList();

    final nextCursor = scanNextCursor(data, cursor);
    final hasMore = scanHasMore(data, videos.length, nextCursor != cursor && nextCursor > 0);

    return ScanResult(videos: videos, nextCursor: nextCursor, hasMore: hasMore);
  }

  // ─── 3. FETCH FOLLOWING USERS (FOR MASS UN-FOLLOW) ────────────────────────
  Future<FollowingScanResult> fetchFollowingUsersBatch({required String cursor, String minCursor = '0', required String secUid}) async {
    const functionBody = r'''
      try {
        const endpoint = 'https://www.tiktok.com/api/user/list/';
        const params = new URLSearchParams();
        params.append('aid', String(aid));
        params.append('count', '30');
        params.append('minCursor', String(minCursor));
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
        'minCursor': minCursor,
        'secUid': secUid,
      },
    );

    if (asyncResult == null || asyncResult.value == null) {
      throw Exception('Không nhận được dữ liệu Following từ WebView: ${asyncResult?.error ?? "empty response"}');
    }

    final raw = asyncResult.value.toString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _checkScanResponse({...data, 'status_code': data['status_code'] ?? data['statusCode']});
    final userList = data['userList'] as List<dynamic>? ?? [];
    final users = userList
        .map((u) => TikTokFollowUser.fromJson(u as Map<String, dynamic>))
        .toList();

    final nextCursor = followingNextCursor(data, cursor);
    final nextMinCursor = followingNextMinCursor(data, minCursor);
    final changed = nextCursor != cursor || nextMinCursor != minCursor;
    final hasMore = followingHasMore(data, users.length, changed);
    DiagnosticLog.instance.record('scan.following', !changed && hasMore ? -2 : 0,
      details: {'scan_count': users.length, 'scan_has_more': hasMore,
        'scan_cursor_changed': changed,
        'scan_min_cursor_changed': nextMinCursor != minCursor,
        'scan_max_cursor_changed': nextCursor != cursor,
        for (final key in ['maxCursor', 'max_cursor', 'minCursor', 'min_cursor', 'nextCursor', 'next_cursor', 'cursor'])
          'scan_has_$key': data[key] != null});

    return FollowingScanResult(users: users, nextCursor: nextCursor, nextMinCursor: nextMinCursor, hasMore: hasMore);
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
      statusCode: int.tryParse(data['status_code']?.toString() ?? '') ?? -1,
      message: data['message']?.toString() ?? '',
      rawResponse: data['raw']?.toString() ?? '',
    );
  }

  Future<DeleteResult> unlikeVideo({required String awemeId, String author = ''}) =>
      _commitWebAction('/api/commit/item/digg/', {'aweme_id': awemeId, 'type': '0', '_author': author});

  Future<DeleteResult> unfollowUser({required String userId, String secUid = ''}) =>
      _commitWebAction('/api/commit/follow/user/', {
        'user_id': userId, 'sec_user_id': secUid, 'type': '0',
        'action_type': '0', 'channel_id': '0', 'from': '18',
        'fromWeb': '1', 'from_pre': '0',
      });

  Future<DeleteResult> _commitWebAction(String path, Map<String, String> params) async {
    final watch = Stopwatch()..start();
    final action = path.contains('digg') ? 'unlike' : 'unfollow';
    DiagnosticLog.instance.record('$action.start', 0);
    try {
      final result = await _performWebAction(path, params);
      Map<String, dynamic> details = {};
      try { details = Map<String, dynamic>.from(jsonDecode(result.rawResponse) as Map); } catch (_) {}
      DiagnosticLog.instance.record(action, result.statusCode,
          details: {...details, 'elapsed_ms': watch.elapsedMilliseconds});
      return result;
    } catch (_) {
      DiagnosticLog.instance.record(action, -1, details: {'elapsed_ms': watch.elapsedMilliseconds});
      rethrow;
    }
  }

  Future<DeleteResult> _performWebAction(String path, Map<String, String> params) async {
    const functionBody = r'''
      const failure = (code, message, detail = {}) =>
        JSON.stringify({success: false, status_code: code, message, raw: JSON.stringify(detail)});
      try {
        if (location.origin !== 'https://www.tiktok.com') {
          return failure(401, 'Mở trang TikTok chính thức và đăng nhập trước.');
        }
        // Read current page state; never substitute passport/SecSDK tokens.
        const candidates = [
          window['__$UNIVERSAL_DATA$__'],
          window['__UNIVERSAL_DATA_FOR_REHYDRATION__']
        ];
        try {
          candidates.push(JSON.parse(document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.textContent || '{}'));
        } catch (_) {}
        const contexts = candidates.map(x => x?.__DEFAULT_SCOPE__?.['webapp.app-context']).filter(Boolean);
        const app = contexts.find(x => x.csrfToken) || {};
        if (!app.csrfToken) {
          return failure(10402, 'Trang hiện tại thiếu CSRF web. Tải lại TikTok Web sau khi đăng nhập.');
        }
        const url = new URL(path, location.origin);
        for (const [key, value] of Object.entries(params)) {
          if (value !== '' && !key.startsWith('_')) url.searchParams.set(key, String(value));
        }
        url.searchParams.set('aid', String(aid));
        url.searchParams.set('app_name', 'tiktok_web');
        url.searchParams.set('device_platform', 'web_pc');
        url.searchParams.set('channel', 'tiktok_web');
        for (const [key, value] of Object.entries({
          device_id: app.wid, odinId: app.odinId, WebIdLastTime: app.webIdCreatedTime
        })) {
          if (value != null && value !== '') url.searchParams.set(key, String(value));
        }
        const language = navigator.language || 'en';
        url.searchParams.set('app_language', language.split('-')[0]);
        url.searchParams.set('browser_language', language);
        url.searchParams.set('browser_platform', navigator.platform || '');
        url.searchParams.set('browser_version', navigator.userAgent || '');
        // Use the page SDK once; do not replay ambiguous writes on guessed endpoints.
        const abort = new AbortController();
        const timer = setTimeout(() => abort.abort(), 20000);
        try {
          const response = await window.fetch(url.toString(), {
            method: 'POST', credentials: 'include', body: '', signal: abort.signal,
            headers: {'tt-csrf-token': app.csrfToken,
              'Content-Type': 'application/x-www-form-urlencoded'}
          });
          const raw = await response.text();
          const detail = {
            http_status: response.status, redirected: response.redirected,
            path: new URL(response.url || url.toString()).pathname,
            content_type: response.headers.get('content-type'),
            response_length: raw.length,
            csrf_present: Boolean(app.csrfToken),
            response_kind: raw.trim().length === 0 ? 'empty' : raw.trim().startsWith('<') ? 'html' : 'text',
            login_redirect: /\/login(?:\/|\?|$)/.test(response.url || ''),
            verification_hint: /captcha|verifycenter|verify-center/i.test(raw)
          };
          let data;
          try { data = JSON.parse(raw); } catch (_) {
            // A blank 200 is ambiguous. Read state once; never replay the POST.
            if (response.ok && !raw.trim() && path.includes('/item/digg/') && params._author) {
              detail.readback_attempted = true;
              detail.readback_confirmed = false;
              try {
                const profileId = user => String(user?.uid || user?.id || '');
                const expectedUser = profileId(app.user);
                const page = await window.fetch(location.origin + '/@' + encodeURIComponent(params._author) +
                  '/video/' + encodeURIComponent(params.aweme_id),
                  {credentials: 'include', signal: abort.signal, cache: 'no-store'});
                const html = await page.text();
                detail.readback_http_status = page.status;
                detail.readback_response_length = html.length;
                detail.readback_redirected = Boolean(page.redirected);
                detail.readback_verification_hint = /captcha|verifycenter|verify-center/i.test(html);
                const parsedPage = new DOMParser().parseFromString(html, 'text/html');
                const hydrationText = parsedPage.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.textContent;
                detail.readback_hydration_present = Boolean(hydrationText);
                const hydration = JSON.parse(hydrationText || '{}');
                const scope = hydration.__DEFAULT_SCOPE__ || {};
                const video = scope['webapp.video-detail']?.itemInfo?.itemStruct;
                const sameSession = expectedUser && profileId(scope['webapp.app-context']?.user) === expectedUser;
                detail.readback_viewer_present = Boolean(expectedUser);
                detail.readback_same_session = Boolean(sameSession);
                detail.readback_video_present = Boolean(video);
                detail.readback_video_matches = Boolean(video && String(video.id) === String(params.aweme_id));
                detail.readback_liked_present = typeof video?.digged === 'boolean';
                if (page.ok && sameSession && String(video?.id) === String(params.aweme_id) && typeof video.digged === 'boolean') {
                  detail.readback_confirmed = true;
                  detail.readback_liked = video.digged;
                  if (!video.digged) return JSON.stringify({success: true, status_code: 0,
                    message: 'Đã xác nhận video không còn được thích.', raw: JSON.stringify(detail)});
                }
              } catch (_) { detail.readback_exception = true; }
            }
            return failure(response.ok ? -2 : response.status,
              'TikTok chưa xác nhận kết quả. Mở tab Log để xem chi tiết; kiểm tra video trước khi thử lại.', detail);
          }
          if (!response.ok) return failure(response.status, 'TikTok HTTP ' + response.status, detail);
          detail.response_kind = 'json';
          const code = data && data.status_code;
          if (code === 0 || code === '0') {
            return JSON.stringify({success: true, status_code: 0, message: 'ok', raw: JSON.stringify(detail)});
          }
          return failure(Number.isFinite(Number(code)) && code != null ? Number(code) : -2,
            String(data?.status_msg || data?.message || 'Thiếu mã xác nhận từ TikTok'), detail);
        } finally { clearTimeout(timer); }
      } catch (e) {
        return failure(-1, e.name === 'AbortError'
          ? 'Request quá hạn; chưa xác nhận được kết quả. Kiểm tra trên TikTok trước khi thử lại.'
          : String(e));
      }
    ''';
    final result = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {'path': path, 'params': params, 'aid': remoteConfig.aid},
    );
    if (result == null || result.error != null || result.value == null) {
      return DeleteResult(success: false, statusCode: -1,
          message: 'WebView chưa trả kết quả: ${result?.error ?? "empty response"}', rawResponse: '');
    }
    try {
      final data = jsonDecode(result.value.toString()) as Map<String, dynamic>;
      return DeleteResult(success: data['success'] == true,
          statusCode: int.tryParse(data['status_code']?.toString() ?? '') ?? -1,
          message: data['message']?.toString() ?? '',
          rawResponse: data['raw']?.toString() ?? '');
    } catch (_) {
      return DeleteResult(success: false, statusCode: -2,
          message: 'WebView trả dữ liệu không hợp lệ.', rawResponse: '');
    }
  }

  static void _checkScanResponse(Map<String, dynamic> data) {
    final code = int.tryParse(data['status_code']?.toString() ?? '');
    if (code != 0) {
      throw Exception('TikTok scan error: ${data['status_code'] ?? "missing status"} - '
          '${data['status_msg'] ?? data['error'] ?? "Invalid response"}');
    }
  }
}
