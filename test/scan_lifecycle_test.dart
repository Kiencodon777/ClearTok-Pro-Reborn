import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/api/tiktok_client.dart';
import 'package:cleartok_reborn/ui/screens/repost_studio_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';
import 'studio_actions_test.dart';
import 'studio_scanner_test.dart' show HeldScanClient;

void main() {
  testWidgets('unmounting Studio drops the pending scan result', (
    tester,
  ) async {
    final client = HeldScanClient();
    final database = ActionDatabase();
    await tester.pumpWidget(
      MaterialApp(
        theme: clearTokTheme(),
        home: RepostStudioScreen(
          database: database,
          client: client,
          currentUser: TikTokUserProfile(
            id: 'a',
            uniqueId: 'a',
            nickname: 'a',
            avatarThumb: '',
            secUid: 'a',
          ),
          onSwitchToBrowser: () {},
        ),
      ),
    );
    await tester.tap(find.text('Quét Repost (100)'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    client.response.complete(
      ScanResult(videos: client.videos, nextCursor: 0, hasMore: false),
    );
    await tester.pump();
    expect(database.items, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
