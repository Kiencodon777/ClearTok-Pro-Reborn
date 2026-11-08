import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundNotificationService {
  static final BackgroundNotificationService _instance =
      BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(initSettings);
      _initialized = true;
    } catch (_) {}
  }

  Future<void> showProgressNotification({
    required int deleted,
    required int total,
    required String statusText,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'cleartok_bg_channel',
      'LapinTokk Deletion Tasks',
      channelDescription: 'Ongoing batch deletion progress and anti-ban status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: total,
      progress: deleted,
      enableVibration: false,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        888,
        'LapinTokk: Đang Dọn Dẹp ($deleted/$total)',
        statusText,
        details,
      );
    } catch (_) {}
  }

  Future<void> showCompletionNotification({
    required int deleted,
    required int failed,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'cleartok_done_channel',
      'LapinTokk Completion',
      channelDescription: 'Batch tasks completion notifications',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.cancel(888);
      await _notifications.show(
        889,
        'LapinTokk: Hoàn Tất! 🎉',
        'Đã dọn dẹp $deleted video thành công (Thất bại: $failed).',
        details,
      );
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _notifications.cancel(888);
    } catch (_) {}
  }
}
