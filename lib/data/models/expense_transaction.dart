import '../../features/ocr/models/expense_category.dart';

/// Model đại diện cho một bản ghi giao dịch chi tiêu trong bảng 'transactions'
class ExpenseTransaction {
  final int? id;
  final double amount;
  final DateTime date;
  final String merchantName;
  final ExpenseCategory category;
  final String? thumbnailPath;

  const ExpenseTransaction({
    this.id,
    required this.amount,
    required this.date,
    required this.merchantName,
    required this.category,
    this.thumbnailPath,
  });

  /// Chuyển đổi đối tượng sang Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'amount': amount,
      'date': date.toIso8601String(),
      'merchant_name': merchantName,
      'category': category.toDbString(),
      'thumbnail_path': thumbnailPath,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Khởi tạo đối tượng từ dữ liệu Map của SQLite
  factory ExpenseTransaction.fromMap(Map<String, dynamic> map) {
    return ExpenseTransaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      merchantName: map['merchant_name'] as String,
      category: ExpenseCategory.fromDbString(map['category'] as String?),
      thumbnailPath: map['thumbnail_path'] as String?,
    );
  }

  ExpenseTransaction copyWith({
    int? id,
    double? amount,
    DateTime? date,
    String? merchantName,
    ExpenseCategory? category,
    String? thumbnailPath,
  }) {
    return ExpenseTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      merchantName: merchantName ?? this.merchantName,
      category: category ?? this.category,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  @override
  String toString() {
    return 'ExpenseTransaction(id: $id, amount: $amount, date: $date, merchant: $merchantName, category: ${category.name}, thumbnail: $thumbnailPath)';
  }
}

