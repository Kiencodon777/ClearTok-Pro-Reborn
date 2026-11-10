import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'tiktok_client.dart' show DeleteResult, MutationToken, MutationCancelled;

class TikTokMutationTransport {
  TikTokMutationTransport(this.controller);
  final InAppWebViewController controller;
  static int _sequence = 0;
  static const String mainWorldBridgeJs = r'''
(function() {
  if (location.origin !== 'https://www.tiktok.com') return;
  if (window.__lapinMwInstalled && document.getElementById('__lapin_mw_bus')) {
    if (document.documentElement) document.documentElement.setAttribute('data-lapin-mw', '1');
    return;
  }
  window.__lapinMwInstalled = true;
  var bus = document.getElementById('__lapin_mw_bus');
  if (!bus) {
    bus = document.createElement('div');
    bus.id = '__lapin_mw_bus';
    bus.style.display = 'none';
    (document.documentElement || document.body).appendChild(bus);
  }
  if (document.documentElement) document.documentElement.setAttribute('data-lapin-mw', '1');

  function getCookie(name) {
    var m = document.cookie.match(new RegExp('(?:^|;\\s*)' + name + '=([^;]+)'));
    return m ? decodeURIComponent(m[1]) : '';
  }

  async function ensureSecToken(targetUrl, signal) {
    if (window.__lapinSecToken) return window.__lapinSecToken;
    var hsMethods = ['HEAD', 'GET'];
    for (var i = 0; i < hsMethods.length; i++) {
      if (signal.aborted) return '';
      try {
        var hs = await window.fetch(targetUrl, {
          method: hsMethods[i], signal: signal,
          credentials: 'include',
          headers: {
            'x-secsdk-csrf-request': '1',
            'x-secsdk-csrf-version': '1.2.8',
            'x-secsdk-csrf-token': 'DOWNGRADE'
          }
        });
        var ware = hs.headers.get('x-ware-csrf-token') || hs.headers.get('X-Ware-Csrf-Token') || '';
        if (ware.indexOf(',') !== -1) {
          var tok = (ware.split(',')[1] || '').trim();
          if (tok) {
            window.__lapinSecToken = tok;
            return tok;
          }
        }
      } catch (_) {}
    }
    return '';
  }

  function runXhr(method, targetUrl, headers, bodyStr, signal, node) {
    return new Promise(function(resolve) {
      try {
        var xhr = new XMLHttpRequest();
        xhr.open(method, targetUrl, true);
        xhr.timeout = 15000;
        xhr.withCredentials = true;
        var hdrs = headers || {};
        for (var k in hdrs) {
          if (Object.prototype.hasOwnProperty.call(hdrs, k) && hdrs[k]) {
            xhr.setRequestHeader(k, hdrs[k]);
          }
        }
        xhr.onload = function() {
          var ware = '';
          try { ware = xhr.getResponseHeader('x-ware-csrf-token') || ''; } catch (_) {}
          if (ware && ware.indexOf(',') !== -1) {
            var nextTok = (ware.split(',')[1] || '').trim();
            if (nextTok) window.__lapinSecToken = nextTok;
          }
          resolve({
            ok: xhr.status >= 200 && xhr.status < 300,
            status: xhr.status || 200,
            url: xhr.responseURL || targetUrl,
            redirected: Boolean(xhr.responseURL && xhr.responseURL !== targetUrl),
            contentType: (function() { try { return xhr.getResponseHeader('content-type') || ''; } catch (_) { return ''; } })(),
            raw: xhr.responseText || ''
          });
        };
        xhr.onerror = function() { resolve({ ok: false, status: 0, url: targetUrl, redirected: false, contentType: '', raw: '' }); };
        xhr.ontimeout = function() { resolve({ ok: false, status: 0, url: targetUrl, redirected: false, contentType: '', raw: '' }); };
        xhr.onabort = function() { resolve({ok:false, status:0, raw:''}); };
        if (signal.aborted) { xhr.onabort(); return; }
        signal.addEventListener('abort', function() { xhr.abort(); }, {once:true});
        node.setAttribute('data-sent', '1');
        xhr.send(bodyStr != null ? bodyStr : '');
      } catch (e) {
        resolve({ ok: false, status: 0, url: targetUrl, redirected: false, contentType: '', raw: '' });
      }
    });
  }

  async function handleNode(node) {
    node.setAttribute('data-state', 'running');
    var req = JSON.parse(node.getAttribute('data-req') || '{}');
    var abort = window.__lapinRequests?.get(req.requestId);
    if (!abort || abort.signal.aborted) return;
    var deadline = setTimeout(function() { abort.abort(); }, 18000);
    try {
      var targetUrl = req.url;
      var checked = new URL(targetUrl);
      if (checked.origin !== location.origin || !['/api/commit/item/digg/', '/api/commit/follow/user/', '/tiktok/v1/upvote/delete'].includes(checked.pathname)) throw new Error('Blocked bridge request');
      var method = req.method || 'POST';
      var csrf = req.csrf || getCookie('tt_csrf_token') || getCookie('csrf_token') || getCookie('passport_csrf_token');
      var msToken = getCookie('msToken');
      if (msToken && targetUrl.indexOf('msToken=') === -1) {
        var u = new URL(targetUrl, location.origin);
        u.searchParams.set('msToken', msToken);
        targetUrl = u.toString();
      }
      var headers = Object.assign({}, req.headers || {});
      if (csrf) headers['tt-csrf-token'] = csrf;
      if (method === 'POST') {
        var secToken = await ensureSecToken(targetUrl, abort.signal);
        if (secToken) headers['x-secsdk-csrf-token'] = secToken;
      }

      var parsed = new URL(targetUrl);
      if (parsed.origin !== location.origin || !['/api/commit/item/digg/', '/api/commit/follow/user/', '/tiktok/v1/upvote/delete'].includes(parsed.pathname) || method !== 'POST') throw new Error('Blocked bridge request');
      if (abort.signal.aborted || node.getAttribute('data-state') !== 'running') { clearTimeout(deadline); return; }
      var res = await runXhr(method, targetUrl, headers, req.body || '', abort.signal, node);
      node.setAttribute('data-res', JSON.stringify(res));
    } catch (err) {
      node.setAttribute('data-res', JSON.stringify({
        ok: false, status: -1, url: '', redirected: false, contentType: '', raw: '', error: String(err)
      }));
    }
    clearTimeout(deadline);
    node.setAttribute('data-state', 'done');
    document.dispatchEvent(new Event('__lapin_mw_res'));
  }

  function scanBus() {
    var nodes = bus.querySelectorAll('[data-state="pending"]');
    for (var i = 0; i < nodes.length; i++) {
      handleNode(nodes[i]);
    }
  }

  document.addEventListener('__lapin_mw_req', scanBus);
  var obs = new MutationObserver(scanBus);
  obs.observe(bus, { childList: true, attributes: true, subtree: true });
})();
''';

