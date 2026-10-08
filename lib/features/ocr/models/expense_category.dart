import 'package:flutter/material.dart';

/// Enum phân loại giao dịch chi tiêu của ứng dụng
enum ExpenseCategory {
  food,
  study,
  travel,
  gear,
  entertainment,
  shopping,
  health,
  bills;

  /// Tên hiển thị người dùng
  String get displayName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food (Đồ ăn)';
      case ExpenseCategory.study:
        return 'Study (Học tập)';
      case ExpenseCategory.travel:
        return 'Travel (Đi lại)';
      case ExpenseCategory.gear:
        return 'Gear (Thiết bị)';
      case ExpenseCategory.entertainment:
        return 'Entertainment (Giải trí)';
      case ExpenseCategory.shopping:
        return 'Shopping (Mua sắm)';
      case ExpenseCategory.health:
        return 'Health (Sức khỏe)';
      case ExpenseCategory.bills:
        return 'Bills (Hóa đơn)';
    }
  }

  /// Icon nhận diện trực quan
  IconData get icon {
    switch (this) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.study:
        return Icons.menu_book_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_car_rounded;
      case ExpenseCategory.gear:
        return Icons.devices_rounded;
      case ExpenseCategory.entertainment:
        return Icons.sports_esports_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.health:
        return Icons.medical_services_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
    }
  }

  /// Màu sắc đại diện cho từng danh mục
  Color get color {
    switch (this) {
      case ExpenseCategory.food:
        return const Color(0xFFF59E0B); // Amber
      case ExpenseCategory.study:
        return const Color(0xFF3B82F6); // Blue
      case ExpenseCategory.travel:
        return const Color(0xFF06B6D4); // Cyan
      case ExpenseCategory.gear:
        return const Color(0xFF8B5CF6); // Purple
      case ExpenseCategory.entertainment:
        return const Color(0xFFEC4899); // Pink
      case ExpenseCategory.shopping:
        return const Color(0xFF10B981); // Emerald
      case ExpenseCategory.health:
        return const Color(0xFFEF4444); // Red
      case ExpenseCategory.bills:
        return const Color(0xFF0EA5E9); // Sky Blue
    }
  }

  /// Helper: Chuyển enum thành chuỗi String để lưu trữ vào SQLite Database
  String toDbString() {
    return name.toUpperCase(); // 'FOOD', 'STUDY', 'TRAVEL', 'GEAR', 'ENTERTAINMENT', 'SHOPPING', 'HEALTH', 'BILLS'
  }

  /// Helper: Parse chuỗi String từ Database ngược lại thành enum (có fallback an toàn)
  static ExpenseCategory fromDbString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ExpenseCategory.food; // Mặc định nếu null
    }

    final normalized = value.trim().toLowerCase();
    for (final category in ExpenseCategory.values) {
      if (category.name.toLowerCase() == normalized ||
          category.toDbString().toLowerCase() == normalized) {
        return category;
      }
    }

    return ExpenseCategory.food; // Mặc định an toàn
  }
}
