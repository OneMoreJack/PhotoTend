import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/main.dart';

void main() {
  testWidgets('app bootstraps with photo timeline tab', (tester) async {
    await tester.pumpWidget(const RePhotoApp());
    expect(find.text('照片'), findsOneWidget);
  });

  testWidgets('language can be changed from settings', (tester) async {
    await tester.pumpWidget(const RePhotoApp());

    expect(find.text('照片'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.text('English'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsOneWidget);
  });
}
