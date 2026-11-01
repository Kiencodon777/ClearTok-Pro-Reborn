import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/ui/widgets/project_credits.dart';

void main() {
  testWidgets('credits preserve exact copy and open a dismissible full-screen view', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: SizedBox(width: 320, child: ProjectCredits())))));
    expect(find.text('Project Name'), findsOneWidget);
    expect(find.text('A D&K Project · 2026'), findsOneWidget);
    expect(find.text('Designed & developed by Viết Kiên and Anh Dũng.', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Project Name'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Đóng credit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Đóng credit'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Đóng credit'), findsNothing);
  });
}
