import 'dart:async';
import 'account_fixture.dart';
import 'package:cleartok_reborn/api/tiktok_client.dart';
import 'package:cleartok_reborn/models/tiktok_video.dart';
import 'package:cleartok_reborn/services/cleartok_account.dart';
import 'package:cleartok_reborn/services/tiktok_deletion_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'studio_actions_test.dart' show ActionClient, ActionDatabase;

class GuestDatabase extends ActionDatabase {
  int usedTrial = 0;
  @override
  int get guestTrialUsedCount => usedTrial;
  @override
  int get guestTrialRemaining => (5 - usedTrial).clamp(0, 5);
  @override
  Future<void> incrementGuestTrialUsed([int count = 1]) async {
    usedTrial += count;
  }
}

class CaptchaClient extends ActionClient {
  @override
  Future<DeleteResult> deleteSingleRepost({required String itemId}) async {
    deleted.add(itemId);
    return DeleteResult(
      success: false,
      statusCode: 10402,
      message: 'captcha',
      rawResponse: '',
    );
  }
}

void main() {
  testWidgets('500 items use initial enrollment plus 30-second checks only', (
    tester,
  ) async {
    final fixture = AccountFixture();
    await fixture.signedIn();
    final client = ActionClient();
    final items = List.generate(500, (i) => client.videos[i % 2]);
    final engine = TikTokDeletionEngine(
      client: client,
      database: ActionDatabase(),
    );
    final started = tester.binding.clock.now();
    var done = false;
    final batch = engine.executeBatch(items).whenComplete(() => done = true);
    for (var i = 0; i < 10000 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, true);
    await batch;
    expect(client.deleted.length, 500);
    expect(
      fixture.checks,
      inInclusiveRange(
        1,
        1 + tester.binding.clock.now().difference(started).inSeconds ~/ 30,
      ),
    );
    expect(
      fixture.requestBodies
          .where((b) => b['action'] == 'register_device')
          .every((b) => b['payload']['feature'] == 'repost'),
      true,
    );
    engine.dispose();
    await tester.runAsync(fixture.dispose);
  });
  testWidgets('captcha prevents subsequent writes', (tester) async {
    ClearTokAccount.client = null;
    final client = CaptchaClient();
    final engine = TikTokDeletionEngine(
      client: client,
      database: ActionDatabase(),
    );
    await engine.executeBatch(client.videos);
    expect(client.deleted.length, 1);
    engine.dispose();
  });

  testWidgets(
    'access invalidation stops the next mocked TikTok write without deleting remaining cache',
    (tester) async {
      ClearTokAccount.client = null;
      ClearTokAccount.initFailed = false;
      final client = ActionClient()..gate = Completer<void>();
      final db = ActionDatabase()..items.addAll(client.videos);
      final engine = TikTokDeletionEngine(client: client, database: db);
      addTearDown(engine.dispose);
      final batch = engine.executeBatch(client.videos);
      await tester.pump();
      expect(client.deleted.length, 1);
      ClearTokAccount.accessInvalidated.value++;
      client.gate!.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await batch;
      expect(client.deleted.length, 1);
      expect(db.items.length, 1);
    },
  );

  testWidgets(
    'guest mode enforces persistent 5-item trial cap across multiple batches even if Supabase init failed',
    (tester) async {
      ClearTokAccount.client = null;
      ClearTokAccount.initFailed = true;
      addTearDown(() => ClearTokAccount.initFailed = false);

      final client = ActionClient();
      final sevenVideos = List.generate(
        7,
        (i) => TikTokVideo.fromJson({
          'id': 'v$i',
          'author': {'uniqueId': 'creator$i'},
          'video': <String, dynamic>{},
          'stats': <String, dynamic>{},
        }),
      );
      final db = GuestDatabase()..items.addAll(sevenVideos);
      final engine = TikTokDeletionEngine(client: client, database: db);
      addTearDown(engine.dispose);

      // First batch of 3 succeeds and records 3 used trial items
      final firstRun = engine.executeBatch(sevenVideos.take(3).toList());
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await firstRun;
      expect(client.deleted.length, 3);
      expect(db.usedTrial, 3);
      expect(db.guestTrialRemaining, 2);

      // Second batch of 4 stops after 2 more items (reaching cumulative 5)
      final secondRun = engine.executeBatch(sevenVideos.skip(3).toList());
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await secondRun;
      expect(client.deleted.length, 5);
      expect(db.usedTrial, 5);
      expect(db.guestTrialRemaining, 0);
    },
  );

  test(
    'isCaptchaChallenge detects TikTok captcha codes and challenge strings',
    () {
      expect(
        TikTokDeletionEngine.isCaptchaChallenge(10402, 'Error', '{}'),
        true,
      );
      expect(
        TikTokDeletionEngine.isCaptchaChallenge(3002226, 'Error', '{}'),
        true,
      );
      expect(
        TikTokDeletionEngine.isCaptchaChallenge(
          -1,
          'TikTok yêu cầu xác minh hoặc trang đã làm mới',
          '{"verify_check":true}',
        ),
        true,
      );
      expect(
        TikTokDeletionEngine.isCaptchaChallenge(403, 'Forbidden', '{}'),
        false,
      );
    },
  );
}
