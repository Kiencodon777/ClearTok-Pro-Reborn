import 'dart:async';
import 'dart:convert';
import 'tiktok_mutation_transport.dart';
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
      uniqueId:
          json['uniqueId']?.toString() ?? json['unique_id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatarThumb:
          json['avatarThumb']?.toString() ??
          json['avatar_thumb']?.toString() ??
          '',
      secUid: json['secUid']?.toString() ?? json['sec_uid']?.toString() ?? '',
    );
  }
}

class ScanResult {
  final List<TikTokVideo> videos;
  final int nextCursor;
  final bool hasMore;

  ScanResult({
    required this.videos,
    required this.nextCursor,
    required this.hasMore,
  });
}

class MutationCancelled implements Exception {}

class MutationToken {
  bool cancelled = false;
  final _listeners = <void Function()>{};

  void check() {
    if (cancelled) throw MutationCancelled();
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }

  void addListener(void Function() listener) {
    if (cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);

  Future<T> wait<T>(Future<T> work) async {
    final stopped = Completer<T>();
    void interrupt() {
      if (!stopped.isCompleted) stopped.completeError(MutationCancelled());
    }

    addListener(interrupt);
    try {
      final value = await Future.any([work, stopped.future]);
      check();
      return value;
    } finally {
      removeListener(interrupt);
    }
  }

  Future<void> delay(Duration duration) async {
    check();
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    try {
      await wait(done.future);
    } finally {
      timer.cancel();
    }
  }
}

class DeleteResult {
  final bool success;
  final int statusCode;
  final String message;
  final String rawResponse;
  final bool confirmedUnchanged;

  DeleteResult({
    required this.success,
    required this.statusCode,
    required this.message,
    required this.rawResponse,
    this.confirmedUnchanged = false,
  });
}

class TikTokClient {
  final InAppWebViewController webViewController;
  final RemotePayloadConfig remoteConfig;

  TikTokClient({required this.webViewController, required this.remoteConfig});

