import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/main.dart';

void main() {
  testWidgets('app bootstraps with RePhoto title', (tester) async {
    await tester.pumpWidget(const RePhotoApp());
    expect(find.text('RePhoto'), findsOneWidget);
  });
}
