import 'dart:async';
import 'package:cleartok_reborn/services/cleartok_account.dart';
import 'package:cleartok_reborn/services/tiktok_deletion_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'studio_actions_test.dart' show ActionClient, ActionDatabase;

void main() {
  testWidgets(
    'access invalidation stops the next mocked TikTok write without deleting remaining cache',
    (tester) async {
      ClearTokAccount.client = null;
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
}
