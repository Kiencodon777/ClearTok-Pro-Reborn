import 'package:hive/hive.dart';
import '../models/tiktok_video.dart';

class LocalDatabase {
  static const String repostBoxName = 'reposts_box';
  static const String historyBoxName = 'history_box';
  static const String settingsBoxName = 'settings_box';
  static const String likesBoxName = 'likes_box';
  static const String followsBoxName = 'follows_box';

  late Box _repostBox;
  late Box _historyBox;
  late Box _settingsBox;
  late Box _likesBox;
  late Box _followsBox;

  Future<void> init() async {
    _repostBox = await Hive.openBox(repostBoxName);
    _historyBox = await Hive.openBox(historyBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
    _likesBox = await Hive.openBox(likesBoxName);
    _followsBox = await Hive.openBox(followsBoxName);
  }

  // ─── Reposts Management ───────────────────────────────────────────────────
  List<TikTokVideo> getAllReposts() {
    return _repostBox.values
        .map((e) => TikTokVideo.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveReposts(List<TikTokVideo> videos) async {
    final map = {for (var v in videos) v.id: v.toMap()};
    await _repostBox.putAll(map);
  }

  Future<void> removeRepost(String videoId) async {
    await _repostBox.delete(videoId);
    await _historyBox.put(videoId, DateTime.now().millisecondsSinceEpoch);
  }

  bool isAlreadyDeleted(String videoId) {
    return _historyBox.containsKey(videoId);
  }

  int get totalDeletedCount => _historyBox.length;

  // ─── Safety & Anti-Ban Settings ───────────────────────────────────────────
  int get customDelayMs => _settingsBox.get('custom_delay_ms', defaultValue: 700) as int;
  Future<void> setCustomDelayMs(int delay) async => await _settingsBox.put('custom_delay_ms', delay);

  bool get pulseJitterEnabled => _settingsBox.get('pulse_jitter', defaultValue: true) as bool;
  Future<void> setPulseJitterEnabled(bool enabled) async => await _settingsBox.put('pulse_jitter', enabled);

  int get deepRestBatchCount => _settingsBox.get('deep_rest_batch', defaultValue: 20) as int;
  Future<void> setDeepRestBatchCount(int count) async => await _settingsBox.put('deep_rest_batch', count);

  int get deepRestDurationSec => _settingsBox.get('deep_rest_sec', defaultValue: 12) as int;
  Future<void> setDeepRestDurationSec(int sec) async => await _settingsBox.put('deep_rest_sec', sec);

  String get safetyPreset => _settingsBox.get('safety_preset', defaultValue: 'balanced') as String;
  Future<void> setSafetyPreset(String preset) async => await _settingsBox.put('safety_preset', preset);
}
