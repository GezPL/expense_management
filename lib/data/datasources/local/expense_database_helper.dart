import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../../features/ocr/models/expense_category.dart';
import '../../models/expense_transaction.dart';

/// Database Helper quản lý SQLite cục bộ cho ứng dụng (Áp dụng Singleton Pattern)
class ExpenseDatabaseHelper {
  // Singleton pattern
  static final ExpenseDatabaseHelper instance = ExpenseDatabaseHelper._internal();
  factory ExpenseDatabaseHelper() => instance;
  ExpenseDatabaseHelper._internal();

  static Database? _database;

  // Tên Database và Bảng
  static const String _dbName = 'expense_tracker.db';
  static const int _dbVersion = 1;
  static const String tableTransactions = 'transactions';

  // Tên các cột theo Schema
  static const String colId = 'id';
  static const String colAmount = 'amount';
  static const String colDate = 'date';
  static const String colMerchantName = 'merchant_name';
  static const String colCategory = 'category';
  static const String colThumbnailPath = 'thumbnail_path';

  /// Lấy instance Database, khởi tạo nếu chưa có
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Khởi tạo cơ sở dữ liệu SQLite
  Future<Database> _initDatabase() async {
    // Sử dụng getDatabasesPath hoặc getApplicationDocumentsDirectory
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// Tạo bảng transactions theo đúng định nghĩa Schema
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTransactions (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colAmount REAL NOT NULL,
        $colDate TEXT NOT NULL,
        $colMerchantName TEXT NOT NULL,
        $colCategory TEXT NOT NULL,
        $colThumbnailPath TEXT
      )
    ''');
  }

  // ==========================================
  // CÁC THAO TÁC CRUD (CREATE - READ - UPDATE - DELETE)
  // ==========================================

  /// Thêm một giao dịch mới vào cơ sở dữ liệu
  Future<int> insertTransaction(ExpenseTransaction transaction) async {
    final db = await database;
    return await db.insert(
      tableTransactions,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy danh sách tất cả các giao dịch, sắp xếp theo ngày mới nhất trước
  Future<List<ExpenseTransaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTransactions,
      orderBy: '$colDate DESC, $colId DESC',
    );

    return List.generate(maps.length, (i) => ExpenseTransaction.fromMap(maps[i]));
  }

  /// Lấy chi tiết một giao dịch theo id
  Future<ExpenseTransaction?> getTransactionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTransactions,
      where: '$colId = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ExpenseTransaction.fromMap(maps.first);
    }
    return null;
  }

  /// Cập nhật giao dịch
  Future<int> updateTransaction(ExpenseTransaction transaction) async {
    final db = await database;
    return await db.update(
      tableTransactions,
      transaction.toMap(),
      where: '$colId = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Xóa một giao dịch theo id
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      tableTransactions,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  /// Tính tổng số tiền đã chi tiêu
  Future<double> getTotalExpense() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM($colAmount) as total FROM $tableTransactions');
    final total = result.first['total'];
    if (total != null) {
      return (total as num).toDouble();
    }
    return 0.0;
  }

  /// Lấy tổng chi tiêu gom nhóm theo danh mục
  Future<Map<String, double>> getCategoryTotals() async {
    final db = await database;
    final Map<String, double> totals = {
      for (final cat in ExpenseCategory.values) cat.toDbString(): 0.0,
    };

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT $colCategory, SUM($colAmount) as total 
      FROM $tableTransactions 
      GROUP BY $colCategory
    ''');

    for (final row in results) {
      final category = row[colCategory] as String?;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      if (category != null) {
        final parsedKey = ExpenseCategory.fromDbString(category).toDbString();
        totals[parsedKey] = (totals[parsedKey] ?? 0.0) + total;
      }
    }

    return totals;
  }

  /// Lấy tổng chi tiêu của 7 ngày trong tuần hiện tại (Thứ 2 = 0 -> Chủ Nhật = 6)
  Future<List<double>> getWeeklyExpenses() async {
    final db = await database;
    final List<double> weekly = List.filled(7, 0.0);

    final now = DateTime.now();
    // Monday = 1, Sunday = 7
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final List<Map<String, dynamic>> results = await db.query(
      tableTransactions,
      where: '$colDate >= ? AND $colDate <= ?',
      whereArgs: [monday.toIso8601String(), sunday.toIso8601String()],
    );

    for (final row in results) {
      final dateStr = row[colDate] as String?;
      final amount = (row[colAmount] as num?)?.toDouble() ?? 0.0;
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final index = (date.weekday - 1).clamp(0, 6);
          weekly[index] += amount;
        }
      }
    }

    return weekly;
  }

  /// Lấy dữ liệu chi tiêu theo từng tháng (mặc định 6 tháng gần nhất) phục vụ Trend Line Chart
  Future<List<MonthlyTrendData>> getMonthlyTrendExpenses([int monthsCount = 6]) async {
    final db = await database;
    final now = DateTime.now();
    final List<MonthlyTrendData> trends = [];

    // Duyệt từ tháng xa nhất đến tháng hiện tại
    for (int i = monthsCount - 1; i >= 0; i--) {
      int year = now.year;
      int month = now.month - i;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }

      final startOfMonth = DateTime(year, month, 1);
      final nextMonth = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      final endOfMonth = nextMonth.subtract(const Duration(milliseconds: 1));

      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT SUM($colAmount) as total 
        FROM $tableTransactions 
        WHERE $colDate >= ? AND $colDate <= ?
      ''', [startOfMonth.toIso8601String(), endOfMonth.toIso8601String()]);

      final double total = (results.first['total'] as num?)?.toDouble() ?? 0.0;
      trends.add(MonthlyTrendData(
        label: 'T$month',
        fullLabel: 'Tháng $month/$year',
        year: year,
        month: month,
        amount: total,
      ));
    }

    return trends;
  }

  /// Xóa toàn bộ giao dịch trong Database (dùng cho tính năng Khôi phục Ghi đè)
  Future<int> deleteAllTransactions() async {
    final db = await database;
    return await db.delete(tableTransactions);
  }

  /// Thêm hàng loạt giao dịch bằng SQLite Batch (tối ưu hóa hiệu năng phục hồi)
  Future<void> batchInsertTransactions(List<ExpenseTransaction> transactions) async {
    final db = await database;
    final batch = db.batch();
    for (final transaction in transactions) {
      final map = transaction.toMap();
      map.remove(colId); // Cho phép SQLite tự động cấp phát ID mới
      batch.insert(tableTransactions, map);
    }
    await batch.commit(noResult: true);
  }

  /// Đóng kết nối Database khi cần
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

/// Dữ liệu xu hướng chi tiêu theo tháng
class MonthlyTrendData {
  final String label; // vd: T5, T6, T10
  final String fullLabel; // vd: Tháng 10/2026
  final int year;
  final int month;
  final double amount;

  const MonthlyTrendData({
    required this.label,
    required this.fullLabel,
    required this.year,
    required this.month,
    required this.amount,
  });
}

