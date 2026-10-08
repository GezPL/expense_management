import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/datasources/local/expense_database_helper.dart';
import '../../data/models/expense_transaction.dart';
import '../utils/budget_helper.dart';
import '../../features/ocr/models/expense_category.dart';

/// Kết quả của tiến trình phục hồi dữ liệu
class BackupRestoreResult {
  final bool success;
  final int importedCount;
  final int totalInFile;
  final String message;

  const BackupRestoreResult({
    required this.success,
    required this.importedCount,
    required this.totalInFile,
    required this.message,
  });
}

/// Tiện ích Sao lưu và Phục hồi dữ liệu ngoại tuyến (Offline Backup & Restore)
class BackupRestoreHelper {
  BackupRestoreHelper._();

  static const String appSignature = 'expense_management';
  static const int currentFormatVersion = 1;

  /// Tạo chuỗi JSON sao lưu toàn diện (Giao dịch + Ngân sách + Hạn mức danh mục)
  static Future<String> generateBackupJson() async {
    final dbHelper = ExpenseDatabaseHelper.instance;
    final transactions = await dbHelper.getAllTransactions();
    final monthlyBudget = await BudgetHelper.getMonthlyBudget();
    final categoryBudgets = await BudgetHelper.getAllCategoryBudgets();

    final Map<String, double> categoryBudgetsMap = {};
    for (final entry in categoryBudgets.entries) {
      categoryBudgetsMap[entry.key.name] = entry.value;
    }

    final backupData = {
      'app': appSignature,
      'version': currentFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'monthly_budget': monthlyBudget,
      'category_budgets': categoryBudgetsMap,
      'transactions_count': transactions.length,
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  /// Thư mục lưu trữ các bản sao lưu trên thiết bị
  static Future<Directory> getBackupDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${docDir.path}/expense_backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Xuất file JSON sao lưu và lưu vào thư mục tài liệu thiết bị
  static Future<File> exportBackupToFile() async {
    final jsonString = await generateBackupJson();
    final dir = await getBackupDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/backup_$timestamp.json');
    return await file.writeAsString(jsonString);
  }

  /// Lấy danh sách các tệp sao lưu đã lưu trong bộ nhớ máy
  static Future<List<File>> getExistingBackupFiles() async {
    try {
      final dir = await getBackupDirectory();
      final entities = dir.listSync();
      final files = entities
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      // Sắp xếp tệp mới nhất lên đầu
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      debugPrint('Lỗi đọc danh sách tệp backup: $e');
      return [];
    }
  }

  /// Phục hồi dữ liệu từ chuỗi JSON
  /// [overwrite] = true: Xóa sạch dữ liệu cũ và ghi đè
  /// [overwrite] = false: Hợp nhất (bỏ qua giao dịch trùng lặp)
  static Future<BackupRestoreResult> restoreFromJsonString(
    String jsonString, {
    bool overwrite = false,
  }) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const BackupRestoreResult(
          success: false,
          importedCount: 0,
          totalInFile: 0,
          message: 'Định dạng dữ liệu không hợp lệ (không phải JSON Object).',
        );
      }

      final transactionsRaw = decoded['transactions'];
      if (transactionsRaw is! List) {
        return const BackupRestoreResult(
          success: false,
          importedCount: 0,
          totalInFile: 0,
          message: 'Tệp không chứa danh sách giao dịch hợp lệ.',
        );
      }

      final dbHelper = ExpenseDatabaseHelper.instance;

      // 1. Khôi phục ngân sách tháng nếu có
      if (decoded['monthly_budget'] is num) {
        final double b = (decoded['monthly_budget'] as num).toDouble();
        if (b > 0) {
          await BudgetHelper.setMonthlyBudget(b);
        }
      }

      // 2. Khôi phục hạn mức từng danh mục nếu có
      if (decoded['category_budgets'] is Map) {
        final catMap = decoded['category_budgets'] as Map;
        for (final entry in catMap.entries) {
          final cat = ExpenseCategory.fromDbString(entry.key.toString());
          final amount = (entry.value as num?)?.toDouble() ?? 0.0;
          if (amount > 0) {
            await BudgetHelper.setCategoryBudget(cat, amount);
          }
        }
      }

      // 3. Xử lý danh sách giao dịch
      final List<ExpenseTransaction> transactionsToRestore = [];
      for (final item in transactionsRaw) {
        if (item is Map<String, dynamic>) {
          try {
            transactionsToRestore.add(ExpenseTransaction.fromMap(item));
          } catch (e) {
            debugPrint('Bỏ qua giao dịch không hợp lệ trong tệp sao lưu: $e');
          }
        }
      }

      if (overwrite) {
        // Chế độ GHI ĐÈ: Xóa toàn bộ dữ liệu hiện có
        await dbHelper.deleteAllTransactions();
        await dbHelper.batchInsertTransactions(transactionsToRestore);

        return BackupRestoreResult(
          success: true,
          importedCount: transactionsToRestore.length,
          totalInFile: transactionsRaw.length,
          message: 'Khôi phục thành công! Đã ghi đè ${transactionsToRestore.length} giao dịch.',
        );
      } else {
        // Chế độ HỢP NHẤT: Bỏ qua giao dịch đã tồn tại
        final currentTransactions = await dbHelper.getAllTransactions();
        final Set<String> existingSignatures = currentTransactions.map((t) {
          return '${t.merchantName.toLowerCase()}_${t.amount}_${t.date.millisecondsSinceEpoch}';
        }).toSet();

        final List<ExpenseTransaction> newItems = [];
        for (final t in transactionsToRestore) {
          final sig = '${t.merchantName.toLowerCase()}_${t.amount}_${t.date.millisecondsSinceEpoch}';
          if (!existingSignatures.contains(sig)) {
            newItems.add(t);
            existingSignatures.add(sig);
          }
        }

        if (newItems.isNotEmpty) {
          await dbHelper.batchInsertTransactions(newItems);
        }

        return BackupRestoreResult(
          success: true,
          importedCount: newItems.length,
          totalInFile: transactionsRaw.length,
          message: 'Hợp nhất thành công! Đã thêm mới ${newItems.length} giao dịch '
              '(bỏ qua ${transactionsToRestore.length - newItems.length} giao dịch đã có).',
        );
      }
    } catch (e) {
      debugPrint('Lỗi giải mã bản sao lưu: $e');
      return BackupRestoreResult(
        success: false,
        importedCount: 0,
        totalInFile: 0,
        message: 'Lỗi đọc tệp sao lưu: $e',
      );
    }
  }
}

