import '../models/expense_category.dart';

/// Kết quả phân tích cú pháp mã VietQR hoặc Hóa đơn điện tử
class VietQrScanResult {
  final bool isValid;
  final double? amount;
  final String? merchantName;
  final String? note;
  final String? billNumber;
  final ExpenseCategory category;
  final String rawPayload;

  const VietQrScanResult({
    required this.isValid,
    this.amount,
    this.merchantName,
    this.note,
    this.billNumber,
    this.category = ExpenseCategory.bills,
    required this.rawPayload,
  });

  @override
  String toString() {
    return 'VietQrScanResult(valid: $isValid, amount: $amount, merchant: $merchantName, note: $note, cat: ${category.name})';
  }
}

/// Trình phân tích cú pháp mã VietQR (EMVCo QR Code), URL thanh toán và hóa đơn điện tử
class VietQrParser {
  VietQrParser._();

  /// Phân tích chuỗi raw từ mã QR (hỗ trợ cả chuẩn EMVCo và URL thanh toán)
  static VietQrScanResult parse(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return const VietQrScanResult(isValid: false, rawPayload: '');
    }

    // 1. Kiểm tra chuẩn EMVCo VietQR (bắt đầu bằng "000201")
    if (text.startsWith('000201') || (text.contains('000201') && text.contains('704'))) {
      return _parseEmvCo(text);
    }

