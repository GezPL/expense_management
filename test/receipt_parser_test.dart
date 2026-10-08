import 'package:flutter_test/flutter_test.dart';
import 'package:expense_management/features/ocr/models/expense_category.dart';
import 'package:expense_management/features/ocr/services/receipt_parser.dart';

void main() {
  group('ReceiptParser Heuristics Engine Tests', () {
    test('Trích xuất chính xác Tổng tiền với định dạng 150.000 đ', () {
      const sampleReceipt = '''
HIGHLANDS COFFEE
135 Nguyen Hue, Q.1, TP.HCM
Tel: 028 3821 2345
Ngày: 15/08/2026 14:30
Thu ngân: NV01

1. Phin Sữa Đá (L)     45.000
2. Trà Sen Vàng (L)     55.000
3. Bánh Mì Thịt         50.000

Cộng tiền hàng:        150.000
VAT (10%):              15.000
Tổng cộng:             150.000 đ
Tiền khách đưa:        200.000 đ
Tiền thối lại:          50.000 đ

CẢM ƠN QUÝ KHÁCH VÀ HẸN GẶP LẠI!
''';

      final parsed = ReceiptParser.parse(rawText: sampleReceipt);

      expect(parsed.merchantName, 'HIGHLANDS COFFEE');
      expect(parsed.totalAmount, 150000.0);
      expect(parsed.transactionDate.day, 15);
      expect(parsed.transactionDate.month, 8);
      expect(parsed.transactionDate.year, 2026);
      expect(parsed.suggestedCategory, ExpenseCategory.food);
    });

    test('Trích xuất số tiền lớn nhất ở nửa dưới hóa đơn với định dạng 150,000 VND', () {
      const sampleReceipt = '''
HÓA ĐƠN BÁN HÀNG
NHÀ SÁCH FAHASA
Đ/c: 40 Nguyen Hue, Q1
Ngày: 20-09-2026

Bút bi Thiên Long       10,000
Vở kẻ ngang             20,000
Sách Lập trình Flutter 120,000

Tổng tiền: 150,000 VND
''';

      final parsed = ReceiptParser.parse(rawText: sampleReceipt);

      expect(parsed.merchantName, 'NHÀ SÁCH FAHASA');
      expect(parsed.totalAmount, 150000.0);
      expect(parsed.transactionDate.day, 20);
      expect(parsed.transactionDate.month, 9);
      expect(parsed.transactionDate.year, 2026);
      expect(parsed.suggestedCategory, ExpenseCategory.study);
    });

    test('Không chấp nhận ngày ở tương lai, tự động fallback về ngày hiện tại', () {
      const sampleReceipt = '''
CỬA HÀNG TIỆN LỢI
Ngày: 25/12/2030
Tổng: 50.000 đ
''';

      final now = DateTime.now();
      final parsed = ReceiptParser.parse(rawText: sampleReceipt);

      // Vì 25/12/2030 là ngày ở tương lai, hệ thống tự động gán ngày hiện tại
      expect(parsed.transactionDate.day, now.day);
      expect(parsed.transactionDate.month, now.month);
      expect(parsed.transactionDate.year, now.year);
    });

    test('Mặc định ngày hiện tại nếu hóa đơn không chứa ngày tháng', () {
      const sampleReceipt = '''
CỬA HÀNG GEARVN
Chuột Gaming Logitech
Tổng cộng: 450,000
''';

      final now = DateTime.now();
      final parsed = ReceiptParser.parse(rawText: sampleReceipt);

      expect(parsed.merchantName, 'CỬA HÀNG GEARVN');
      expect(parsed.totalAmount, 450000.0);
      expect(parsed.transactionDate.day, now.day);
      expect(parsed.transactionDate.month, now.month);
      expect(parsed.transactionDate.year, now.year);
      expect(parsed.suggestedCategory, ExpenseCategory.gear);
    });

    test('Gợi ý đúng 5 danh mục bắt buộc: Food, Study, Travel, Gear, Entertainment', () {
      // 1. Food
      final foodReceipt = ReceiptParser.parse(rawText: 'HIGHLANDS COFFEE\nPhin Sữa Đá: 35.000');
      expect(foodReceipt.suggestedCategory, ExpenseCategory.food);

      // 2. Study
      final studyReceipt = ReceiptParser.parse(rawText: 'NHÀ SÁCH FAHASA\nVở kẻ ngang: 20.000');
      expect(studyReceipt.suggestedCategory, ExpenseCategory.study);

      // 3. Travel
      final travelReceipt = ReceiptParser.parse(rawText: 'CHUYẾN ĐI GRAB BIKE\nCước phí: 45.000');
      expect(travelReceipt.suggestedCategory, ExpenseCategory.travel);

      // 4. Gear
      final gearReceipt = ReceiptParser.parse(rawText: 'THẾ GIỚI DI ĐỘNG\nCáp sạc Type-C: 150.000');
      expect(gearReceipt.suggestedCategory, ExpenseCategory.gear);

      // 5. Entertainment
      final entertainmentReceipt = ReceiptParser.parse(rawText: 'RẠP CGV CINEMAS\nVé xem phim: 110.000');
      expect(entertainmentReceipt.suggestedCategory, ExpenseCategory.entertainment);

      // 6. Health
      final healthReceipt = ReceiptParser.parse(rawText: 'NHÀ THUỐC LONG CHÂU\nPanadol Extra: 55.000');
      expect(healthReceipt.suggestedCategory, ExpenseCategory.health);

      // 7. Bills
      final billsReceipt = ReceiptParser.parse(rawText: 'TỔNG CÔNG TY ĐIỆN LỰC EVN\nTiền điện tháng 8: 650.000');
      expect(billsReceipt.suggestedCategory, ExpenseCategory.bills);

      // 8. Shopping
      final shoppingReceipt = ReceiptParser.parse(rawText: 'UNIQLO VINCOM\nÁo thun UT: 399.000');
      expect(shoppingReceipt.suggestedCategory, ExpenseCategory.shopping);
    });
  });
}