  Future<DeleteResult> perform(
    String path,
    Map<String, String> params,
    int aid,
    MutationToken token,
  ) async {
    token.check();
    final requestId = ++_sequence;
    // Register before starting the async script so a queued call cannot miss stop.
    await controller.evaluateJavascript(source: mainWorldBridgeJs);
    token.check();
    await controller.evaluateJavascript(
      source:
          """
      (window.__lapinRequests ??= new Map()).set($requestId, new AbortController()); true;
    """,
    );
    Future<void> abortRequest() async {
      try {
        await controller.evaluateJavascript(
          source: 'window.__lapinRequests?.get($requestId)?.abort();',
        );
      } catch (_) {}
    }

    token.addListener(abortRequest);
    const functionBody = r'''
      const failure = (code, message, detail = {}) =>
        JSON.stringify({success: false, status_code: code, message, raw: JSON.stringify(detail)});
      try {
        if (location.origin !== 'https://www.tiktok.com') {
          return failure(401, 'Mở trang TikTok chính thức và đăng nhập trước.', {unsent:true});
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
          return failure(10402, 'Trang hiện tại thiếu CSRF web. Tải lại TikTok Web sau khi đăng nhập.', {unsent:true});
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
        const registry = window.__lapinRequests ??= new Map();
        const webId = 'web-' + (window.__lapinWebId = (window.__lapinWebId || 0) + 1);
        const key = typeof requestId === 'undefined' ? webId : requestId;
        // Web builds call this body directly without a mobile cancellation handle.
        if (typeof requestId === 'undefined') registry.set(key, new AbortController());
        const abort = registry.get(key);
        if (!abort || abort.signal.aborted) return failure(-1, 'Cancelled', {unsent:true});
        const timer = setTimeout(() => abort.abort(), 20000);
        try {
          const bus = document.getElementById('__lapin_mw_bus');
          if (!bus) return failure(-2, 'Main-world bridge chưa sẵn sàng.', {unsent:true});
          const response = await new Promise(resolve => {
            const node = document.createElement('div');
            node.setAttribute('data-req', JSON.stringify({
              requestId: key, url: url.toString(), method: 'POST', csrf: app.csrfToken,
              headers: {'tt-csrf-token': app.csrfToken, 'Content-Type': path === '/tiktok/v1/upvote/delete' ? 'application/json' : 'application/x-www-form-urlencoded'},
              body: path === '/tiktok/v1/upvote/delete' ? JSON.stringify({item_id: params.item_id, type: 1}) : ''
            }));
            node.setAttribute('data-state', 'pending');
            let finished = false;
            let poll, timeout;
            const done = (expired = false) => {
              if (finished || (!expired && node.getAttribute('data-state') !== 'done')) return;
              finished = true;
              clearInterval(poll); clearTimeout(timeout);
              let result = {ok:false, status:0, raw:''};
              try { if (!expired) result = JSON.parse(node.getAttribute('data-res')); } catch (_) {}
              node.setAttribute('data-state', 'cancelled');
              result.sent = node.getAttribute('data-sent') === '1';
              abort.signal.removeEventListener('abort', interrupt);
              node.remove();
              resolve(result);
            };
            const interrupt = () => done(true);
            abort.signal.addEventListener('abort', interrupt, {once:true});
            poll = setInterval(done, 40);
            timeout = setTimeout(() => done(true), 20000);
            bus.appendChild(node);
            document.dispatchEvent(new Event('__lapin_mw_req'));
            done();
          });
          if (!response.sent) return failure(-1, 'Request chưa gửi.', {unsent:true});
          const raw = response.raw || '';
          const detail = {
            http_status: response.status, redirected: response.redirected,
            path: new URL(response.url || url.toString()).pathname,
            content_type: response.contentType,
            response_length: raw.length,
            csrf_present: Boolean(app.csrfToken),
            response_kind: raw.trim().length === 0 ? 'empty' : raw.trim().startsWith('<') ? 'html' : 'text',
            login_redirect: /\/login(?:\/|\?|$)/.test(response.url || ''),
            verification_hint: /captcha|verifycenter|verify-center/i.test(raw)
          };
          if (detail.login_redirect || new URL(response.url || url.toString()).origin !== location.origin) {
            return failure(401, 'Phiên TikTok cần đăng nhập lại.', detail);
          }
          if (detail.verification_hint) return failure(10402, 'TikTok yêu cầu xác minh.', detail);
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
                if (detail.readback_video_matches) detail.readback_verification_hint = false;
                detail.readback_liked_present = typeof video?.digged === 'boolean';
                if (page.ok && sameSession && String(video?.id) === String(params.aweme_id) && typeof video.digged === 'boolean') {
                  detail.readback_confirmed = true;
                  detail.readback_liked = video.digged;
                  if (!video.digged) return JSON.stringify({success: true, status_code: 0,
                    message: 'Đã xác nhận video không còn được thích.', raw: JSON.stringify(detail)});
                }
                // Fallback JSON readback via /api/item/detail/ when HTML is a 1499-byte SPA shell
                if (!abort.signal.aborted && expectedUser && !detail.readback_hydration_present) {
                  try {
                    const detailUrl = new URL('/api/item/detail/', location.origin);
                    detailUrl.searchParams.set('aid', String(aid));
                    detailUrl.searchParams.set('itemId', String(params.aweme_id));
                    detailUrl.searchParams.set('app_name', 'tiktok_web');
                    detailUrl.searchParams.set('device_platform', 'web_pc');
                    const itemResp = await window.fetch(detailUrl.toString(), {
                      credentials: 'include', signal: abort.signal, cache: 'no-store'
                    });
                    const itemJson = await itemResp.json();
                    const itemStruct = itemJson?.itemInfo?.itemStruct;
                    const live = JSON.parse(document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.textContent || '{}');
                    const liveUser = live.__DEFAULT_SCOPE__?.['webapp.app-context']?.user;
                    if (itemResp.ok && profileId(liveUser) === expectedUser && itemStruct && String(itemStruct.id) === String(params.aweme_id) && typeof itemStruct.digged === 'boolean') {
                      detail.readback_confirmed = true;
                      detail.readback_liked = itemStruct.digged;
                      if (!itemStruct.digged) {
                        return JSON.stringify({success: true, status_code: 0,
                          message: 'Đã xác nhận qua API video không còn được thích.', raw: JSON.stringify(detail)});
                      }
                    }
                  } catch (_) {}
                }
              } catch (_) { detail.readback_exception = true; }
            }
            if (detail.readback_confirmed && detail.readback_liked === true) {
              return failure(-3, 'Video vẫn đang được thích.', detail);
            }
            return failure(response.ok ? -2 : (response.status || -2),
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
        } finally { clearTimeout(timer); registry.delete(key); }
      } catch (e) {
        return failure(-1, e.name === 'AbortError'
          ? 'Request quá hạn; chưa xác nhận được kết quả. Kiểm tra trên TikTok trước khi thử lại.'
          : String(e));
      }
    ''';
    try {
      token.check();
      token.check();
      final result = await controller.callAsyncJavaScript(
        functionBody: functionBody,
        arguments: {
          'path': path,
          'params': params,
          'aid': aid,
          'requestId': requestId,
        },
      );
      try {
        if (result == null || result.error != null) {
          throw const FormatException();
        }
        final data =
            jsonDecode(result.value.toString()) as Map<String, dynamic>;
        final detail = jsonDecode(data['raw'] as String);
        final unsent = detail['unsent'] == true;
        if (token.cancelled && unsent) throw MutationCancelled();
        return DeleteResult(
          confirmedUnchanged:
              unsent ||
              data['status_code'] == -3 && detail['readback_liked'] == true,
          success: data['success'] == true,
          statusCode: int.tryParse(data['status_code'].toString()) ?? -2,
          message: data['message']?.toString() ?? '',
          rawResponse: data['raw']?.toString() ?? '',
        );
      } on MutationCancelled {
        rethrow;
      } catch (_) {
        return DeleteResult(
          success: false,
          statusCode: -2,
          message: 'Chưa xác minh được kết quả từ WebView.',
          rawResponse: '',
        );
      }
    } finally {
      token.removeListener(abortRequest);
      try {
        await controller.evaluateJavascript(
          source: 'window.__lapinRequests?.delete($requestId);',
        );
      } catch (_) {}
    }
  }
}
