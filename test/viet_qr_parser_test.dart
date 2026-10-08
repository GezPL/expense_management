import 'package:flutter_test/flutter_test.dart';
import 'package:expense_management/features/ocr/models/expense_category.dart';
import 'package:expense_management/features/ocr/services/viet_qr_parser.dart';

void main() {
  group('VietQrParser Tests', () {
    test('Phân tích chuẩn EMVCo VietQR hợp lệ (Tag 54 số tiền, Tag 59 tên quán, Tag 62 nội dung)', () {
      // Giả lập mã VietQR chuẩn EMVCo
      // Tag 00 len 02: 01
      // Tag 54 len 06: 120000 (120k)
      // Tag 59 len 16: HIGHLANDS COFFEE
      // Tag 62 len 26: Subtag 08 len 22: Thanh toan ca phe sang
      const sampleEmvCo =
          '00020154061200005916HIGHLANDS COFFEE62260822Thanh toan ca phe sang';

      final result = VietQrParser.parse(sampleEmvCo);

      expect(result.isValid, isTrue);
      expect(result.amount, 120000.0);
      expect(result.merchantName, 'HIGHLANDS COFFEE');
      expect(result.note, 'Thanh toan ca phe sang');
      expect(result.category, ExpenseCategory.food);
    });

    test('Phân tích URL VietQR thanh toán tiền học hoặc sách', () {
      const sampleUrl =
          'https://img.vietqr.io/image/vcb-0123456789-compact.png?amount=350000&addInfo=Mua+sach+giao+trinh&merchant=Nha+sach+Fahasa';

      final result = VietQrParser.parse(sampleUrl);

      expect(result.isValid, isTrue);
      expect(result.amount, 350000.0);
      expect(result.merchantName, 'Nha sach Fahasa');
      expect(result.category, ExpenseCategory.study);
    });

    test('Phân tích mã QR thanh toán ví điện tử di chuyển (Grab / Xăng)', () {
      const sampleWallet =
          '2|99|0912345678|Tai xe Grab Bike||0|0|45000|Cuoc xe Grab di hoc';

      final result = VietQrParser.parse(sampleWallet);

      expect(result.isValid, isTrue);
      expect(result.amount, 45000.0);
      expect(result.merchantName, 'Tai xe Grab Bike');
      expect(result.category, ExpenseCategory.travel);
    });

    test('Tự động nhận diện danh mục hóa đơn điện nước (Bills)', () {
      const sampleBill =
          'https://vinvoice.viettel.vn/tracuu?tien=750000&noidung=Tien+dien+thang+10&store=Dien+luc+EVN';

      final result = VietQrParser.parse(sampleBill);

      expect(result.isValid, isTrue);
      expect(result.amount, 750000.0);
      expect(result.category, ExpenseCategory.bills);
    });

    test('Xử lý an toàn khi payload QR rỗng hoặc không đúng định dạng', () {
      final emptyResult = VietQrParser.parse('');
      expect(emptyResult.isValid, isFalse);

      final invalidResult = VietQrParser.parse('Random plain text not QR');
      expect(invalidResult.isValid, isFalse);
    });
  });
}

