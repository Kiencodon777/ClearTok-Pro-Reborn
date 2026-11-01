import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/database/local_database.dart';
import 'package:cleartok_reborn/models/tiktok_video.dart';
import 'package:cleartok_reborn/models/tiktok_follow_user.dart';
import 'package:cleartok_reborn/ui/screens/repost_studio_screen.dart';

class TestDatabase extends LocalDatabase {
  bool expanded = false;
  @override bool get studioToolsExpanded => expanded;
  @override Future<void> setStudioToolsExpanded(bool value) async { expanded = value; }
  @override int get scanBatchLimit => 100;
  @override int get totalDeletedCount => 0;
  @override List<TikTokVideo> getAllReposts() => [];
  @override List<TikTokFollowUser> getAllFollowing() => [];
  @override List<TikTokVideo> getAllLikedVideos() => [];
}

void main() {
  testWidgets('toolbar starts compact, expands, then collapses without a credit banner', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = TestDatabase();
    await tester.pumpWidget(MaterialApp(home: RepostStudioScreen(database: db, client: null, currentUser: null, onSwitchToBrowser: () {})));
    expect(find.text('Project Name'), findsNothing);
    expect(find.text('Đợt quét:'), findsNothing);
    expect(find.text('D&K'), findsOneWidget);
    await tester.tap(find.byTooltip('Mở rộng công cụ'));
    await tester.pumpAndSettle();
    expect(find.text('Đợt quét:'), findsOneWidget);
    expect(db.expanded, true);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Thu gọn công cụ'));
    await tester.pumpAndSettle();
    expect(find.text('Đợt quét:'), findsNothing);
    expect(db.expanded, false);
  });
}
