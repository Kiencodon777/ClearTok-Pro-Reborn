import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/tiktok_client.dart';
import '../database/local_database.dart';
import '../models/tiktok_follow_user.dart';
import '../models/tiktok_video.dart';
import 'background_notification_service.dart';
import 'diagnostic_log.dart';
import 'cleartok_account.dart';

enum DeletionStatus {
  idle,
  running,
  paused,
  deepResting,
  captchaRequired,
  completed,
  stopped,
  error,
}

class BatchDeletionProgress {
  final int total;
  final int deleted;
  final int failed;
  final String? currentTitle;
  final DeletionStatus status;
  final String? message;
  final String? lastErrorDetail;
  final int? deepRestRemainingSec;

  BatchDeletionProgress({
    required this.total,
    required this.deleted,
    required this.failed,
    this.currentTitle,
    required this.status,
    this.message,
    this.lastErrorDetail,
    this.deepRestRemainingSec,
  });
}

class TikTokDeletionEngine {
  final TikTokClient client;
  final LocalDatabase database;
  final BackgroundNotificationService _notifService =
      BackgroundNotificationService();

  bool _isCancelled = false;
  bool _isPaused = false;
  bool _isRunning = false;
  String? _cancelReason;
  final _random = Random();

  final _progressController =
      StreamController<BatchDeletionProgress>.broadcast();
  Stream<BatchDeletionProgress> get progressStream =>
      _progressController.stream;
  StreamSubscription? _accountSubscription;
  Timer? _accountTimer;
  String? _activeFeature;
  bool _checkingAccount = false;

