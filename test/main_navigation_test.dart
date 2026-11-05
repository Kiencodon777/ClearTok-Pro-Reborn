import 'package:cleartok_reborn/ui/widgets/project_credits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cleartok_reborn/core/remote_payload_config.dart';
import 'package:cleartok_reborn/ui/screens/main_navigation_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';
import 'studio_toolbar_test.dart' show TestDatabase;
import 'account_fixture.dart';
import 'package:cleartok_reborn/ui/screens/cleartok_account_screen.dart';

class TestWebViewPlatform extends InAppWebViewPlatform {
  int creations = 0;
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    creations++;
    return TestWebView(params);
  }
}

class TestWebView extends PlatformInAppWebViewWidget {
  TestWebView(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('webview-surface'));
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnimplementedError();
  @override
  void dispose() {}
}

void main() {
  testWidgets('account route in Studio preserves the existing WebView state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final old = InAppWebViewPlatform.instance;
    final platform = TestWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    final fixture = AccountFixture();
    await fixture.signedIn();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.dispose);
      if (old != null) InAppWebViewPlatform.instance = old;
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: clearTokTheme(),
        home: ClearTokAccountGate(
          child: MainNavigationScreen(
            database: TestDatabase(),
            remoteConfig: RemotePayloadConfig(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final webViewState = tester.state(find.byType(InAppWebView));
    final size = tester.getSize(find.byKey(const ValueKey('webview-surface')));
    await tester.tap(find.text('Studio Reposts').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu Studio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tài khoản ClearTok'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị test'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('TikTok Web').hitTestable().first);
    await tester.pumpAndSettle();
    expect(
      identical(tester.state(find.byType(InAppWebView)), webViewState),
      true,
    );
    expect(tester.getSize(find.byKey(const ValueKey('webview-surface'))), size);
    // Widget factories may run during rebuilds; the retained State above owns the WebView lifecycle.
    expect(find.byType(InAppWebView), findsOneWidget);
  });
  testWidgets('tab changes preserve the WebView and its available size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final old = InAppWebViewPlatform.instance;
    final platform = TestWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (old != null) InAppWebViewPlatform.instance = old;
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: clearTokTheme(),
        home: MainNavigationScreen(
          database: TestDatabase(),
          remoteConfig: RemotePayloadConfig(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final webViewState = tester.state(find.byType(InAppWebView));
    final size = tester.getSize(find.byKey(const ValueKey('webview-surface')));
    expect(find.byType(IndexedStack), findsOneWidget);
    await tester.tap(find.text('Studio Reposts').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('ClearTok Studio Pro'), findsOneWidget);
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

    await tester.tap(find.text('Log').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Log chẩn đoán'), findsOneWidget);
    await tester.tap(find.text('TikTok Web').hitTestable().first);
    await tester.pumpAndSettle();
    expect(
      identical(tester.state(find.byType(InAppWebView)), webViewState),
      isTrue,
    );
    expect(tester.getSize(find.byKey(const ValueKey('webview-surface'))), size);
    expect(tester.takeException(), isNull);
  });
}
