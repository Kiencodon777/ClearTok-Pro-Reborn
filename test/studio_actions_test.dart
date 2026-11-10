import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/api/tiktok_client.dart';
import 'package:cleartok_reborn/models/tiktok_video.dart';
import 'package:cleartok_reborn/ui/screens/repost_studio_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';
import 'studio_toolbar_test.dart' show TestDatabase;

class ActionDatabase extends TestDatabase {
  final items = <TikTokVideo>[];
  @override
  List<TikTokVideo> getAllReposts() => items.toList();
  @override
  int get customDelayMs => 0;
  @override
  bool get pulseJitterEnabled => false;
  @override
  Future<void> removeRepost(String id) async {
    items.removeWhere((v) => v.id == id);
  }

  @override
  Future<void> saveReposts(List<TikTokVideo> videos) async {
    items.addAll(videos);
  }
}

class ActionClient implements TikTokClient {
  Completer<void>? gate;
  final videos = List.generate(
    2,
    (i) => TikTokVideo.fromJson({
      'id': '$i',
      'author': {'uniqueId': 'creator$i'},
      'video': <String, dynamic>{},
      'stats': <String, dynamic>{},
    }),
  );
  final deleted = <String>[];
  @override
  Future<ScanResult> fetchRepostBatch({
    required int cursor,
    required String secUid,
  }) async => ScanResult(videos: videos, nextCursor: 0, hasMore: false);
  @override
  Future<DeleteResult> deleteSingleRepost({
    required String itemId,
    MutationToken? token,
  }) async {
    deleted.add(itemId);
    await gate?.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return DeleteResult(
      success: true,
      statusCode: 0,
      message: '',
      rawResponse: '',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'pause, resume and stop controls stay reachable in live glass sheet',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = ActionClient()..gate = Completer<void>();
      final db = ActionDatabase()..items.addAll(client.videos);
      await tester.pumpWidget(
        MaterialApp(
          theme: clearTokTheme(),
          home: RepostStudioScreen(
            database: db,
            client: client,
            currentUser: null,
            onSwitchToBrowser: () {},
          ),
        ),
      );
      await tester.tap(find.text('Hủy Repost (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt Đầu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tạm Dừng'));
      await tester.tap(find.text('Tạm Dừng'));
      await tester.pump();
      expect(find.text('Tiếp Tục'), findsOneWidget);
      await tester.ensureVisible(find.text('Tiếp Tục'));
      await tester.tap(find.text('Tiếp Tục'));
      await tester.pump();
      expect(find.text('Tạm Dừng'), findsOneWidget);
      await tester.ensureVisible(find.text('Dừng Hẳn'));
      await tester.tap(find.text('Dừng Hẳn'));
      client.gate!.complete();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(client.deleted.length, 1);
      expect(find.text('Đóng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Đóng'));
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
    },
  );
  for (final count in [1, 2]) {
    testWidgets(
      'scan, select and confirm deletion of $count reposts through glass UI',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = ActionDatabase();
        final client = ActionClient();
        await tester.pumpWidget(
          MaterialApp(
            theme: clearTokTheme(),
            home: RepostStudioScreen(
              database: db,
              client: client,
              currentUser: TikTokUserProfile(
                id: 'test',
                uniqueId: 'test',
                nickname: 'Test',
                avatarThumb: '',
                secUid: 'test',
              ),
              onSwitchToBrowser: () {},
            ),
          ),
        );
        await tester.tap(find.text('Quét Repost (100)'));
        await tester.pumpAndSettle();
        expect(db.items.length, 2);
        if (count == 1) {
          await tester.tap(find.byKey(const ValueKey('video-1')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Hủy Repost ($count)'));
        await tester.pumpAndSettle();
        expect(find.text('Xác Nhận Xử Lý'), findsOneWidget);
        client.gate = Completer<void>();
        await tester.tap(find.text('Bắt Đầu'));
        await tester.pumpAndSettle();
        client.gate!.complete();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(client.deleted.length, count);
        expect(db.items.length, 2 - count);
        expect(find.text('Đóng'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Đóng'));
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();
      },
    );
  }
}
