import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/remote_payload_config.dart';
import '../models/tiktok_video.dart';

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

  Future<String?> getCookie(String name) async {
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: WebUri('https://www.tiktok.com'));
    for (var c in cookies) {
      if (c.name == name) return c.value;
    }
    return null;
  }

  Future<String> extractCsrfToken() async {
    final token = await getCookie('s_v_web_id') ?? await getCookie('ttwid') ?? '';
    return token;
  }

  Future<ScanResult> fetchRepostBatch({required int cursor, required String secUid}) async {
    final script = remoteConfig.buildScanScript(cursor: cursor, secUid: secUid);
    final rawResult = await webViewController.evaluateJavascript(source: script);
    
    if (rawResult == null) {
      throw Exception('Empty response from WebView context');
    }

    final data = jsonDecode(rawResult.toString()) as Map<String, dynamic>;
    if (data['status_code'] != 0 && data['status_code'] != null) {
      throw Exception('TikTok Error: ${data['status_code']} - ${data['error'] ?? 'API reject'}');
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
    final script = remoteConfig.buildDeleteScript(itemId: itemId, csrfToken: csrfToken);
    final rawResult = await webViewController.evaluateJavascript(source: script);

    if (rawResult == null) return false;
    final data = jsonDecode(rawResult.toString()) as Map<String, dynamic>;

    if (data['status_code'] == 0) {
      return true;
    } else if (data['status_code'] == 3002226 || data['status_code'] == 429) {
      throw Exception('RATE_LIMITED');
    } else {
      return false;
    }
  }
}
