import 'package:flutter_test/flutter_test.dart';
import 'package:expense_management/data/datasources/local/expense_database_helper.dart';
import 'package:expense_management/data/models/expense_transaction.dart';
import 'package:expense_management/features/ocr/models/expense_category.dart';

void main() {
  group('ExpenseCategory Enum & Helper Tests', () {
    test('toDbString chuyển đổi chính xác sang chữ in hoa', () {
      expect(ExpenseCategory.food.toDbString(), 'FOOD');
      expect(ExpenseCategory.study.toDbString(), 'STUDY');
      expect(ExpenseCategory.travel.toDbString(), 'TRAVEL');
      expect(ExpenseCategory.gear.toDbString(), 'GEAR');
      expect(ExpenseCategory.entertainment.toDbString(), 'ENTERTAINMENT');
      expect(ExpenseCategory.shopping.toDbString(), 'SHOPPING');
      expect(ExpenseCategory.health.toDbString(), 'HEALTH');
      expect(ExpenseCategory.bills.toDbString(), 'BILLS');
    });

    test('fromDbString parse chính xác từ chuỗi hoa hoặc thường', () {
      expect(ExpenseCategory.fromDbString('FOOD'), ExpenseCategory.food);
      expect(ExpenseCategory.fromDbString('food'), ExpenseCategory.food);
      expect(ExpenseCategory.fromDbString('STUDY'), ExpenseCategory.study);
      expect(ExpenseCategory.fromDbString('travel'), ExpenseCategory.travel);
      expect(ExpenseCategory.fromDbString('GEAR'), ExpenseCategory.gear);
      expect(ExpenseCategory.fromDbString('entertainment'), ExpenseCategory.entertainment);
      expect(ExpenseCategory.fromDbString('SHOPPING'), ExpenseCategory.shopping);
      expect(ExpenseCategory.fromDbString('health'), ExpenseCategory.health);
      expect(ExpenseCategory.fromDbString('BILLS'), ExpenseCategory.bills);
    });

    test('fromDbString fallback về food nếu chuỗi null hoặc không hợp lệ', () {
      expect(ExpenseCategory.fromDbString(null), ExpenseCategory.food);
      expect(ExpenseCategory.fromDbString(''), ExpenseCategory.food);
      expect(ExpenseCategory.fromDbString('UNKNOWN_CAT'), ExpenseCategory.food);
    });
  });

  group('ExpenseTransaction Model Serialization Tests', () {
    test('toMap và fromMap chuyển đổi hai chiều chính xác', () {
      final now = DateTime(2026, 10, 6, 10, 30);
      final transaction = ExpenseTransaction(
        id: 1,
        amount: 150000.0,
        date: now,
        merchantName: 'Highlands Coffee',
        category: ExpenseCategory.food,
        thumbnailPath: '/app/documents/thumbnails/thumb_123.jpg',
      );

      final map = transaction.toMap();
      expect(map['id'], 1);
      expect(map['amount'], 150000.0);
      expect(map['date'], now.toIso8601String());
      expect(map['merchant_name'], 'Highlands Coffee');
      expect(map['category'], 'FOOD');
      expect(map['thumbnail_path'], '/app/documents/thumbnails/thumb_123.jpg');

      final parsed = ExpenseTransaction.fromMap(map);
      expect(parsed.id, 1);
      expect(parsed.amount, 150000.0);
      expect(parsed.date, now);
      expect(parsed.merchantName, 'Highlands Coffee');
      expect(parsed.category, ExpenseCategory.food);
      expect(parsed.thumbnailPath, '/app/documents/thumbnails/thumb_123.jpg');
    });

    test('ExpenseDatabaseHelper áp dụng Singleton pattern chính xác', () {
      final helper1 = ExpenseDatabaseHelper.instance;
      final helper2 = ExpenseDatabaseHelper();
      expect(identical(helper1, helper2), isTrue);
    });
  });
}

