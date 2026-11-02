import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/services/diagnostic_log.dart';
import 'package:cleartok_reborn/ui/screens/diagnostic_log_screen.dart';
import 'package:cleartok_reborn/ui/widgets/liquid_glass.dart';

void main() {
  testWidgets('diagnostic screen still copies and clears logs', (tester) async {
    final log = DiagnosticLog.instance;
    log.clear();
    log.record('ui.test', 0);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      log.clear();
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
        MaterialApp(theme: clearTokTheme(), home: const DiagnosticLogScreen()));
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.byTooltip('Sao chép log'));
    await tester.pump();
    expect(copied, contains('ui.test'));
    await tester.tap(find.byTooltip('Xóa log'));
    await tester.pump();
    expect(log.entries, isEmpty);
    expect(find.byType(SelectableText), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
