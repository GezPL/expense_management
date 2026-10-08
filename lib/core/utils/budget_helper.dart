import 'package:shared_preferences/shared_preferences.dart';
import '../../features/ocr/models/expense_category.dart';

/// Helper quản lý hạn mức ngân sách chi tiêu hàng tháng và từng danh mục qua SharedPreferences
class BudgetHelper {
  BudgetHelper._();

  static const String _budgetKey = 'user_monthly_budget';
  static const String _categoryBudgetPrefix = 'category_budget_';
  static const double defaultBudget = 5000000.0; // 5.000.000 VNĐ mặc định

  /// Lấy hạn mức ngân sách tháng đã cài đặt
  static Future<double> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? defaultBudget;
  }

  /// Cập nhật hạn mức ngân sách mới
  static Future<bool> setMonthlyBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setDouble(_budgetKey, amount);
  }

  /// Lấy hạn mức của một danh mục cụ thể (null nếu chưa thiết lập)
  static Future<double?> getCategoryBudget(ExpenseCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_categoryBudgetPrefix${category.name}');
  }

  /// Cài đặt hạn mức cho một danh mục cụ thể
  static Future<bool> setCategoryBudget(ExpenseCategory category, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setDouble('$_categoryBudgetPrefix${category.name}', amount);
  }

  /// Xóa hạn mức cho một danh mục cụ thể (trở về không giới hạn)
  static Future<bool> removeCategoryBudget(ExpenseCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove('$_categoryBudgetPrefix${category.name}');
  }

  /// Lấy tất cả hạn mức danh mục đã được người dùng thiết lập
  static Future<Map<ExpenseCategory, double>> getAllCategoryBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<ExpenseCategory, double> result = {};
    for (final category in ExpenseCategory.values) {
      final value = prefs.getDouble('$_categoryBudgetPrefix${category.name}');
      if (value != null && value > 0) {
        result[category] = value;
      }
    }
    return result;
  }
}
