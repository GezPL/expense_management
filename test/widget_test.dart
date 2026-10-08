import 'package:flutter_test/flutter_test.dart';
import 'package:expense_management/main.dart';

void main() {
  testWidgets('ExpenseManagementApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseManagementApp());
    expect(find.byType(ExpenseManagementApp), findsOneWidget);
  });
}