  TikTokDeletionEngine({required this.client, required this.database}) {
    ClearTokAccount.accessInvalidated.addListener(_onAccessInvalidated);
    _notifService.init();
    _accountSubscription = ClearTokAccount.client?.auth.onAuthStateChange
        .listen((event) {
          if (event.session == null) {
            _cancelReason = 'Đã đăng xuất khỏi tài khoản ClearTok.';
            stop();
          }
        }, onError: (Object _) => stop());
    if (ClearTokAccount.client != null) {
      _accountTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (_isRunning &&
            !_checkingAccount &&
            ClearTokAccount.client?.auth.currentSession != null) {
          try {
            _checkingAccount = true;
            await ClearTokAccount.check(feature: _activeFeature);
          } catch (error) {
            if (error is FunctionException &&
                (error.status == 401 ||
                    error.status == 403 ||
                    error.status == 429)) {
              _cancelReason =
                  'Tài khoản hoặc thiết bị không được phép truy cập.';
              stop();
            }
          } finally {
            _checkingAccount = false;
          }
        }
      });
    }
  }

  void _onAccessInvalidated() {
    _cancelReason = 'Tài khoản hoặc thiết bị không được phép truy cập.';
    stop();
  }

  void stop() {
    _isCancelled = true;
    _notifService.cancelAll();
  }

  void pause() => _isPaused = true;
  void resume() => _isPaused = false;

  static bool isCaptchaChallenge(int statusCode, String message, String raw) {
    if (statusCode == 10402 || statusCode == 3002226) return true;
    final combined = '${message.toLowerCase()} ${raw.toLowerCase()}';
    return combined.contains('captcha') ||
        combined.contains('verify_check') ||
        combined.contains('xác minh');
  }

  Future<void> _finishStopped(
    int total,
    int deleted,
    int failed, [
    String? customMessage,
  ]) async {
    _emit(
      BatchDeletionProgress(
        total: total,
        deleted: deleted,
        failed: failed,
        status: DeletionStatus.stopped,
        message:
            customMessage ?? _cancelReason ?? 'Người dùng đã dừng tiến trình.',
      ),
    );
    await _notifService.cancelAll();
  }

  /// Executes batch for Reposts or Liked Videos (mode: 'repost' or 'unlike')
  Future<void> executeBatch(
    List<TikTokVideo> videos, {
    String mode = 'repost',
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    _isCancelled = false;
    _isPaused = false;
    _cancelReason = null;

    final isUnlike = mode == 'unlike';
    _activeFeature = isUnlike ? 'unlike' : 'repost';
    final actionName = isUnlike ? 'bỏ thích' : 'hủy repost';
    final int total = videos.length;
    int deleted = 0;
    int failed = 0;
    final clearTokOwner = ClearTokAccount.client?.auth.currentUser?.id;
    int batchStreak = 0;

    try {
      if (clearTokOwner != null) {
        await ClearTokAccount.check(feature: _activeFeature);
      }
      _emit(
        BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          status: DeletionStatus.running,
          message: 'Khởi động tiến trình $actionName $total video...',
        ),
      );

      await _notifService.showProgressNotification(
        deleted: deleted,
        total: total,
        statusText: 'Đang chuẩn bị $actionName $total video...',
      );

      for (int i = 0; i < total; i++) {
        if (_isCancelled) {
          await _finishStopped(total, deleted, failed);
          return;
        }

        while (_isPaused) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (_isCancelled) {
            await _finishStopped(total, deleted, failed);
            return;
          }
        }

        // Giảm tốc deep rest check
        if (database.pulseJitterEnabled &&
            batchStreak >= database.deepRestBatchCount) {
          batchStreak = 0;
          final restDuration = database.deepRestDurationSec;

          for (int sec = restDuration; sec > 0; sec--) {
            if (_isCancelled) break;
            while (_isPaused) {
              await Future.delayed(const Duration(milliseconds: 300));
              if (_isCancelled) break;
            }
            if (_isCancelled) break;

            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                status: DeletionStatus.deepResting,
                message:
                    '🛡️ Nhịp thở tự nhiên (Giảm tốc): Đang nghỉ ngơi giải nhiệt... ($sec giây)',
                deepRestRemainingSec: sec,
              ),
            );

            await _notifService.showProgressNotification(
              deleted: deleted,
              total: total,
              statusText: '🛡️ Tạm nghỉ tạm nghỉ... (${sec}s)',
            );

            await Future.delayed(const Duration(seconds: 1));
          }

          if (_isCancelled) {
            await _finishStopped(total, deleted, failed);
            return;
          }
        }

        final isGuest =
            ClearTokAccount.initFailed ||
            (ClearTokAccount.client != null && clearTokOwner == null);
        if (isGuest && (i >= 5 || database.guestTrialRemaining <= 0)) {
          _isCancelled = true;
          await _finishStopped(
            total,
            deleted,
            failed,
            'Đã đạt giới hạn 5 mục dùng thử cho Khách. Đăng nhập ClearTok để mở khóa!',
          );
          return;
        }

        final video = videos[i];
        _emit(
          BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            currentTitle: '@${video.authorUsername}',
            status: DeletionStatus.running,
            message:
                'Đang $actionName: @${video.authorUsername} (${i + 1}/$total)',
          ),
        );

        await _notifService.showProgressNotification(
          deleted: deleted,
          total: total,
          statusText:
              'Đang $actionName: @${video.authorUsername} ($deleted/$total)',
        );

        try {
          if (ClearTokAccount.client != null) {
            if (clearTokOwner != ClearTokAccount.client!.auth.currentUser?.id) {
              _isCancelled = true;
              await _finishStopped(
                total,
                deleted,
                failed,
                'Tài khoản ClearTok đã thay đổi trong khi chạy.',
              );
              return;
            }
          }
          final result = isUnlike
              ? await client.unlikeVideo(
                  awemeId: video.id,
                  author: video.authorUsername,
                )
              : await client.deleteSingleRepost(itemId: video.id);

          if (result.success) {
            deleted++;
            batchStreak++;
            if (isGuest) {
              await database.incrementGuestTrialUsed();
            }
            if (isUnlike) {
              await database.removeLikedVideo(video.id);
            } else {
              await database.removeRepost(video.id);
            }

            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                currentTitle: '@${video.authorUsername}',
                status: DeletionStatus.running,
                message:
                    '✅ Đã $actionName thành công: @${video.authorUsername}',
              ),
            );
          } else {
            failed++;
            final errDetail =
                'status_code=${result.statusCode} | msg=${result.message} | raw=${result.rawResponse.length > 200 ? result.rawResponse.substring(0, 200) : result.rawResponse}';
            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                currentTitle: '@${video.authorUsername}',
                status: DeletionStatus.running,
                message: '❌ Lỗi TikTok: ${result.message}',
                lastErrorDetail: errDetail,
              ),
            );

            if (isCaptchaChallenge(
              result.statusCode,
              result.message,
              result.rawResponse,
            )) {
              _emit(
                BatchDeletionProgress(
                  total: total,
                  deleted: deleted,
                  failed: failed,
                  currentTitle: '@${video.authorUsername}',
                  status: DeletionStatus.captchaRequired,
                  message:
                      '🛡️ TikTok yêu cầu xác minh bảo mật (Captcha). Hãy bấm "Mở xác minh TikTok ngay" để giải Captcha rồi tiếp tục nhé!',
                  lastErrorDetail: errDetail,
                ),
              );
              await _notifService.cancelAll();
              return;
            }

            if ([
              -1,
              -2,
              401,
              403,
              10402,
              3002226,
              429,
            ].contains(result.statusCode)) {
              _emit(
                BatchDeletionProgress(
                  total: total,
                  deleted: deleted,
                  failed: failed,
                  status: DeletionStatus.error,
                  message:
                      'Đã dừng vì chưa xác nhận được kết quả. ${result.message}',
                ),
              );
              await _notifService.cancelAll();
              return;
            }
          }
        } catch (e) {
          if (e is FunctionException && (e.status == 401 || e.status == 403)) {
            _isCancelled = true;
            await _finishStopped(
              total,
              deleted,
              failed,
              'Tài khoản hoặc thiết bị không được phép truy cập.',
            );
            return;
          }
          if (e is FunctionException && e.status == 429) {
            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                status: DeletionStatus.error,
                message:
                    'Bạn đang gửi quá nhanh (Rate Limit). Vui lòng thử lại sau ít phút.',
              ),
            );
            await _notifService.cancelAll();
            return;
          }
          failed++;
          _emit(
            BatchDeletionProgress(
              total: total,
              deleted: deleted,
              failed: failed,
              currentTitle: '@${video.authorUsername}',
              status: DeletionStatus.running,
              message: '💥 Lỗi ngoại lệ: $e',
              lastErrorDetail: e.toString(),
            ),
          );
        }

        final baseDelay = database.customDelayMs;
        final jitter = _random.nextInt(300);
        await Future.delayed(Duration(milliseconds: baseDelay + jitter));
      }

      _emit(
        BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          status: DeletionStatus.completed,
          message:
              '🎉 Đã hoàn tất $actionName! Thành công: $deleted, Thất bại: $failed.',
        ),
      );

      await _notifService.showCompletionNotification(
        deleted: deleted,
        failed: failed,
      );
    } finally {
      _isRunning = false;
    }
  }

  /// Executes batch for Following Users (mode: 'unfollow')
  Future<void> executeUnfollowBatch(List<TikTokFollowUser> users) async {
    if (_isRunning) return;
    _isRunning = true;
    _isCancelled = false;
    _isPaused = false;
    _cancelReason = null;

    _activeFeature = 'unfollow';
    final int total = users.length;
    int deleted = 0;
    int failed = 0;
    final clearTokOwner = ClearTokAccount.client?.auth.currentUser?.id;
    int batchStreak = 0;

    try {
      if (clearTokOwner != null) {
        await ClearTokAccount.check(feature: _activeFeature);
      }
      _emit(
        BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          status: DeletionStatus.running,
          message: 'Khởi động tiến trình hủy theo dõi $total tài khoản...',
        ),
      );

      await _notifService.showProgressNotification(
        deleted: deleted,
        total: total,
        statusText: 'Đang hủy theo dõi $total tài khoản...',
      );

      for (int i = 0; i < total; i++) {
        if (_isCancelled) {
          await _finishStopped(total, deleted, failed);
          return;
        }

        while (_isPaused) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (_isCancelled) {
            await _finishStopped(total, deleted, failed);
            return;
          }
        }

        if (database.pulseJitterEnabled &&
            batchStreak >= database.deepRestBatchCount) {
          batchStreak = 0;
          final restDuration = database.deepRestDurationSec;

          for (int sec = restDuration; sec > 0; sec--) {
            if (_isCancelled) break;
            while (_isPaused) {
              await Future.delayed(const Duration(milliseconds: 300));
              if (_isCancelled) break;
            }
            if (_isCancelled) break;

            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                status: DeletionStatus.deepResting,
                message:
                    '🛡️ Nhịp thở tự nhiên (Giảm tốc): Đang nghỉ ngơi giải nhiệt... ($sec giây)',
                deepRestRemainingSec: sec,
              ),
            );

            await _notifService.showProgressNotification(
              deleted: deleted,
              total: total,
              statusText: '🛡️ Tạm nghỉ tạm nghỉ... (${sec}s)',
            );

            await Future.delayed(const Duration(seconds: 1));
          }

          if (_isCancelled) {
            await _finishStopped(total, deleted, failed);
            return;
          }
        }

        final isGuest =
            ClearTokAccount.initFailed ||
            (ClearTokAccount.client != null && clearTokOwner == null);
        if (isGuest && (i >= 5 || database.guestTrialRemaining <= 0)) {
          _isCancelled = true;
          await _finishStopped(
            total,
            deleted,
            failed,
            'Đã đạt giới hạn 5 mục dùng thử cho Khách. Đăng nhập ClearTok để mở khóa!',
          );
          return;
        }

        final user = users[i];
        _emit(
          BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            currentTitle: '@${user.uniqueId}',
            status: DeletionStatus.running,
            message: 'Đang hủy follow: @${user.uniqueId} (${i + 1}/$total)',
          ),
        );

        await _notifService.showProgressNotification(
          deleted: deleted,
          total: total,
          statusText: 'Đang hủy follow: @${user.uniqueId} ($deleted/$total)',
        );

        try {
          if (ClearTokAccount.client != null) {
            if (clearTokOwner != ClearTokAccount.client!.auth.currentUser?.id) {
              _isCancelled = true;
              await _finishStopped(
                total,
                deleted,
                failed,
                'Tài khoản ClearTok đã thay đổi trong khi chạy.',
              );
              return;
            }
          }
          final result = await client.unfollowUser(
            userId: user.id,
            secUid: user.secUid,
          );

          if (result.success) {
            deleted++;
            batchStreak++;
            if (isGuest) {
              await database.incrementGuestTrialUsed();
            }
            await database.removeFollowing(user.id);

            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                currentTitle: '@${user.uniqueId}',
                status: DeletionStatus.running,
                message: '✅ Đã hủy follow thành công: @${user.uniqueId}',
              ),
            );
          } else {
            failed++;
            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                currentTitle: '@${user.uniqueId}',
                status: DeletionStatus.running,
                message: '❌ Lỗi TikTok: ${result.message}',
                lastErrorDetail: result.rawResponse.length > 200
                    ? result.rawResponse.substring(0, 200)
                    : result.rawResponse,
              ),
            );

            if (isCaptchaChallenge(
              result.statusCode,
              result.message,
              result.rawResponse,
            )) {
              _emit(
                BatchDeletionProgress(
                  total: total,
                  deleted: deleted,
                  failed: failed,
                  currentTitle: '@${user.uniqueId}',
                  status: DeletionStatus.captchaRequired,
                  message:
                      '🛡️ TikTok yêu cầu xác minh bảo mật (Captcha). Hãy bấm "Mở xác minh TikTok ngay" để giải Captcha rồi tiếp tục nhé!',
                  lastErrorDetail: result.rawResponse.length > 200
                      ? result.rawResponse.substring(0, 200)
                      : result.rawResponse,
                ),
              );
              await _notifService.cancelAll();
              return;
            }

            if ([
              -1,
              -2,
              401,
              403,
              10402,
              3002226,
              429,
            ].contains(result.statusCode)) {
              _emit(
                BatchDeletionProgress(
                  total: total,
                  deleted: deleted,
                  failed: failed,
                  status: DeletionStatus.error,
                  message:
                      'Đã dừng vì chưa xác nhận được kết quả. ${result.message}',
                ),
              );
              await _notifService.cancelAll();
              return;
            }
          }
        } catch (e) {
          if (e is FunctionException && (e.status == 401 || e.status == 403)) {
            _isCancelled = true;
            await _finishStopped(
              total,
              deleted,
              failed,
              'Tài khoản hoặc thiết bị không được phép truy cập.',
            );
            return;
          }
          if (e is FunctionException && e.status == 429) {
            _emit(
              BatchDeletionProgress(
                total: total,
                deleted: deleted,
                failed: failed,
                status: DeletionStatus.error,
                message:
                    'Bạn đang gửi quá nhanh (Rate Limit). Vui lòng thử lại sau ít phút.',
              ),
            );
            await _notifService.cancelAll();
            return;
          }
          failed++;
          _emit(
            BatchDeletionProgress(
              total: total,
              deleted: deleted,
              failed: failed,
              currentTitle: '@${user.uniqueId}',
              status: DeletionStatus.running,
              message: '💥 Lỗi ngoại lệ: $e',
              lastErrorDetail: e.toString(),
            ),
          );
        }

        final baseDelay = database.customDelayMs;
        final jitter = _random.nextInt(300);
        await Future.delayed(Duration(milliseconds: baseDelay + jitter));
      }

      _emit(
        BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          status: DeletionStatus.completed,
          message:
              '🎉 Đã hoàn tất hủy theo dõi! Thành công: $deleted, Thất bại: $failed.',
        ),
      );

      await _notifService.showCompletionNotification(
        deleted: deleted,
        failed: failed,
      );
    } finally {
      _isRunning = false;
    }
  }

  void _emit(BatchDeletionProgress progress) {
    if ([
      DeletionStatus.captchaRequired,
      DeletionStatus.completed,
      DeletionStatus.stopped,
      DeletionStatus.error,
    ].contains(progress.status)) {
      DiagnosticLog.instance.record(
        'batch.${progress.status.name}',
        progress.failed > 0 ? -1 : 0,
      );
    }
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  void dispose() {
    ClearTokAccount.accessInvalidated.removeListener(_onAccessInvalidated);
    _accountSubscription?.cancel();
    _accountTimer?.cancel();
    _isCancelled = true;
    _notifService.cancelAll();
    _progressController.close();
  }
}
