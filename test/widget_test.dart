import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart'; // Ensure this is the correct import path

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BankBalanceApp());

    // Verify that something exists
    expect(find.byType(BankBalanceApp), findsOneWidget);
  });
}
