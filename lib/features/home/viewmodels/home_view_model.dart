import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/budget_helper.dart';
import '../../../data/datasources/local/expense_database_helper.dart';
import '../../../data/models/expense_transaction.dart';
import '../../ocr/models/expense_category.dart';
import '../../ocr/views/review_transaction_screen.dart';

/// ViewModel quản lý dữ liệu và tương tác của Dashboard Trang chủ (MVVM)
class HomeViewModel extends ChangeNotifier {
  final ExpenseDatabaseHelper _dbHelper = ExpenseDatabaseHelper.instance;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  List<ExpenseTransaction> _allTransactions = [];
  List<ExpenseTransaction> _filteredTransactions = [];

  double _totalMonthExpense = 0.0;
  double _monthlyBudget = BudgetHelper.defaultBudget;

  String _searchQuery = '';
  ExpenseCategory? _selectedCategory;

  // Getters
  bool get isLoading => _isLoading;
  List<ExpenseTransaction> get transactions => _filteredTransactions;
  double get totalMonthExpense => _totalMonthExpense;
  double get monthlyBudget => _monthlyBudget;
  String get searchQuery => _searchQuery;
  ExpenseCategory? get selectedCategory => _selectedCategory;

  double get budgetProgress =>
      _monthlyBudget > 0 ? (_totalMonthExpense / _monthlyBudget).clamp(0.0, 1.0) : 0.0;

  bool get isOverBudget => _totalMonthExpense > _monthlyBudget;

  /// Tải toàn bộ danh sách giao dịch và hạn mức ngân sách
  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Tải ngân sách tháng
      _monthlyBudget = await BudgetHelper.getMonthlyBudget();

      // 2. Tải toàn bộ giao dịch từ SQLite
      _allTransactions = await _dbHelper.getAllTransactions();

      // 3. Tính tổng tiền chi tiêu trong tháng hiện tại
      final now = DateTime.now();
      _totalMonthExpense = _allTransactions.where((t) {
        return t.date.year == now.year && t.date.month == now.month;
      }).fold(0.0, (sum, t) => sum + t.amount);

      // 4. Áp dụng bộ lọc
      _applyFilter();
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu Dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cập nhật từ khóa tìm kiếm theo tên quán
  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  /// Cập nhật bộ lọc theo danh mục chi tiêu (null để chọn Tất cả)
  void setCategoryFilter(ExpenseCategory? category) {
    _selectedCategory = category;
    _applyFilter();
    notifyListeners();
  }

  /// Áp dụng đồng thời tìm kiếm và lọc danh mục
  void _applyFilter() {
    _filteredTransactions = _allTransactions.where((t) {
      // Lọc danh mục
      if (_selectedCategory != null && t.category != _selectedCategory) {
        return false;
      }
      // Lọc từ khóa
      if (_searchQuery.isNotEmpty) {
        final merchantMatch = t.merchantName.toLowerCase().contains(_searchQuery);
        final categoryMatch = t.category.displayName.toLowerCase().contains(_searchQuery);
        return merchantMatch || categoryMatch;
      }
      return true;
    }).toList();
  }

  /// Cập nhật hạn mức ngân sách mới
  Future<void> updateMonthlyBudget(double newBudget) async {
    if (newBudget <= 0) return;
    await BudgetHelper.setMonthlyBudget(newBudget);
    _monthlyBudget = newBudget;
    notifyListeners();
  }

  /// Xóa một giao dịch khỏi Database và dọn dẹp file thumbnail trên đĩa
  Future<bool> deleteTransaction(ExpenseTransaction transaction) async {
    if (transaction.id == null) return false;

    try {
      // 1. Xóa trong SQLite
      await _dbHelper.deleteTransaction(transaction.id!);

      // 2. Xóa file thumbnail trên đĩa nếu tồn tại
      if (transaction.thumbnailPath != null) {
        final file = File(transaction.thumbnailPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ [HomeViewModel] Đã xóa file thumbnail: ${transaction.thumbnailPath}');
        }
      }

      // 3. Tải lại dữ liệu
      await loadDashboardData();
      return true;
    } catch (e) {
      debugPrint('❌ [HomeViewModel] Lỗi khi xóa giao dịch: $e');
      return false;
    }
  }

  /// Chọn ảnh hóa đơn có sẵn từ Thư viện thiết bị (Gallery Picker)
  Future<void> pickImageFromGallery(BuildContext context) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null || !context.mounted) return;

      // Chuyển thẳng sang ReviewTransactionScreen để chạy OCR
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewTransactionScreen(imagePath: image.path),
        ),
      );

      // Nếu đã lưu giao dịch thành công, tải lại dữ liệu Dashboard
      if (result != null) {
        await loadDashboardData();
      }
    } catch (e) {
      debugPrint('Lỗi chọn ảnh từ thư viện: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh từ thư viện: $e')),
        );
      }
    }
  }
}

