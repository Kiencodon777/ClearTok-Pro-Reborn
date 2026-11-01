import 'dart:async';
import 'dart:math';
import '../api/tiktok_client.dart';
import '../database/local_database.dart';
import '../models/tiktok_video.dart';

enum DeletionStatus { idle, running, paused, completed, stopped, error }

class BatchDeletionProgress {
  final int total;
  final int deleted;
  final int failed;
  final TikTokVideo? currentVideo;
  final DeletionStatus status;
  final String? message;
  final String? lastErrorDetail;

  BatchDeletionProgress({
    required this.total,
    required this.deleted,
    required this.failed,
    this.currentVideo,
    required this.status,
    this.message,
    this.lastErrorDetail,
  });
}

class TikTokDeletionEngine {
  final TikTokClient client;
  final LocalDatabase database;
  
  bool _isCancelled = false;
  bool _isPaused = false;
  final _random = Random();

  final _progressController = StreamController<BatchDeletionProgress>.broadcast();
  Stream<BatchDeletionProgress> get progressStream => _progressController.stream;

  TikTokDeletionEngine({required this.client, required this.database});

  void stop() => _isCancelled = true;
  void pause() => _isPaused = true;
  void resume() => _isPaused = false;

  Future<void> executeBatch(List<TikTokVideo> videos) async {
    _isCancelled = false;
    _isPaused = false;

    int total = videos.length;
    int deleted = 0;
    int failed = 0;

    _progressController.add(BatchDeletionProgress(
      total: total,
      deleted: deleted,
      failed: failed,
      status: DeletionStatus.running,
      message: 'Khởi động tiến trình hủy $total repost...',
    ));

    for (int i = 0; i < total; i++) {
      if (_isCancelled) {
        _progressController.add(BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          status: DeletionStatus.stopped,
          message: 'Người dùng đã dừng tiến trình.',
        ));
        return;
      }

      while (_isPaused) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_isCancelled) return;
      }

      final video = videos[i];
      _progressController.add(BatchDeletionProgress(
        total: total,
        deleted: deleted,
        failed: failed,
        currentVideo: video,
        status: DeletionStatus.running,
        message: 'Đang hủy: @${video.authorUsername} (${i + 1}/$total)',
      ));

      try {
        final result = await client.deleteSingleRepost(itemId: video.id);

        if (result.success) {
          deleted++;
          await database.removeRepost(video.id);
          _progressController.add(BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            currentVideo: video,
            status: DeletionStatus.running,
            message: 'Đã hủy thành công: @${video.authorUsername}',
          ));
        } else {
          failed++;
          _progressController.add(BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            currentVideo: video,
            status: DeletionStatus.running,
            message: 'Lỗi TikTok: ${result.message}',
            lastErrorDetail: result.rawResponse.isNotEmpty ? result.rawResponse : result.message,
          ));

          if (result.statusCode == 3002226 || result.statusCode == 429) {
            _progressController.add(BatchDeletionProgress(
              total: total,
              deleted: deleted,
              failed: failed,
              status: DeletionStatus.paused,
              message: 'Dính Rate-limit TikTok. Tạm dừng 60 giây giải nhiệt...',
            ));
            await Future.delayed(const Duration(seconds: 60));
            i--; // Thử lại video này
            continue;
          }
        }
      } catch (e) {
        failed++;
        _progressController.add(BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          currentVideo: video,
          status: DeletionStatus.running,
          message: 'Lỗi ngoại lệ: $e',
          lastErrorDetail: e.toString(),
        ));
      }

      // Jitter delay (base delay + random 0..300ms) to ensure human-like cadence
      final baseDelay = database.customDelayMs;
      final jitter = _random.nextInt(300);
      await Future.delayed(Duration(milliseconds: baseDelay + jitter));
    }

    _progressController.add(BatchDeletionProgress(
      total: total,
      deleted: deleted,
      failed: failed,
      status: DeletionStatus.completed,
      message: 'Đã hoàn tất dọn dẹp! Thành công: $deleted, Thất bại: $failed.',
    ));
  }

  void dispose() {
    _progressController.close();
  }
}
