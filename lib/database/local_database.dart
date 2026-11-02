import 'package:hive/hive.dart';
import '../models/tiktok_follow_user.dart';
import '../models/tiktok_video.dart';

class ProcessedHistoryItem {
  final String key;
  final String id;
  final String type; // 'repost', 'unlike', 'unfollow'
  final String authorUsername;
  final String authorNickname;
  final String description;
  final String coverUrl;
  final int diggCount;
  final int processedAt;

  const ProcessedHistoryItem({
    required this.key,
    required this.id,
    required this.type,
    required this.authorUsername,
    required this.authorNickname,
    required this.description,
    required this.coverUrl,
    required this.diggCount,
    required this.processedAt,
  });

  String get tiktokUrl {
    final cleanAuthor = authorUsername.replaceFirst(RegExp(r'^@'), '').trim();
    if (type == 'unfollow') {
      if (cleanAuthor.isNotEmpty && cleanAuthor != 'unknown') {
        return 'https://www.tiktok.com/@$cleanAuthor';
      }
      return 'https://www.tiktok.com/';
    }
    if (cleanAuthor.isNotEmpty && cleanAuthor != 'unknown') {
      return 'https://www.tiktok.com/@$cleanAuthor/video/$id';
    }
    return 'https://www.tiktok.com/video/$id';
  }
}

class LocalDatabase {
  static const String repostBoxName = 'reposts_box';
  static const String historyBoxName = 'history_box';
  static const String settingsBoxName = 'settings_box';
  static const String likesBoxName = 'likes_box';
  static const String followsBoxName = 'follows_box';

  Box? _repostBox;
  Box? _historyBox;
  Box? _settingsBox;
  Box? _likesBox;
  Box? _followsBox;

