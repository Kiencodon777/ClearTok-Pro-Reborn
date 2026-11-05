import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/database/local_database.dart';
import 'package:cleartok_reborn/models/tiktok_video.dart';
import 'package:cleartok_reborn/models/tiktok_follow_user.dart';
import 'package:cleartok_reborn/ui/screens/repost_studio_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';

class TestDatabase extends LocalDatabase {
  @override
  int get customDelayMs => 700;
  @override
  bool get pulseJitterEnabled => false;
  @override
  int get deepRestBatchCount => 20;
  @override
  int get deepRestDurationSec => 12;
  bool expanded = false;
  @override
  bool get studioToolsExpanded => expanded;
  @override
  Future<void> setStudioToolsExpanded(bool value) async {
    expanded = value;
  }

  @override
  int get scanBatchLimit => 100;
  @override
  int get totalDeletedCount => 0;
  @override
  List<TikTokVideo> getAllReposts() => [];
  @override
  List<TikTokFollowUser> getAllFollowing() => [];
  @override
  List<TikTokVideo> getAllLikedVideos() => [];
}

void main() {
  testWidgets('glass menu sheets fit a compact phone and close normally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: clearTokTheme(),
        home: RepostStudioScreen(
          database: TestDatabase(),
          client: null,
          currentUser: null,
          onSwitchToBrowser: () {},
        ),
      ),
    );
    for (final label in ['Thống kê', 'Xuất CSV/JSON', 'Cài đặt']) {
      await tester.tap(find.byTooltip('Menu Studio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(GlassSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
    }
  });
  testWidgets(
    'toolbar starts compact, expands, then collapses without a credit banner',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = TestDatabase();
      await tester.pumpWidget(
        MaterialApp(
          theme: clearTokTheme(),
          home: RepostStudioScreen(
            database: db,
            client: null,
            currentUser: null,
            onSwitchToBrowser: () {},
          ),
        ),
      );
      expect(find.text('Project Name'), findsNothing);
      expect(find.text('Đợt quét:'), findsNothing);
      // Creator text belongs below the app-level tab bar, not in the video area.
      expect(
        find.text('Viết Kiên & Anh Dũng', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Mở rộng công cụ'));
      await tester.pumpAndSettle();
      expect(find.text('Đợt quét:'), findsOneWidget);
      expect(db.expanded, true);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Thu gọn công cụ'));
      await tester.tap(find.byTooltip('Thu gọn công cụ'));
      await tester.pumpAndSettle();
      expect(find.text('Đợt quét:'), findsNothing);
      expect(db.expanded, false);
      await tester.tap(find.byTooltip('Menu Studio'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);
      expect(find.text('Tổng quan tương tác của bạn'), findsOneWidget);
      expect(find.text('Tài khoản ClearTok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
