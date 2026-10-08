import 'package:shared_preferences/shared_preferences.dart';

/// Helper quản lý hạn mức ngân sách chi tiêu hàng tháng qua SharedPreferences
class BudgetHelper {
  BudgetHelper._();

  static const String _budgetKey = 'user_monthly_budget';
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
}

