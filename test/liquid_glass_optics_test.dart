import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/core/remote_payload_config.dart';
import 'package:cleartok_reborn/models/tiktok_video.dart';
import 'package:cleartok_reborn/ui/screens/main_navigation_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';
import 'package:cleartok_reborn/ui/widgets/project_credits.dart';
import 'main_navigation_test.dart' show TestWebViewPlatform;
import 'studio_toolbar_test.dart' show TestDatabase;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const coverUrl = 'https://fixture.invalid/cleartok-cover.jpg';

class OpticsDatabase extends TestDatabase {
  @override
  List<TikTokVideo> getAllReposts() => List.generate(
    8,
    (i) => TikTokVideo.fromJson({
      'id': '$i',
      'author': <String, dynamic>{'uniqueId': 'creator$i'},
      'video': <String, dynamic>{'cover': coverUrl},
      'stats': <String, dynamic>{'diggCount': 128},
    }),
  );
}

void main() {
  testWidgets(
    'real glass dock includes credits, sits at bottom and renders over images',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      InAppWebViewPlatform.instance = TestWebViewPlatform();
      await tester.runAsync(() async {
        final sdk = Platform.environment['FLUTTER_ROOT'];
        final font = await File(
          '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ).readAsBytes();
        for (final family in [
          'Roboto',
          'CupertinoSystemText',
          'CupertinoSystemDisplay',
        ]) {
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(font)))).load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        final bytes = await rootBundle.load('assets/brand/app_icon.jpg');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        PaintingBinding.instance.imageCache.putIfAbsent(
          const NetworkImage(coverUrl),
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: frame.image)),
          ),
        );
        codec.dispose();
      });
      final theme = clearTokTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
          ),
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('optics-preview'),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 47, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
              ),
              child: AmbientBackground(child: child!),
            ),
          ),
          home: MainNavigationScreen(
            database: OpticsDatabase(),
            remoteConfig: const RemotePayloadConfig(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Studio Reposts').hitTestable().first);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/app_icon.jpg'),
          tester.element(find.byType(MainNavigationScreen)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byType(ProjectCreditFooter),
          matching: find.byKey(const ValueKey('creator-dock')),
        ),
        findsOneWidget,
      );
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('creator-dock'))).dy,
        844,
      );
      expect(find.byType(GBoxLiquidDock), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('optics-preview')),
        matchesGoldenFile('goldens/dock-liquid-glass.png'),
      );
      final press = await tester.startGesture(
        tester.getCenter(find.text('Studio Reposts').hitTestable().first),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await press.moveBy(const Offset(-20, -4));
      await tester.pump(const Duration(milliseconds: 80));
      await expectLater(
        find.byKey(const ValueKey('optics-preview')),
        matchesGoldenFile('goldens/dock-liquid-glass-pressed.png'),
      );
      await press.up();
      await tester.pumpAndSettle();
    },
  );
}
