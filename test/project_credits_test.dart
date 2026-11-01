import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/ui/widgets/project_credits.dart';

void main() {
  testWidgets('credits contain exactly two centered text lines without framing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(width: 320, child: ProjectCreditFooter())))));
    expect(find.text('Viết Kiên & Anh Dũng', findRichText: true), findsOneWidget);
    expect(find.text('Designed & developed · A D&K Project · 2026'), findsOneWidget);
    final texts = tester.widgetList<Text>(find.descendant(
      of: find.byType(ProjectCreditFooter), matching: find.byType(Text))).toList();
    expect(texts.length, 2);
    for (final text in texts) {
      expect(text.textAlign, TextAlign.center);
      expect(text.maxLines, 1);
    }
    expect(find.descendant(of: find.byType(ProjectCreditFooter), matching: find.byType(Icon)), findsNothing);
    expect(find.descendant(of: find.byType(ProjectCreditFooter), matching: find.byType(DecoratedBox)), findsNothing);
    expect(find.text('D&K'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
