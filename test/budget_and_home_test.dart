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

    test('Cài đặt và lấy hạn mức riêng cho từng danh mục', () async {
      // Ban đầu chưa có hạn mức
      final initialFoodBudget = await BudgetHelper.getCategoryBudget(ExpenseCategory.food);
      expect(initialFoodBudget, isNull);

      // Cài đặt hạn mức cho Food và Study
      await BudgetHelper.setCategoryBudget(ExpenseCategory.food, 2500000.0);
      await BudgetHelper.setCategoryBudget(ExpenseCategory.study, 1000000.0);

      final foodBudget = await BudgetHelper.getCategoryBudget(ExpenseCategory.food);
      final studyBudget = await BudgetHelper.getCategoryBudget(ExpenseCategory.study);
      final billsBudget = await BudgetHelper.getCategoryBudget(ExpenseCategory.bills);

      expect(foodBudget, 2500000.0);
      expect(studyBudget, 1000000.0);
      expect(billsBudget, isNull);

      // Lấy toàn bộ danh mục đã cấu hình
      final allBudgets = await BudgetHelper.getAllCategoryBudgets();
      expect(allBudgets.length, 2);
      expect(allBudgets[ExpenseCategory.food], 2500000.0);
      expect(allBudgets[ExpenseCategory.study], 1000000.0);

      // Xóa hạn mức danh mục Food
      await BudgetHelper.removeCategoryBudget(ExpenseCategory.food);
      final removedFoodBudget = await BudgetHelper.getCategoryBudget(ExpenseCategory.food);
      expect(removedFoodBudget, isNull);

      final remainingBudgets = await BudgetHelper.getAllCategoryBudgets();
      expect(remainingBudgets.containsKey(ExpenseCategory.food), isFalse);
      expect(remainingBudgets.containsKey(ExpenseCategory.study), isTrue);
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

    test('Tính toán hạn mức danh mục và cảnh báo vượt hạn mức danh mục', () {
      const foodLimit = 2000000.0;
      const foodExpense = 2300000.0;
      final isOverLimit = foodExpense > foodLimit;
      final progress = foodExpense / foodLimit;

      expect(isOverLimit, isTrue);
      expect(progress, greaterThan(1.0));
    });
  });
}
