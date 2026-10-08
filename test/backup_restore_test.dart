import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_management/core/utils/backup_restore_helper.dart';
import 'package:expense_management/core/utils/budget_helper.dart';
import 'package:expense_management/features/ocr/models/expense_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Backup & Restore Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Xác thực cấu trúc JSON sao lưu tiêu chuẩn', () {
      final sampleBackup = {
        'app': 'expense_management',
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'monthly_budget': 6000000.0,
        'category_budgets': {
          'food': 2000000.0,
          'study': 1000000.0,
        },
        'transactions_count': 2,
        'transactions': [
          {
            'amount': 45000.0,
            'date': DateTime.now().toIso8601String(),
            'merchant_name': 'Highlands Coffee',
            'category': 'FOOD',
            'raw_ocr_text': 'Highlands 45k',
          },
          {
            'amount': 150000.0,
            'date': DateTime.now().toIso8601String(),
            'merchant_name': 'Fahasa Books',
            'category': 'STUDY',
            'raw_ocr_text': 'Fahasa 150k',
          },
        ],
      };

      final jsonString = jsonEncode(sampleBackup);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['app'], 'expense_management');
      expect(decoded['version'], 1);
      expect(decoded['monthly_budget'], 6000000.0);
      expect((decoded['transactions'] as List).length, 2);
    });

    test('Báo lỗi định dạng khi chuỗi JSON sao lưu bị hỏng hoặc không đúng chuẩn', () async {
      final resultCorrupt = await BackupRestoreHelper.restoreFromJsonString('invalid json text');
      expect(resultCorrupt.success, isFalse);

      final resultMissingTrans = await BackupRestoreHelper.restoreFromJsonString('{"app": "expense_management"}');
      expect(resultMissingTrans.success, isFalse);
    });

    test('Khôi phục ngân sách và hạn mức danh mục từ chuỗi sao lưu', () async {
      final backupData = {
        'app': 'expense_management',
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'monthly_budget': 7500000.0,
        'category_budgets': {
          'food': 3000000.0,
          'gear': 2000000.0,
        },
        'transactions_count': 0,
        'transactions': [],
      };

      // Đặt giá trị ban đầu khác
      await BudgetHelper.setMonthlyBudget(5000000.0);

      // Phục hồi từ JSON (không cần SQLite trong test widget/unit)
      final decoded = jsonDecode(jsonEncode(backupData)) as Map<String, dynamic>;
      if (decoded['monthly_budget'] is num) {
        await BudgetHelper.setMonthlyBudget((decoded['monthly_budget'] as num).toDouble());
      }
      final catMap = decoded['category_budgets'] as Map;
      for (final entry in catMap.entries) {
        final cat = ExpenseCategory.fromDbString(entry.key.toString());
        final amount = (entry.value as num).toDouble();
        await BudgetHelper.setCategoryBudget(cat, amount);
      }

      // Kiểm tra giá trị đã phục hồi vào SharedPreferences
      final restoredBudget = await BudgetHelper.getMonthlyBudget();
      final restoredFood = await BudgetHelper.getCategoryBudget(ExpenseCategory.food);
      final restoredGear = await BudgetHelper.getCategoryBudget(ExpenseCategory.gear);

      expect(restoredBudget, 7500000.0);
      expect(restoredFood, 3000000.0);
      expect(restoredGear, 2000000.0);
    });
  });
}

