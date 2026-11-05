import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cleartok_reborn/services/cleartok_account.dart';
import 'package:cleartok_reborn/ui/screens/cleartok_account_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'account_fixture.dart';

Future<AccountFixture> render(
  WidgetTester tester, {
  bool signedIn = false,
  Widget? child,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool keyboard = false,
}) async {
  final fixture = AccountFixture();
  if (signedIn) await fixture.signedIn();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: clearTokTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
          viewInsets: EdgeInsets.only(bottom: keyboard ? 200 : 0),
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('auth-capture'),
        child: ClearTokAccountGate(child: child ?? const Text('protected')),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.dispose);
  });
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> tapText(WidgetTester tester, String value) async {
  final finder = find.text(value).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> credentials(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'test@example.invalid',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'fixture-password');
}

void main() {
  testWidgets('missing configuration never exposes protected child', (
    tester,
  ) async {
    ClearTokAccount.client = null;
    await tester.pumpWidget(
      const MaterialApp(home: ClearTokAccountGate(child: Text('protected'))),
    );
    expect(find.text('protected'), findsNothing);
    expect(find.textContaining('Cần cấu hình Supabase'), findsOneWidget);
  });
  testWidgets(
    'login validates fields, toggles visibility and sanitizes API errors',
    (tester) async {
      final fixture = await render(tester);
      fixture.invalidPassword = true;
      await tapText(tester, 'Đăng nhập');
      expect(find.text('Vui lòng nhập Email ClearTok.'), findsOneWidget);
      expect(fixture.logins, 0);
      await credentials(tester);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .obscureText,
        true,
      );
      await tester.tap(find.byTooltip('Hiện Mật khẩu ClearTok'));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .obscureText,
        false,
      );
      await tapText(tester, 'Đăng nhập');
      expect(find.text('Email hoặc mật khẩu chưa đúng.'), findsOneWidget);
      expect(find.textContaining('private response'), findsNothing);
      expect(find.text('protected'), findsNothing);
    },
  );
  testWidgets(
    'registration validates confirmation and shows email verification',
    (tester) async {
      final fixture = await render(tester);
      await tapText(tester, 'Chưa có tài khoản? Đăng ký');
      await credentials(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'different');
      await tapText(tester, 'Đăng ký');
      expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'fixture-password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'fixture-password',
      );
      await tapText(tester, 'Đăng ký');
      expect(find.text('Xác minh email'), findsOneWidget);
      expect(fixture.checks, 0);
      expect(find.text('protected'), findsNothing);
      await tapText(tester, 'Gửi lại thư xác minh');
      expect(
        fixture.requestBodies.any((body) => body['type'] == 'signup'),
        true,
      );
    },
  );
  testWidgets(
    'forgot password uses callback and confirmation without exposing account existence',
    (tester) async {
      final fixture = await render(tester);
      await tapText(tester, 'Quên mật khẩu?');
      await tester.enterText(
        find.byType(TextFormField),
        'test@example.invalid',
      );
      await tapText(tester, 'Gửi hướng dẫn khôi phục');
      expect(find.textContaining('Nếu email hợp lệ'), findsOneWidget);
      expect(
        fixture.requestBodies.any((body) => body.containsKey('code_challenge')),
        true,
      );
    },
  );
  testWidgets('loading never exposes Studio and ignores duplicate login taps', (
    tester,
  ) async {
    final fixture = await render(tester);
    fixture.hold = Completer<void>();
    await credentials(tester);
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('protected'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    fixture.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('protected'), findsOneWidget);
  });
  testWidgets(
    'profile route preserves child, revokes own device and logs out',
    (tester) async {
      var builds = 0;
      final child = StatefulBuilder(
        builder: (context, setState) {
          builds++;
          return Scaffold(
            body: TextButton(
              onPressed: () => ClearTokAccountGate.openAccount(context),
              child: const Text('Open profile'),
            ),
          );
        },
      );
      final fixture = await render(tester, signedIn: true, child: child);
      final before = builds;
      await tapText(tester, 'Open profile');
      expect(find.text('Thiết bị test'), findsOneWidget);
      expect(builds, before);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(builds, before);
      await tapText(tester, 'Open profile');
      await tapText(tester, 'Thu hồi');
      await tapText(tester, 'Thu hồi');
      expect(fixture.revoked, 1);
      expect(find.text('Chưa thể vào Studio').last, findsOneWidget);
      await tapText(tester, 'Đăng xuất ClearTok');
      expect(fixture.api.auth.currentSession, isNull);
    },
  );
  testWidgets('recovery callback cannot reach Studio until password update', (
    tester,
  ) async {
    final fixture = await render(tester, signedIn: true);
    await fixture.recovery();
    await tester.pumpAndSettle();
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);
    expect(find.text('protected'), findsNothing);
    await fixture.api.auth.refreshSession();
    await tester.pumpAndSettle();
    expect(find.text('protected'), findsNothing);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'new-fixture-password',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'new-fixture-password',
    );
    await tapText(tester, 'Lưu mật khẩu mới');
    expect(fixture.writes, 1);
    expect(find.text('protected'), findsOneWidget);
  });
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'accessible Auth layout fits $size with large type and keyboard',
      (tester) async {
        await render(tester, size: size, textScale: 1.8, keyboard: true);
        await tapText(tester, 'Chưa có tài khoản? Đăng ký');
        await tester.ensureVisible(find.text('Đăng ký'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        expect(
          tester.getSemantics(find.byTooltip('Hiện Xác nhận mật khẩu')),
          isNotNull,
        );
        semantics.dispose();
      },
    );
  }
  testWidgets('auth screenshot at phone size', (tester) async {
    await tester.runAsync(() async {
      final root = Platform.environment['FLUTTER_ROOT']!;
      await (FontLoader('Roboto')..addFont(
            File(
              '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    await render(tester);
    final boundary = find.byType(ClearTokAccountGate);
    expect(boundary, findsOneWidget);
    await tester.runAsync(() async {
      final image =
          await (tester.renderObject(find.byKey(const ValueKey('auth-capture')))
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/ui-previews')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/cleartok-login.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