  Future<String?> getCookie(String name) async {
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(
        url: WebUri('https://www.tiktok.com'),
      );
      for (final c in cookies) {
        if (c.name == name &&
            c.value != null &&
            c.value.toString().isNotEmpty) {
          return c.value.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ensures the WebView is on a main TikTok Desktop page (not stuck on `/login`)
  /// so `webmssdk.js` and `__UNIVERSAL_DATA_FOR_REHYDRATION__` are active.
  static const String mainWorldBridgeJs =
      TikTokMutationTransport.mainWorldBridgeJs;

  Future<void> ensureMainWorldBridge() async {
    try {
      await webViewController.evaluateJavascript(source: mainWorldBridgeJs);
    } catch (_) {}
  }

  Future<void> ensureActiveWebappPage({
    String? uniqueId,
    MutationToken? token,
  }) async {
    try {
      final url = (await webViewController.getUrl())?.toString() ?? '';
      if (url.isEmpty ||
          url.contains('/login') ||
          !url.contains('tiktok.com')) {
        final target = (uniqueId != null && uniqueId.isNotEmpty)
            ? 'https://www.tiktok.com/@$uniqueId'
            : 'https://www.tiktok.com/foryou';
        token?.check();
        await webViewController.loadUrl(
          urlRequest: URLRequest(url: WebUri(target)),
        );
        await (token ?? MutationToken()).delay(
          const Duration(milliseconds: 1600),
        );
      }
    } catch (_) {}
  }

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

      final asyncResult = await webViewController.callAsyncJavaScript(
        functionBody: functionBody,
      );
      if (asyncResult == null || asyncResult.value == null) return null;

      final data =
          jsonDecode(asyncResult.value.toString()) as Map<String, dynamic>;
      if (data['status'] == 'ok' && data['user'] != null) {
        return TikTokUserProfile.fromJson(data['user'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  // ─── 1. FETCH REPOSTS ─────────────────────────────────────────────────────
  Future<ScanResult> fetchRepostBatch({
    required int cursor,
    required String secUid,
  }) async {
    if (cursor == 0) {
      await ensureActiveWebappPage();
    }
    const functionBody = r'''
      try {
        const endpoint = scanEndpoint;
        let app = {};
        try {
          const rawHydration = document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.textContent;
          if (rawHydration) {
            app = JSON.parse(rawHydration)?.__DEFAULT_SCOPE__?.['webapp.app-context'] || {};
          }
        } catch (_) {}

        const params = new URLSearchParams();
        params.append('aid', String(aid));
        params.append('app_name', 'tiktok_web');
        params.append('device_platform', 'web_pc');
        params.append('channel', 'tiktok_web');
        params.append('count', String(count));
        params.append('cursor', String(cursor));
        params.append('secUid', String(secUid));
        params.append('coverFormat', '2');
        params.append('needPinnedItemIds', 'true');
        params.append('post_item_list_request_type', '0');
        if (app.wid) params.append('device_id', String(app.wid));
        if (app.odinId) params.append('odinId', String(app.odinId));

        const targetUrl = endpoint + '?' + params.toString();
        const abort = new AbortController();
        const timer = setTimeout(() => abort.abort(), 20000);
        try {
          const response = await fetch(targetUrl, {
            method: 'GET',
            credentials: 'include',
            signal: abort.signal,
            headers: {
              'Accept': 'application/json, text/plain, */*'
            }
          });

          let raw = await response.text();
          if (!raw || !raw.trim()) {
            raw = await new Promise((resolve) => {
              try {
                const xhr = new XMLHttpRequest();
                xhr.open('GET', targetUrl, true);
                xhr.timeout = 15000;
                xhr.withCredentials = true;
                xhr.setRequestHeader('Accept', 'application/json, text/plain, */*');
                xhr.onload = () => resolve(xhr.responseText || '');
                xhr.onerror = () => resolve('');
                xhr.ontimeout = () => resolve('');
                xhr.send();
              } catch (_) {
                resolve('');
              }
            });
          }
          if (!raw || !raw.trim()) {
            return JSON.stringify({
              status_code: -2,
              error: 'HTTP ' + response.status + ' empty response (chưa xác nhận được danh sách)'
            });
          }
          return raw;
        } finally {
          clearTimeout(timer);
        }
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
    if (rawResult == null || rawResult.toString().trim().isEmpty) {
      return ScanResult(videos: const [], nextCursor: 0, hasMore: false);
    }

    final data = jsonDecode(rawResult.toString()) as Map<String, dynamic>;
    if (data['status_code'] != 0 && data['status_code'] != null) {
      throw Exception(
        'TikTok Error: ${data['status_code']} - ${data['error'] ?? data['status_msg'] ?? 'API rejected'}',
      );
    }

    final itemList = data['itemList'] as List<dynamic>? ?? [];
    final videos = itemList
        .map(
          (item) => TikTokVideo.fromJson(
            item as Map<String, dynamic>,
            secUid: secUid,
          ),
        )
        .toList();

    final nextCursor = scanNextCursor(data, cursor);
    final hasMore = scanHasMore(
      data,
      videos.length,
      nextCursor != cursor && nextCursor > 0,
    );

    return ScanResult(videos: videos, nextCursor: nextCursor, hasMore: hasMore);
  }

  // ─── 2. FETCH LIKED VIDEOS (FOR MASS UN-LIKE) ─────────────────────────────
  Future<ScanResult> fetchLikedVideosBatch({
    required int cursor,
    required String secUid,
  }) async {
    if (cursor == 0) {
      await ensureActiveWebappPage();
    }
    const functionBody = r'''
      try {
        const endpoint = 'https://www.tiktok.com/api/favorite/item_list/';
        const params = new URLSearchParams();
        params.append('aid', String(aid));
        params.append('app_name', 'tiktok_web');
        params.append('device_platform', 'web_pc');
        params.append('channel', 'tiktok_web');
        params.append('count', '30');
        params.append('cursor', String(cursor));
        params.append('secUid', String(secUid));
        params.append('coverFormat', '2');

        const abort = new AbortController();
        const timer = setTimeout(() => abort.abort(), 20000);
        try {
          const response = await fetch(endpoint + '?' + params.toString(), {
            method: 'GET',
            credentials: 'include',
            signal: abort.signal,
            headers: { 'Accept': 'application/json, text/plain, */*' }
          });

          const raw = await response.text();
          if (!raw || !raw.trim()) {
            return JSON.stringify({
              status_code: -2,
              error: 'HTTP ' + response.status + ' empty response (chưa xác nhận được danh sách)'
            });
          }
          return raw;
        } finally {
          clearTimeout(timer);
        }
      } catch (e) {
        return JSON.stringify({status_code: -1, error: e.toString()});
      }
    ''';

    final asyncResult = await webViewController.callAsyncJavaScript(
      functionBody: functionBody,
      arguments: {'aid': remoteConfig.aid, 'cursor': cursor, 'secUid': secUid},
    );

    if (asyncResult == null || asyncResult.value == null) {
      throw Exception(
        'Không nhận được dữ liệu Likes từ WebView: ${asyncResult?.error ?? "empty response"}',
      );
    }

    final raw = asyncResult.value.toString();
    if (raw.trim().isEmpty) {
      return ScanResult(videos: const [], nextCursor: 0, hasMore: false);
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _checkScanResponse(data);
    final itemList = data['itemList'] as List<dynamic>? ?? [];
    final videos = itemList
        .map(
          (item) => TikTokVideo.fromJson(
            item as Map<String, dynamic>,
            secUid: secUid,
          ),
        )
        .toList();

    final nextCursor = scanNextCursor(data, cursor);
    final hasMore = scanHasMore(
      data,
      videos.length,
      nextCursor != cursor && nextCursor > 0,
    );

    return ScanResult(videos: videos, nextCursor: nextCursor, hasMore: hasMore);
  }

  // ─── 3. FETCH FOLLOWING USERS (FOR MASS UN-FOLLOW) ────────────────────────
  Future<FollowingScanResult> fetchFollowingUsersBatch({
    required String cursor,
    String minCursor = '0',
    required String secUid,
  }) async {
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
        if (!raw || !raw.trim()) {
          return JSON.stringify({
            status_code: -2,
            error: 'HTTP ' + (response.status ?? 200) + ' empty response (chưa xác nhận được danh sách)'
          });
        }
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
      throw Exception(
        'Không nhận được dữ liệu Following từ WebView: ${asyncResult?.error ?? "empty response"}',
      );
    }

    final raw = asyncResult.value.toString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _checkScanResponse({
      ...data,
      'status_code': data['status_code'] ?? data['statusCode'],
    });
    final userList = data['userList'] as List<dynamic>? ?? [];
    final users = userList
        .map((u) => TikTokFollowUser.fromJson(u as Map<String, dynamic>))
        .toList();

    final nextCursor = followingNextCursor(data, cursor);
    final nextMinCursor = followingNextMinCursor(data, minCursor);
    final changed = nextCursor != cursor || nextMinCursor != minCursor;
    final hasMore = followingHasMore(data, users.length, changed);
    DiagnosticLog.instance.record(
      'scan.following',
      !changed && hasMore ? -2 : 0,
      details: {
        'scan_count': users.length,
        'scan_has_more': hasMore,
        'scan_cursor_changed': changed,
        'scan_min_cursor_changed': nextMinCursor != minCursor,
        'scan_max_cursor_changed': nextCursor != cursor,
        for (final key in [
          'maxCursor',
          'max_cursor',
          'minCursor',
          'min_cursor',
          'nextCursor',
          'next_cursor',
          'cursor',
        ])
          'scan_has_$key': data[key] != null,
      },
    );

    return FollowingScanResult(
      users: users,
      nextCursor: nextCursor,
      nextMinCursor: nextMinCursor,
      hasMore: hasMore,
    );
  }

  // ─── 4. DELETE SINGLE REPOST ──────────────────────────────────────────────
  Future<DeleteResult> deleteSingleRepost({
    required String itemId,
    MutationToken? token,
  }) => _commitWebAction('/tiktok/v1/upvote/delete', {
    'item_id': itemId,
    'type': '1',
  }, token);

  Future<DeleteResult> unlikeVideo({
    required String awemeId,
    String author = '',
    MutationToken? token,
  }) => _commitWebAction('/api/commit/item/digg/', {
    'aweme_id': awemeId,
    'type': '0',
    '_author': author,
  }, token);

  Future<DeleteResult> unfollowUser({
    required String userId,
    String secUid = '',
    MutationToken? token,
  }) => _commitWebAction('/api/commit/follow/user/', {
    'user_id': userId,
    'sec_user_id': secUid,
    'type': '0',
    'action_type': '0',
    'channel_id': '0',
    'from': '18',
    'fromWeb': '1',
    'from_pre': '0',
  }, token);

  Future<DeleteResult> _commitWebAction(
    String path,
    Map<String, String> params,
    MutationToken? cancellation,
  ) async {
    final watch = Stopwatch()..start();
    final action = path.contains('digg') ? 'unlike' : 'unfollow';
    DiagnosticLog.instance.record('$action.start', 0);
    try {
      final token = cancellation ?? MutationToken();
      token.check();
      await token.wait(ensureActiveWebappPage(token: token));
      token.check();
      final result = await TikTokMutationTransport(
        webViewController,
      ).perform(path, params, remoteConfig.aid, token);
      Map<String, dynamic> details = {};
      try {
        details = Map<String, dynamic>.from(
          jsonDecode(result.rawResponse) as Map,
        );
      } catch (_) {}
      DiagnosticLog.instance.record(
        action,
        result.statusCode,
        details: {...details, 'elapsed_ms': watch.elapsedMilliseconds},
      );
      return result;
    } catch (_) {
      DiagnosticLog.instance.record(
        action,
        -1,
        details: {'elapsed_ms': watch.elapsedMilliseconds},
      );
      rethrow;
    }
  }

  static void _checkScanResponse(Map<String, dynamic> data) {
    final code = int.tryParse(data['status_code']?.toString() ?? '');
    if (code != 0) {
      throw Exception(
        'TikTok scan error: ${data['status_code'] ?? "missing status"} - '
        '${data['status_msg'] ?? data['error'] ?? "Invalid response"}',
      );
    }
  }
}
