import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/main.dart';

void main() {
  testWidgets('renders RePhoto app title', (WidgetTester tester) async {
    await tester.pumpWidget(const RePhotoApp());
    expect(find.text('RePhoto'), findsOneWidget);
  });
}
