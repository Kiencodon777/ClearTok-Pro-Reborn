import 'package:hive/hive.dart';
import '../models/tiktok_video.dart';

class LocalDatabase {
  static const String repostBoxName = 'reposts_box';
  static const String historyBoxName = 'history_box';
  static const String settingsBoxName = 'settings_box';

  late Box _repostBox;
  late Box _historyBox;
  late Box _settingsBox;

  Future<void> init() async {
    _repostBox = await Hive.openBox(repostBoxName);
    _historyBox = await Hive.openBox(historyBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
  }

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

  int get customDelayMs => _settingsBox.get('custom_delay_ms', defaultValue: 700) as int;
  Future<void> setCustomDelayMs(int delay) async => await _settingsBox.put('custom_delay_ms', delay);
}