    // 2. Kiểm tra định dạng URL VietQR / E-Invoice / Thanh toán
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return _parseUrlPayment(text);
    }

    // 3. Kiểm tra định dạng Ví điện tử (Ví dụ Momo: 2|99|sdt|ten|email|0|0|sotien|noidung)
    if (text.contains('|')) {
      final momoResult = _parseDelimitedPayload(text);
      if (momoResult != null) return momoResult;
    }

    return VietQrScanResult(
      isValid: false,
      rawPayload: text,
      note: text,
      category: ExpenseCategory.bills,
    );
  }

  /// Phân tích chuẩn EMVCo TLV (Tag-Length-Value)
  static VietQrScanResult _parseEmvCo(String emvString) {
    double? amount;
    String? merchantName;
    String? note;
    String? billNumber;

    try {
      int index = 0;
      final cleanText = emvString.contains('000201')
          ? emvString.substring(emvString.indexOf('000201'))
          : emvString;

      while (index + 4 <= cleanText.length) {
        final tag = cleanText.substring(index, index + 2);
        final length = int.tryParse(cleanText.substring(index + 2, index + 4));

        if (length == null || index + 4 + length > cleanText.length) {
          break;
        }

        final value = cleanText.substring(index + 4, index + 4 + length);
        index += 4 + length;

        switch (tag) {
          case '54': // Số tiền giao dịch (Transaction Amount)
            amount = double.tryParse(value);
            break;
          case '59': // Tên người thụ hưởng / Cửa hàng (Merchant Name)
            merchantName = value.trim();
            break;
          case '62': // Thông tin bổ sung (Additional Data Template)
            final subFields = _parseTlvSubFields(value);
            if (subFields.containsKey('08')) {
              note = subFields['08']; // Mục đích giao dịch / Nội dung chuyển khoản
            }
            if (subFields.containsKey('01')) {
              billNumber = subFields['01']; // Số hóa đơn / Bill number
            }
            if (subFields.containsKey('05') && note == null) {
              note = subFields['05']; // Reference Label
            }
            break;
        }
      }

      final category = _autoDetectCategory(
        merchantName: merchantName ?? '',
        note: note ?? '',
      );

      return VietQrScanResult(
        isValid: amount != null || merchantName != null,
        amount: amount,
        merchantName: merchantName ?? 'Thanh toán VietQR',
        note: note ?? billNumber,
        billNumber: billNumber,
        category: category,
        rawPayload: emvString,
      );
    } catch (_) {
      return VietQrScanResult(
        isValid: false,
        rawPayload: emvString,
      );
    }
  }

  /// Phân tích sub-tags bên trong Tag 62 (Additional Data)
  static Map<String, String> _parseTlvSubFields(String subTlvString) {
    final Map<String, String> result = {};
    int index = 0;
    while (index + 4 <= subTlvString.length) {
      final tag = subTlvString.substring(index, index + 2);
      final length = int.tryParse(subTlvString.substring(index + 2, index + 4));
      if (length == null || index + 4 + length > subTlvString.length) break;

      final value = subTlvString.substring(index + 4, index + 4 + length);
      result[tag] = value.trim();
      index += 4 + length;
    }
    return result;
  }

  /// Phân tích URL thanh toán VietQR hoặc liên kết hóa đơn điện tử
  static VietQrScanResult _parseUrlPayment(String urlStr) {
    try {
      final uri = Uri.parse(urlStr);
      final query = uri.queryParameters;

      double? amount;
      String? merchantName;
      String? note;

      // Tìm kiếm số tiền từ các param phổ biến
      final amountKeys = ['amount', 'tien', 'tongtien', 'total', 'sotien'];
      for (final k in amountKeys) {
        if (query.containsKey(k)) {
          final rawVal = query[k]?.replaceAll(RegExp(r'[^\d.]'), '');
          if (rawVal != null) {
            amount = double.tryParse(rawVal);
            if (amount != null) break;
          }
        }
      }

      // Tìm tên quán hoặc mô tả
      note = query['addInfo'] ?? query['desc'] ?? query['content'] ?? query['noidung'] ?? query['memo'];
      merchantName = query['merchant'] ?? query['store'] ?? query['ten'] ?? uri.host;

      final category = _autoDetectCategory(
        merchantName: merchantName,
        note: note ?? '',
      );

      return VietQrScanResult(
        isValid: true,
        amount: amount,
        merchantName: merchantName,
        note: note,
        category: category,
        rawPayload: urlStr,
      );
    } catch (_) {
      return VietQrScanResult(
        isValid: false,
        rawPayload: urlStr,
      );
    }
  }

  /// Phân tích chuỗi phân cách bởi ký tự | (Ví điện tử Momo/ZaloPay QR)
  static VietQrScanResult? _parseDelimitedPayload(String text) {
    try {
      final parts = text.split('|');
      if (parts.length >= 8) {
        // Chuẩn ví điện tử Momo P2P / Merchant QR
        final merchant = parts[3].trim();
        final amount = double.tryParse(parts[7].replaceAll(RegExp(r'[^\d.]'), ''));
        final note = parts.length > 8 ? parts[8].trim() : null;

        final category = _autoDetectCategory(merchantName: merchant, note: note ?? '');

        return VietQrScanResult(
          isValid: true,
          amount: amount,
          merchantName: merchant.isNotEmpty ? merchant : 'Ví điện tử',
          note: note,
          category: category,
          rawPayload: text,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Tự động nhận diện danh mục thông minh dựa trên tên quán và nội dung
  static ExpenseCategory _autoDetectCategory({
    required String merchantName,
    required String note,
  }) {
    final combined = '$merchantName $note'.toLowerCase();

    // 1. Food / Đồ ăn uống
    if (combined.contains('coffee') ||
        combined.contains('cafe') ||
        combined.contains('tea') ||
        combined.contains('tra sua') ||
        combined.contains('quan an') ||
        combined.contains('nha hang') ||
        combined.contains('com') ||
        combined.contains('pho') ||
        combined.contains('bun') ||
        combined.contains('banh mi') ||
        combined.contains('highlands') ||
        combined.contains('phuc long') ||
        combined.contains('kfc') ||
        combined.contains('lotteria')) {
      return ExpenseCategory.food;
    }

    // 2. Study / Học tập
    if (combined.contains('sach') ||
        combined.contains('book') ||
        combined.contains('fahasa') ||
        combined.contains('hoc phi') ||
        combined.contains('dai hoc') ||
        combined.contains('khoa hoc') ||
        combined.contains('van phong pham')) {
      return ExpenseCategory.study;
    }

    // 3. Travel / Di chuyển
    if (combined.contains('grab') ||
        combined.contains('be ') ||
        combined.contains('xanh sm') ||
        combined.contains('xang') ||
        combined.contains('petrolimex') ||
        combined.contains('ve xe') ||
        combined.contains('ve may bay') ||
        combined.contains('taxi')) {
      return ExpenseCategory.travel;
    }

    // 4. Bills / Hóa đơn
    if (combined.contains('dien') ||
        combined.contains('nuoc') ||
        combined.contains('internet') ||
        combined.contains('viettel') ||
        combined.contains('fpt') ||
        combined.contains('vnpt') ||
        combined.contains('hoa don') ||
        combined.contains('bill') ||
        combined.contains('cuoc')) {
      return ExpenseCategory.bills;
    }

    // 5. Health / Sức khỏe
    if (combined.contains('thuoc') ||
        combined.contains('pharmacity') ||
        combined.contains('long chau') ||
        combined.contains('benh vien') ||
        combined.contains('phong kham') ||
        combined.contains('nha khoa') ||
        combined.contains('y te')) {
      return ExpenseCategory.health;
    }

    // 6. Shopping / Mua sắm
    if (combined.contains('shopee') ||
        combined.contains('lazada') ||
        combined.contains('tiki') ||
        combined.contains('sieu thi') ||
        combined.contains('winmart') ||
        combined.contains('co.op') ||
        combined.contains('bach hoa') ||
        combined.contains('thoi trang') ||
        combined.contains('quan ao')) {
      return ExpenseCategory.shopping;
    }

    // 7. Entertainment / Giải trí
    if (combined.contains('cgv') ||
        combined.contains('lotte cinema') ||
        combined.contains('rap chieu phim') ||
        combined.contains('billiards') ||
        combined.contains('game') ||
        combined.contains('steam') ||
        combined.contains('karaoke')) {
      return ExpenseCategory.entertainment;
    }

    // 8. Gear / Thiết bị
    if (combined.contains('gear') ||
        combined.contains('chuot') ||
        combined.contains('ban phim') ||
        combined.contains('tai nghe') ||
        combined.contains('laptop') ||
        combined.contains('dien thoai') ||
        combined.contains('thegioididong') ||
        combined.contains('fpt shop') ||
        combined.contains('cellphones')) {
      return ExpenseCategory.gear;
    }

    // Mặc định cho VietQR / Hóa đơn điện tử là Bills
    return ExpenseCategory.bills;
  }
}

