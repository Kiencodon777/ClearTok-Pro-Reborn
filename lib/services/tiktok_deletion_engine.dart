import 'dart:async';
import 'dart:math';
import '../api/tiktok_client.dart';
import '../database/local_database.dart';
import '../models/tiktok_video.dart';
import 'background_notification_service.dart';

enum DeletionStatus { idle, running, paused, deepResting, completed, stopped, error }

class BatchDeletionProgress {
  final int total;
  final int deleted;
  final int failed;
  final TikTokVideo? currentVideo;
  final DeletionStatus status;
  final String? message;
  final String? lastErrorDetail;
  final int? deepRestRemainingSec;

  BatchDeletionProgress({
    required this.total,
    required this.deleted,
    required this.failed,
    this.currentVideo,
    required this.status,
    this.message,
    this.lastErrorDetail,
    this.deepRestRemainingSec,
  });
}

class TikTokDeletionEngine {
  final TikTokClient client;
  final LocalDatabase database;
  final BackgroundNotificationService _notifService = BackgroundNotificationService();

  bool _isCancelled = false;
  bool _isPaused = false;
  bool _isRunning = false;
  final _random = Random();

  final _progressController = StreamController<BatchDeletionProgress>.broadcast();
  Stream<BatchDeletionProgress> get progressStream => _progressController.stream;

  TikTokDeletionEngine({required this.client, required this.database}) {
    _notifService.init();
  }

  void stop() {
    _isCancelled = true;
    _notifService.cancelAll();
  }

  void pause() => _isPaused = true;
  void resume() => _isPaused = false;

  Future<void> executeBatch(List<TikTokVideo> videos) async {
    if (_isRunning) return;
    _isRunning = true;
    _isCancelled = false;
    _isPaused = false;

    final int total = videos.length;
    int deleted = 0;
    int failed = 0;
    int batchStreak = 0;

    _emit(BatchDeletionProgress(
      total: total,
      deleted: deleted,
      failed: failed,
      status: DeletionStatus.running,
      message: 'Khởi động tiến trình hủy $total repost...',
    ));

    await _notifService.showProgressNotification(
      deleted: deleted,
      total: total,
      statusText: 'Đang chuẩn bị dọn dẹp $total video...',
    );

    for (int i = 0; i < total; i++) {
      if (_isCancelled) {
        _emit(BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          status: DeletionStatus.stopped,
          message: 'Người dùng đã dừng tiến trình.',
        ));
        await _notifService.cancelAll();
        _isRunning = false;
        return;
      }

      while (_isPaused) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_isCancelled) {
          _isRunning = false;
          return;
        }
      }

      // ─── Smart Anti-Ban: Humanized Deep Rest Pulse ────────────────────────
      if (database.pulseJitterEnabled && batchStreak >= database.deepRestBatchCount) {
        batchStreak = 0;
        final restDuration = database.deepRestDurationSec;

        for (int sec = restDuration; sec > 0; sec--) {
          if (_isCancelled) break;
          while (_isPaused) {
            await Future.delayed(const Duration(milliseconds: 300));
            if (_isCancelled) break;
          }

          _emit(BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            status: DeletionStatus.deepResting,
            message: '🛡️ Nhịp thở tự nhiên (Anti-Ban): Đang nghỉ ngơi giải nhiệt... ($sec giây)',
            deepRestRemainingSec: sec,
          ));

          await _notifService.showProgressNotification(
            deleted: deleted,
            total: total,
            statusText: '🛡️ Tạm nghỉ né quét bot... (${sec}s)',
          );

          await Future.delayed(const Duration(seconds: 1));
        }

        if (_isCancelled) {
          _isRunning = false;
          return;
        }
      }

      final video = videos[i];
      _emit(BatchDeletionProgress(
        total: total,
        deleted: deleted,
        failed: failed,
        currentVideo: video,
        status: DeletionStatus.running,
        message: 'Đang hủy: @${video.authorUsername} (${i + 1}/$total)',
      ));

      await _notifService.showProgressNotification(
        deleted: deleted,
        total: total,
        statusText: 'Đang hủy: @${video.authorUsername} ($deleted/$total)',
      );

      try {
        final result = await client.deleteSingleRepost(itemId: video.id);

        if (result.success) {
          deleted++;
          batchStreak++;
          await database.removeRepost(video.id);
          _emit(BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            currentVideo: video,
            status: DeletionStatus.running,
            message: '✅ Đã hủy thành công: @${video.authorUsername}',
          ));
        } else {
          failed++;
          final errDetail =
              'status_code=${result.statusCode} | msg=${result.message} | raw=${result.rawResponse.length > 200 ? result.rawResponse.substring(0, 200) : result.rawResponse}';
          _emit(BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            currentVideo: video,
            status: DeletionStatus.running,
            message: '❌ Lỗi TikTok: ${result.message}',
            lastErrorDetail: errDetail,
          ));

          // Rate-limit backoff
          if (result.statusCode == 3002226 || result.statusCode == 429) {
            _emit(BatchDeletionProgress(
              total: total,
              deleted: deleted,
              failed: failed,
              status: DeletionStatus.paused,
              message: '⏳ Dính Rate-limit TikTok. Tạm dừng 60 giây giải nhiệt...',
            ));
            await Future.delayed(const Duration(seconds: 60));
            i--; // Retry this video
            continue;
          }
        }
      } catch (e) {
        failed++;
        _emit(BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          currentVideo: video,
          status: DeletionStatus.running,
          message: '💥 Lỗi ngoại lệ: $e',
          lastErrorDetail: e.toString(),
        ));
      }

      // Human-like jitter delay
      final baseDelay = database.customDelayMs;
      final jitter = _random.nextInt(300);
      await Future.delayed(Duration(milliseconds: baseDelay + jitter));
    }

    _emit(BatchDeletionProgress(
      total: total,
      deleted: deleted,
      failed: failed,
      status: DeletionStatus.completed,
      message: '🎉 Đã hoàn tất dọn dẹp! Thành công: $deleted, Thất bại: $failed.',
    ));

    await _notifService.showCompletionNotification(deleted: deleted, failed: failed);
    _isRunning = false;
  }

  void _emit(BatchDeletionProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  void dispose() {
    _isCancelled = true;
    _notifService.cancelAll();
    _progressController.close();
  }
}
