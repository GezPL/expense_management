import 'package:flutter_test/flutter_test.dart';
import 'package:expense_management/core/utils/budget_helper.dart';
import 'package:expense_management/data/models/expense_transaction.dart';
import 'package:expense_management/features/ocr/models/expense_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetHelper Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Lấy giá trị ngân sách mặc định 5.000.000 đ', () async {
      final budget = await BudgetHelper.getMonthlyBudget();
      expect(budget, 5000000.0);
    });

    test('Cập nhật và lấy hạn mức ngân sách mới thành công', () async {
      await BudgetHelper.setMonthlyBudget(8000000.0);
      final updatedBudget = await BudgetHelper.getMonthlyBudget();
      expect(updatedBudget, 8000000.0);
    });
  });

  group('Home Filter & Budget Logic Tests', () {
    final sampleList = [
      ExpenseTransaction(
        id: 1,
        amount: 45000.0,
        date: DateTime.now(),
        merchantName: 'Highlands Coffee',
        category: ExpenseCategory.food,
      ),
      ExpenseTransaction(
        id: 2,
        amount: 120000.0,
        date: DateTime.now(),
        merchantName: 'Nhà sách Fahasa',
        category: ExpenseCategory.study,
      ),
      ExpenseTransaction(
        id: 3,
        amount: 35000.0,
        date: DateTime.now(),
        merchantName: 'Grab Bike',
        category: ExpenseCategory.travel,
      ),
    ];

    test('Lọc theo từ khóa tìm kiếm merchantName chính xác', () {
      final query = 'highlands';
      final filtered = sampleList
          .where((t) => t.merchantName.toLowerCase().contains(query))
          .toList();

      expect(filtered.length, 1);
      expect(filtered.first.merchantName, 'Highlands Coffee');
    });

    test('Lọc theo ExpenseCategory chính xác', () {
      final foodFiltered = sampleList
          .where((t) => t.category == ExpenseCategory.food)
          .toList();
      expect(foodFiltered.length, 1);
      expect(foodFiltered.first.category, ExpenseCategory.food);

      final studyFiltered = sampleList
          .where((t) => t.category == ExpenseCategory.study)
          .toList();
      expect(studyFiltered.length, 1);
      expect(studyFiltered.first.category, ExpenseCategory.study);
    });

    test('Tính toán tỷ lệ tiến độ ngân sách và cảnh báo vượt hạn mức', () {
      const budget = 5000000.0;
      const expense = 3500000.0;
      final progress = (expense / budget).clamp(0.0, 1.0);
      expect(progress, 0.7);

      const overExpense = 6000000.0;
      final isOver = overExpense > budget;
      expect(isOver, isTrue);
    });
  });
}

