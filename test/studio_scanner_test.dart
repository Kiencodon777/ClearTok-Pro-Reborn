import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/api/tiktok_client.dart';
import 'package:cleartok_reborn/services/studio_scanner.dart';
import 'studio_actions_test.dart';

class HeldScanClient extends ActionClient {
  final response = Completer<ScanResult>();
  @override
  Future<ScanResult> fetchRepostBatch({
    required int cursor,
    required String secUid,
  }) => response.future;
}

void main() {
  test('cancelled scan never persists or appends an in-flight page', () async {
    final client = HeldScanClient();
    final database = ActionDatabase();
    var active = true, appended = 0;
    final future = StudioScanner().scan(
      client: client,
      database: database,
      user: TikTokUserProfile(
        id: 'a',
        uniqueId: 'a',
        nickname: 'a',
        avatarThumb: '',
        secUid: 'a',
      ),
      hub: 'repost',
      existingIds: {},
      targetLimit: 100,
      isActive: () => active,
      onPage: (_, count) => appended = count,
    );
    active = false;
    client.response.complete(
      ScanResult(videos: client.videos, nextCursor: 0, hasMore: false),
    );
    await future;
    expect(database.items, isEmpty);
    expect(appended, 0);
  });
  test('existing cached IDs are not appended twice', () async {
    final client = ActionClient(), database = ActionDatabase();
    final count = await StudioScanner().scan(
      client: client,
      database: database,
      user: TikTokUserProfile(
        id: 'a',
        uniqueId: 'a',
        nickname: 'a',
        avatarThumb: '',
        secUid: 'a',
      ),
      hub: 'repost',
      existingIds: {'0'},
      targetLimit: 100,
      isActive: () => true,
      onPage: (_, count) {},
    );
    expect(count, 1);
    expect(database.items.single.id, '1');
  });
}
