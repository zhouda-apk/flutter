// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:business_card/main.dart';

void main() {
  testWidgets('Business card displays info', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BusinessCardApp());

    // Verify name and occupation are present
    expect(find.text('周承寬'), findsOneWidget);
    expect(find.text('學生'), findsOneWidget);
  });
}
