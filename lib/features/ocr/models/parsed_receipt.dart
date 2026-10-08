import 'expense_category.dart';

/// Dữ liệu hóa đơn sau khi được phân tích qua Regex Heuristics Engine
class ParsedReceipt {
  final double totalAmount;
  final DateTime transactionDate;
  final String merchantName;
  final ExpenseCategory suggestedCategory;
  final String rawText;
  final int ocrDurationMs;

  const ParsedReceipt({
    required this.totalAmount,
    required this.transactionDate,
    required this.merchantName,
    required this.suggestedCategory,
    required this.rawText,
    required this.ocrDurationMs,
  });

  ParsedReceipt copyWith({
    double? totalAmount,
    DateTime? transactionDate,
    String? merchantName,
    ExpenseCategory? suggestedCategory,
    String? rawText,
    int? ocrDurationMs,
  }) {
    return ParsedReceipt(
      totalAmount: totalAmount ?? this.totalAmount,
      transactionDate: transactionDate ?? this.transactionDate,
      merchantName: merchantName ?? this.merchantName,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      rawText: rawText ?? this.rawText,
      ocrDurationMs: ocrDurationMs ?? this.ocrDurationMs,
    );
  }
}

