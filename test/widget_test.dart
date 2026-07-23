import 'package:flutter_test/flutter_test.dart';
import 'package:fleuron/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is present
    expect(find.text('Team Dashboard'), findsOneWidget);
  });
}