  Future<void> init() async {
    _repostBox = await Hive.openBox(repostBoxName);
    _historyBox = await Hive.openBox(historyBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
    _likesBox = await Hive.openBox(likesBoxName);
    _followsBox = await Hive.openBox(followsBoxName);
  }

  // ─── Reposts Management ───────────────────────────────────────────────────
  List<TikTokVideo> getAllReposts() {
    final box = _repostBox;
    if (box == null) return [];
    return box.values
        .map((e) => TikTokVideo.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveReposts(List<TikTokVideo> videos) async {
    final box = _repostBox;
    if (box == null) return;
    final map = {for (var v in videos) v.id: v.toMap()};
    await box.putAll(map);
  }

  Future<void> removeRepost(String videoId) async {
    final raw = _repostBox?.get(videoId);
    await _repostBox?.delete(videoId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw is Map) {
      final data = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      data['type'] = 'repost';
      data['processedAt'] = now;
      await _historyBox?.put('repost_$videoId', data);
    } else {
      await _historyBox?.put('repost_$videoId', now);
    }
  }

  bool isAlreadyDeleted(String videoId) {
    final box = _historyBox;
    if (box == null) return false;
    return box.containsKey('repost_$videoId') || box.containsKey(videoId);
  }

  // ─── Likes Management ─────────────────────────────────────────────────────
  List<TikTokVideo> getAllLikedVideos() {
    final box = _likesBox;
    if (box == null) return [];
    return box.values
        .map((e) => TikTokVideo.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveLikedVideos(List<TikTokVideo> videos) async {
    final box = _likesBox;
    if (box == null) return;
    final map = {for (var v in videos) v.id: v.toMap()};
    await box.putAll(map);
  }

  Future<void> removeLikedVideo(String videoId) async {
    final raw = _likesBox?.get(videoId);
    await _likesBox?.delete(videoId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw is Map) {
      final data = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      data['type'] = 'unlike';
      data['processedAt'] = now;
      await _historyBox?.put('like_$videoId', data);
    } else {
      await _historyBox?.put('like_$videoId', now);
    }
  }

  // ─── Follows Management ───────────────────────────────────────────────────
  List<TikTokFollowUser> getAllFollowing() {
    final box = _followsBox;
    if (box == null) return [];
    return box.values
        .map(
          (e) => TikTokFollowUser.fromMap(Map<dynamic, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> saveFollowing(List<TikTokFollowUser> users) async {
    final box = _followsBox;
    if (box == null) return;
    final map = {for (var u in users) u.id: u.toMap()};
    await box.putAll(map);
  }

  Future<void> removeFollowing(String userId) async {
    final raw = _followsBox?.get(userId);
    await _followsBox?.delete(userId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (raw is Map) {
      final data = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      data['type'] = 'unfollow';
      data['processedAt'] = now;
      await _historyBox?.put('follow_$userId', data);
    } else {
      await _historyBox?.put('follow_$userId', now);
    }
  }

  // ─── Separated Processed Counts & History ─────────────────────────────────
  int get totalDeletedCount => _historyBox?.length ?? 0;

  int get deletedRepostCount {
    final box = _historyBox;
    if (box == null) return totalDeletedCount;
    return box.keys.where((k) => k.toString().startsWith('repost_')).length;
  }

  int get deletedLikeCount {
    final box = _historyBox;
    if (box == null) return 0;
    return box.keys.where((k) => k.toString().startsWith('like_')).length;
  }

  int get deletedFollowCount {
    final box = _historyBox;
    if (box == null) return 0;
    return box.keys.where((k) => k.toString().startsWith('follow_')).length;
  }

  int deletedCountForHub(String hub) {
    if (_historyBox == null) return totalDeletedCount;
    switch (hub) {
      case 'repost':
        return deletedRepostCount;
      case 'unlike':
        return deletedLikeCount;
      case 'unfollow':
        return deletedFollowCount;
      default:
        return totalDeletedCount;
    }
  }

  List<ProcessedHistoryItem> getProcessedHistory({String? type}) {
    final box = _historyBox;
    if (box == null) return const [];
    final items = <ProcessedHistoryItem>[];
    for (final rawKey in box.keys) {
      final key = rawKey.toString();
      String itemType = 'repost';
      String itemId = key;
      if (key.startsWith('repost_')) {
        itemType = 'repost';
        itemId = key.substring('repost_'.length);
      } else if (key.startsWith('like_')) {
        itemType = 'unlike';
        itemId = key.substring('like_'.length);
      } else if (key.startsWith('follow_')) {
        itemType = 'unfollow';
        itemId = key.substring('follow_'.length);
      }
      if (type != null && itemType != type) continue;

      final val = box.get(rawKey);
      if (val is Map) {
        final m = Map<dynamic, dynamic>.from(val);
        final processedAt = (m['processedAt'] is int)
            ? m['processedAt'] as int
            : 0;
        if (itemType == 'unfollow') {
          items.add(
            ProcessedHistoryItem(
              key: key,
              id: (m['id'] ?? itemId).toString(),
              type: itemType,
              authorUsername: (m['uniqueId'] ?? m['authorUsername'] ?? itemId)
                  .toString(),
              authorNickname: (m['nickname'] ?? m['authorNickname'] ?? '')
                  .toString(),
              description: (m['bio'] ?? '').toString(),
              coverUrl: (m['avatarThumb'] ?? '').toString(),
              diggCount: (m['followerCount'] is int)
                  ? m['followerCount'] as int
                  : 0,
              processedAt: processedAt,
            ),
          );
        } else {
          items.add(
            ProcessedHistoryItem(
              key: key,
              id: (m['id'] ?? itemId).toString(),
              type: itemType,
              authorUsername: (m['authorUsername'] ?? 'tiktok').toString(),
              authorNickname: (m['authorNickname'] ?? '').toString(),
              description: (m['description'] ?? '').toString(),
              coverUrl: (m['coverUrl'] ?? '').toString(),
              diggCount: (m['diggCount'] is int) ? m['diggCount'] as int : 0,
              processedAt: processedAt,
            ),
          );
        }
      } else if (val is int) {
        items.add(
          ProcessedHistoryItem(
            key: key,
            id: itemId,
            type: itemType,
            authorUsername: itemType == 'unfollow' ? itemId : 'tiktok',
            authorNickname: itemType == 'unfollow'
                ? 'Tài khoản đã hủy follow'
                : 'Video ID: $itemId',
            description: 'Đã xử lý trong phiên trước',
            coverUrl: '',
            diggCount: 0,
            processedAt: val,
          ),
        );
      }
    }
    items.sort((a, b) => b.processedAt.compareTo(a.processedAt));
    return items;
  }

  Future<void> removeProcessedHistoryEntry(String key) async {
    await _historyBox?.delete(key);
  }

  Future<void> clearProcessedHistory({String? type}) async {
    final box = _historyBox;
    if (box == null) return;
    if (type == null) {
      await box.clear();
      return;
    }
    final prefix = type == 'repost'
        ? 'repost_'
        : (type == 'unlike' ? 'like_' : 'follow_');
    final keysToRemove = box.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    await box.deleteAll(keysToRemove);
  }

  // ─── Scan Batch Limit Settings ────────────────────────────────────────────
  int get scanBatchLimit =>
      (_settingsBox?.get('scan_batch_limit', defaultValue: 100) as int?) ?? 100;
  Future<void> setScanBatchLimit(int limit) async =>
      await _settingsBox?.put('scan_batch_limit', limit);

  // ─── Safety & Anti-Ban Settings ───────────────────────────────────────────
  int get customDelayMs =>
      (_settingsBox?.get('custom_delay_ms', defaultValue: 700) as int?) ?? 700;
  Future<void> setCustomDelayMs(int delay) async =>
      await _settingsBox?.put('custom_delay_ms', delay);

  bool get pulseJitterEnabled =>
      (_settingsBox?.get('pulse_jitter', defaultValue: true) as bool?) ?? true;
  Future<void> setPulseJitterEnabled(bool enabled) async =>
      await _settingsBox?.put('pulse_jitter', enabled);

  int get deepRestBatchCount =>
      (_settingsBox?.get('deep_rest_batch', defaultValue: 20) as int?) ?? 20;
  Future<void> setDeepRestBatchCount(int count) async =>
      await _settingsBox?.put('deep_rest_batch', count);

  int get deepRestDurationSec =>
      (_settingsBox?.get('deep_rest_sec', defaultValue: 12) as int?) ?? 12;
  Future<void> setDeepRestDurationSec(int sec) async =>
      await _settingsBox?.put('deep_rest_sec', sec);

  String get safetyPreset =>
      (_settingsBox?.get('safety_preset', defaultValue: 'balanced')
          as String?) ??
      'balanced';
  bool get studioToolsExpanded =>
      (_settingsBox?.get('studio_tools_expanded', defaultValue: false)
          as bool?) ??
      false;
  Future<void> setStudioToolsExpanded(bool value) async =>
      await _settingsBox?.put('studio_tools_expanded', value);
  int get updateSnoozedUntil =>
      (_settingsBox?.get('update_snoozed_until', defaultValue: 0) as int?) ?? 0;
  Future<void> snoozeUpdates() async => await _settingsBox?.put(
    'update_snoozed_until',
    DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
  );
  Future<void> setSafetyPreset(String preset) async =>
      await _settingsBox?.put('safety_preset', preset);
}
