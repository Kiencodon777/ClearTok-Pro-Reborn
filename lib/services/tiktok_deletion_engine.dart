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

  BatchDeletionProgress({
    required this.total,
    required this.deleted,
    required this.failed,
    this.currentVideo,
    required this.status,
    this.message,
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
    final csrfToken = await client.extractCsrfToken();

    for (int i = 0; i < total; i++) {
      if (_isCancelled) {
        _progressController.add(BatchDeletionProgress(
          total: total,
          deleted: deleted,
          failed: failed,
          status: DeletionStatus.stopped,
          message: 'Operation stopped by user.',
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
      ));

      try {
        final success = await client.deleteSingleRepost(itemId: video.id, csrfToken: csrfToken);
        if (success) {
          deleted++;
          await database.removeRepost(video.id);
        } else {
          failed++;
        }
      } catch (e) {
        if (e.toString().contains('RATE_LIMITED')) {
          _progressController.add(BatchDeletionProgress(
            total: total,
            deleted: deleted,
            failed: failed,
            status: DeletionStatus.paused,
            message: 'TikTok rate limit hit. Pausing for 60s cooldown...',
          ));
          await Future.delayed(const Duration(seconds: 60));
          i--; // Retry this video
          continue;
        } else {
          failed++;
        }
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
      message: 'Batch complete! Successfully deleted $deleted reposts.',
    ));
  }

  void dispose() {
    _progressController.close();
  }
}
