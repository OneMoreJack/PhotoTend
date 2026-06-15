import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/main.dart';

void main() {
  testWidgets('renders photo timeline tab', (WidgetTester tester) async {
    await tester.pumpWidget(const RePhotoApp());
    expect(find.text('照片'), findsOneWidget);
  });
}
