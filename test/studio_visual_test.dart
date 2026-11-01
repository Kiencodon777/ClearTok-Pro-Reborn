import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/models/tiktok_follow_user.dart';
import 'package:cleartok_reborn/ui/screens/repost_studio_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';
import 'studio_toolbar_test.dart' show TestDatabase;

class PreviewDatabase extends TestDatabase {
  @override
  List<TikTokFollowUser> getAllFollowing() => List.generate(8, (i) => TikTokFollowUser(
    id: '$i', uniqueId: ['vietkien', 'anhdung', 'cleartok_creator'][i % 3],
    nickname: ['Viết Kiên', 'Anh Dũng', 'Nhà sáng tạo nội dung'][i % 3],
    avatarThumb: '', followerCount: 1200));
}

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844), const Size(844, 390)]) {
    testWidgets('Studio layout and selection at ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(useMaterial3: true),
        home: RepaintBoundary(key: const ValueKey('preview'), child: AmbientBackground(
          child: RepostStudioScreen(database: PreviewDatabase(), client: null,
            currentUser: null, onSwitchToBrowser: () {})))));
      await tester.tap(find.text('Mass Un-Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy Follow (8)'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Hủy Follow (7)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width == 390) {
        await tester.tap(find.byTooltip('Mở rộng công cụ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await expectLater(find.byKey(const ValueKey('preview')),
        matchesGoldenFile('../build/ui-previews/studio-${size.width.toInt()}.png'));
    });
  }
}
