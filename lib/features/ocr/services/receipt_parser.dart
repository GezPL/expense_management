import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/expense_category.dart';
import '../models/parsed_receipt.dart';

/// Regex Heuristics Engine chuyên dụng phân tích hóa đơn bán lẻ Việt Nam
class ReceiptParser {
  ReceiptParser._();

  /// Phân tích văn bản thô kết hợp RecognizedText của ML Kit để trích xuất 3 thông tin chính
  static ParsedReceipt parse({
    required String rawText,
    RecognizedText? recognizedText,
    int ocrDurationMs = 0,
  }) {
    final lines = _extractLines(rawText, recognizedText);

    // 1. Trích xuất Tên cửa hàng (Merchant Name)
    final merchantName = _extractMerchantName(lines, recognizedText);

    // 2. Trích xuất Ngày giao dịch (Transaction Date)
    final transactionDate = _extractTransactionDate(rawText);

    // 3. Trích xuất Tổng tiền (Total Amount)
    final totalAmount = _extractTotalAmount(lines, rawText, recognizedText);

    // 4. Heuristic gợi ý danh mục chi tiêu dựa trên văn bản
    final category = _suggestCategory(merchantName, rawText);

    return ParsedReceipt(
      totalAmount: totalAmount,
      transactionDate: transactionDate,
      merchantName: merchantName,
      suggestedCategory: category,
      rawText: rawText,
      ocrDurationMs: ocrDurationMs,
    );
  }

  // ==========================================
  // NHIỆM VỤ 2.1: TRÍCH XUẤT TỔNG TIỀN (TOTAL AMOUNT)
  // ==========================================

  /// Danh sách từ khóa chỉ tổng tiền trong hóa đơn
  static final List<String> _totalKeywords = [
    'tổng cộng',
    'tong cong',
    'tổng tiền',
    'tong tien',
    'thanh toán',
    'thanh toan',
    'tổng thanh toán',
    'tong thanh toan',
    'cộng tiền hàng',
    'phải trả',
    'phai tra',
    'total',
    'grand total',
    'amount due',
    'net amount',
    'tiền mặt',
  ];

  /// Regex nhận diện số tiền Việt Nam: 150,000 | 150.000 | 150 000 | 150,000 VND | 150.000 đ
  static final RegExp _currencyPattern = RegExp(
    r'(?:^|[^\d])(\d{1,3}(?:[.,\s]\d{3})+(?:\s*(?:VND|VNĐ|vnd|vnđ|đ|Đ))?)(?:[^\d]|$)',
    caseSensitive: false,
  );

  /// Regex số nguyên kèm ký hiệu tiền tệ (vd: 150000 đ, 150000VND)
  static final RegExp _simpleCurrencyPattern = RegExp(
    r'\b(\d{4,9})\s*(?:VND|VNĐ|vnd|vnđ|đ|Đ)\b',
    caseSensitive: false,
  );

  static double _extractTotalAmount(
    List<_LineData> lines,
    String rawText,
    RecognizedText? recognizedText,
  ) {
    if (lines.isEmpty) return 0.0;

    // Danh sách các ứng viên số tiền tìm được kèm trọng số
    final List<_AmountCandidate> candidates = [];

    // Tìm maxY để xác định nửa dưới của hóa đơn
    double maxY = 1.0;
    if (recognizedText != null) {
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          maxY = max(maxY, line.boundingBox.bottom.toDouble());
        }
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowerText = line.text.toLowerCase();

      // Kiểm tra xem dòng này có chứa từ khóa tổng tiền hay không
      final bool hasKeyword = _totalKeywords.any((kw) => lowerText.contains(kw));

      // Tính vị trí tương đối theo chiều dọc (0.0 = đỉnh, 1.0 = đáy hóa đơn)
      final double yRatio = maxY > 1.0 && line.top != null
          ? (line.top! / maxY)
          : (i / lines.length);

      final bool isLowerHalf = yRatio >= 0.45; // Nửa dưới của hóa đơn

      // Tìm kiếm các số tiền trong dòng này
      final lineAmounts = _extractNumbersFromText(line.text);

      // Nếu dòng chứa keyword nhưng số tiền nằm ở dòng kế tiếp (thường gặp khi từ khóa và số tách dòng)
      if (hasKeyword && lineAmounts.isEmpty && i + 1 < lines.length) {
        final nextLineAmounts = _extractNumbersFromText(lines[i + 1].text);
        for (final amount in nextLineAmounts) {
          candidates.add(_AmountCandidate(
            amount: amount,
            hasKeyword: true,
            isLowerHalf: isLowerHalf,
            yRatio: yRatio,
            originalText: lines[i + 1].text,
          ));
        }
      }

      for (final amount in lineAmounts) {
        // Loại bỏ các con số phi thực tế (nhỏ hơn 1,000đ hoặc quá 500 triệu)
        if (amount < 1000 || amount > 500000000) continue;

        candidates.add(_AmountCandidate(
          amount: amount,
          hasKeyword: hasKeyword,
          isLowerHalf: isLowerHalf,
          yRatio: yRatio,
          originalText: line.text,
        ));
      }
    }

    if (candidates.isEmpty) {
      return 0.0;
    }

    // Heuristics ưu tiên:
    // 1. Ưu tiên cao nhất: Dòng có chứa từ khóa tổng tiền và nằm ở nửa dưới
    final keywordLowerHalf = candidates
        .where((c) => c.hasKeyword && c.isLowerHalf)
        .toList();
    if (keywordLowerHalf.isNotEmpty) {
      // Lấy số tiền lớn nhất trong nhóm này (đề phòng có VAT nhỏ hơn)
      keywordLowerHalf.sort((a, b) => b.amount.compareTo(a.amount));
      return keywordLowerHalf.first.amount;
    }

    // 2. Dòng có chứa từ khóa tổng tiền ở bất kỳ vị trí nào
    final keywordAnywhere = candidates.where((c) => c.hasKeyword).toList();
    if (keywordAnywhere.isNotEmpty) {
      keywordAnywhere.sort((a, b) => b.amount.compareTo(a.amount));
      return keywordAnywhere.first.amount;
    }

    // 3. Ưu tiên con số lớn nhất nằm ở nửa dưới của hóa đơn (Yêu cầu đề bài)
    final lowerHalfCandidates = candidates.where((c) => c.isLowerHalf).toList();
    if (lowerHalfCandidates.isNotEmpty) {
      lowerHalfCandidates.sort((a, b) => b.amount.compareTo(a.amount));
      return lowerHalfCandidates.first.amount;
    }

    // 4. Fallback: Con số lớn nhất tìm thấy trong toàn bộ văn bản
    candidates.sort((a, b) => b.amount.compareTo(a.amount));
    return candidates.first.amount;
  }

  /// Trích xuất danh sách các giá trị số từ một chuỗi văn bản
  static List<double> _extractNumbersFromText(String text) {
    final List<double> result = [];

    // Pattern 1: Số có dấu chấm/phẩy ngăn cách hàng nghìn
    final matches = _currencyPattern.allMatches(text);
    for (final match in matches) {
      final rawNum = match.group(1);
      if (rawNum != null) {
        final parsed = _cleanAndParseAmount(rawNum);
        if (parsed != null) result.add(parsed);
      }
    }

    // Pattern 2: Số nguyên kèm đuôi tiền tệ (150000 VND)
    final simpleMatches = _simpleCurrencyPattern.allMatches(text);
    for (final match in simpleMatches) {
      final rawNum = match.group(1);
      if (rawNum != null) {
        final parsed = double.tryParse(rawNum);
        if (parsed != null) result.add(parsed);
      }
    }

    return result;
  }

  /// Làm sạch chuỗi tiền tệ và chuyển sang double (vd: "150.000 đ" -> 150000.0)
  static double? _cleanAndParseAmount(String raw) {
    String cleaned = raw.trim();
    // Bỏ các chữ cái như VND, VNĐ, đ, Đ
    cleaned = cleaned.replaceAll(RegExp(r'[a-zA-Z\sđĐ₫]', caseSensitive: false), '');
    // Bỏ dấu phân cách hàng nghìn (. hoặc ,)
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  // ==========================================
  // NHIỆM VỤ 2.2: TRÍCH XUẤT NGÀY GIAO DỊCH
  // ==========================================

  /// Regex bắt ngày định dạng DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
  static final RegExp _datePattern = RegExp(
    r'\b(0?[1-9]|[12][0-9]|3[01])[\/\-\.](0?[1-9]|1[012])[\/\-\.]((?:20|19)\d{2})\b',
  );

  /// Regex bắt ngày định dạng YYYY/MM/DD
  static final RegExp _dateIsoPattern = RegExp(
    r'\b((?:20|19)\d{2})[\/\-\.](0?[1-9]|1[012])[\/\-\.](0?[1-9]|[12][0-9]|3[01])\b',
  );

  static DateTime _extractTransactionDate(String rawText) {
    try {
      final now = DateTime.now();

      // 1. Tìm định dạng phổ biến DD/MM/YYYY
      final match = _datePattern.firstMatch(rawText);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);
        final date = DateTime(year, month, day);
        // Không chấp nhận ngày trong tương lai (do OCR đọc nhầm hoặc ngày in sai)
        return date.isAfter(now) ? now : date;
      }

      // 2. Tìm định dạng YYYY/MM/DD
      final isoMatch = _dateIsoPattern.firstMatch(rawText);
      if (isoMatch != null) {
        final year = int.parse(isoMatch.group(1)!);
        final month = int.parse(isoMatch.group(2)!);
        final day = int.parse(isoMatch.group(3)!);
        final date = DateTime(year, month, day);
        return date.isAfter(now) ? now : date;
      }
    } catch (e) {
      debugPrint('Lỗi parse ngày tháng: $e');
    }

    // Nếu không tìm thấy hoặc sai định dạng: Mặc định là ngày hiện tại (Yêu cầu đề bài)
    return DateTime.now();
  }

  // ==========================================
  // NHIỆM VỤ 2.3: TRÍCH XUẤT TÊN CỬA HÀNG (MERCHANT NAME)
  // ==========================================

  /// Các từ khóa tiêu đề chung cần loại bỏ khỏi tên cửa hàng
  static final List<String> _ignoreMerchantKeywords = [
    'hóa đơn',
    'hoa don',
    'receipt',
    'bill',
    'phiếu tính tiền',
    'phieu tinh tien',
    'phiếu thanh toán',
    'phieu thanh toan',
    'tax invoice',
    'hóa đơn bán hàng',
    'hoa don ban hang',
    'hóa đơn gtgt',
    'welcome',
    'xin cảm ơn',
    'thank you',
    'cảm ơn quý khách',
    'khách hàng',
    'ngày / date',
    'thu ngân',
    'cashier',
  ];

  static String _extractMerchantName(
    List<_LineData> lines,
    RecognizedText? recognizedText,
  ) {
    if (lines.isEmpty) return 'Cửa hàng không xác định';

    // Heuristic 1: Nếu có RecognizedText, tìm dòng có font chữ lớn nhất (chiều cao boundingBox lớn nhất)
    // nằm ở 30% trên cùng của hóa đơn
    if (recognizedText != null && recognizedText.blocks.isNotEmpty) {
      double maxY = 1.0;
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          maxY = max(maxY, line.boundingBox.bottom.toDouble());
        }
      }

      _LineData? largestLine;
      double maxHeight = 0.0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          final topRatio = maxY > 0 ? (box.top / maxY) : 0.0;

          // Chỉ xét phần trên cùng của hóa đơn (topRatio < 0.35)
          if (topRatio <= 0.35) {
            final text = line.text.trim();
            if (_isValidMerchantLine(text)) {
              if (box.height > maxHeight) {
                maxHeight = box.height.toDouble();
                largestLine = _LineData(
                  text: text,
                  top: box.top.toDouble(),
                  height: box.height.toDouble(),
                );
              }
            }
          }
        }
      }

      if (largestLine != null && largestLine.text.isNotEmpty) {
        return _cleanMerchantName(largestLine.text);
      }
    }

    // Heuristic 2: Lấy dòng văn bản thứ nhất hoặc thứ hai hợp lệ từ trên xuống
    int candidateCount = 0;
    for (int i = 0; i < min(lines.length, 5); i++) {
      final line = lines[i];
      final text = line.text.trim();

      if (_isValidMerchantLine(text)) {
        candidateCount++;
        // Thường dòng 1 hoặc dòng 2 có ý nghĩa nhất
        if (candidateCount == 1 || candidateCount == 2) {
          return _cleanMerchantName(text);
        }
      }
    }

    return 'Cửa hàng tiện lợi';
  }

  /// Kiểm tra một dòng có thể là tên cửa hàng hợp lệ hay không
  static bool _isValidMerchantLine(String text) {
    if (text.length < 3 || text.length > 50) return false;

    final lower = text.toLowerCase();

    // Loại bỏ tiêu đề hóa đơn chung
    if (_ignoreMerchantKeywords.any((kw) => lower.contains(kw))) return false;

    // Loại bỏ số điện thoại (bắt đầu bằng 0 hoặc +84)
    if (RegExp(r'^(?:\+84|0)\d{9,11}$').hasMatch(text.replaceAll(' ', ''))) return false;

    // Loại bỏ địa chỉ, website, mã số thuế
    if (lower.startsWith('đ/c') ||
        lower.startsWith('địa chỉ') ||
        lower.startsWith('address') ||
        lower.startsWith('mst') ||
        lower.startsWith('tel') ||
        lower.contains('www.') ||
        lower.contains('.com') ||
        lower.contains('.vn')) {
      return false;
    }

    // Loại bỏ dòng chứa toàn số hoặc ký tự đặc biệt
    if (RegExp(r'^[0-9\W]+$').hasMatch(text)) return false;

    return true;
  }

  /// Chuẩn hóa tên cửa hàng cho đẹp mắt
  static String _cleanMerchantName(String name) {
    String cleaned = name.trim();
    // Bỏ các ký hiệu dẫn đầu như * - #
    cleaned = cleaned.replaceAll(RegExp(r'^[\*\-\#\:\.]+\s*'), '');
    return cleaned;
  }

  // ==========================================
  // NHIỆM VỤ PHỤ TRỢ: GỢI Ý DANH MỤC CHI TIÊU
  // ==========================================

  static ExpenseCategory _suggestCategory(String merchant, String rawText) {
    final combined = '$merchant $rawText'.toLowerCase();

    // 1. Food (Đồ ăn, uống, thực phẩm)
    if (RegExp(r'(coffee|cà phê|cafe|highlands|phúc long|starbucks|trà sữa|the alley|gong cha|kfc|lotteria|jollibee|mcdonald|nhà hàng|quán ăn|bún|phở|cơm|bánh mì|pizza|burger|lẩu|nướng|bbq|food|bakery|toco|tocotoco|ministop|circle k|7-eleven|winmart|coopmart|bach hoa xanh|siêu thị)').hasMatch(combined)) {
      return ExpenseCategory.food;
    }

    // 2. Study (Học tập)
    if (RegExp(r'(nhà sách|fahasa|tiền sách|văn phòng phẩm|học phí|study|school|university|khóa học|course|sách|book|udemy|coursera|tập|bút)').hasMatch(combined)) {
      return ExpenseCategory.study;
    }

    // 3. Entertainment (Giải trí)
    if (RegExp(r'(cgv|lotte cinema|bhd|galaxy cinema|rạp chiếu phim|cinema|game|steam|playstation|netflix|spotify|billiards|karaoke|vé xem|bảo tàng|sở thú|vinpearl)').hasMatch(combined)) {
      return ExpenseCategory.entertainment;
    }

    // 4. Travel (Đi lại / Du lịch)
    if (RegExp(r'(grab|be|gojek|xăng|petrolimex|pv oil|\bvé xe\b|\bvé tàu\b|vé máy bay|flight|vietnam airlines|vietjet|bamboo|taxi|mai linh|vinasun|hotel|khách sạn|homestay|resort|travel)').hasMatch(combined)) {
      return ExpenseCategory.travel;
    }

    // 5. Gear (Thiết bị)
    if (RegExp(r'(thế giới di động|tgdd|fpt|fptshop|cellphones|phong vũ|hanoicomputer|gear|laptop|chuột|bàn phím|tai nghe|headphone|màn hình|ram|ssd|iphone|samsung|apple|xiaomi|điện thoại)').hasMatch(combined)) {
      return ExpenseCategory.gear;
    }

    // 6. Health (Sức khỏe, Y tế, Thuốc)
    if (RegExp(r'(nhà thuốc|pharmacy|long châu|an khang|pharmacity|bệnh viện|phòng khám|thuốc|bác sĩ|medical|hospital|clinic|y tế)').hasMatch(combined)) {
      return ExpenseCategory.health;
    }

    // 7. Bills (Hóa đơn tiện ích: điện, nước, internet, viễn thông)
    if (RegExp(r'(tiền điện|tiền nước|hóa đơn điện|hóa đơn nước|evn|cấp nước|internet|viettel telecom|vnpt|fpt telecom|truyền hình|chung cư|phí dịch vụ|bill|tiện ích)').hasMatch(combined)) {
      return ExpenseCategory.bills;
    }

    // 8. Shopping (Mua sắm thời trang, sàn TMĐT, phụ kiện)
    if (RegExp(r'(uniqlo|zara|h&m|quần áo|thời trang|fashion|shopee|lazada|tiki|mua sắm|shopping|giày|dép|túi xách|mỹ phẩm|son môi)').hasMatch(combined)) {
      return ExpenseCategory.shopping;
    }

    return ExpenseCategory.food; // Mặc định
  }

  /// Chuyển đổi rawText và recognizedText thành danh sách dòng có thứ tự
  static List<_LineData> _extractLines(
    String rawText,
    RecognizedText? recognizedText,
  ) {
    final List<_LineData> list = [];

    if (recognizedText != null && recognizedText.blocks.isNotEmpty) {
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          list.add(_LineData(
            text: line.text,
            top: line.boundingBox.top.toDouble(),
            height: line.boundingBox.height.toDouble(),
          ));
        }
      }
      // Sắp xếp các dòng từ trên xuống dưới
      list.sort((a, b) => (a.top ?? 0).compareTo(b.top ?? 0));
      return list;
    }

    // Fallback nếu chỉ có rawText thuần túy
    final rawLines = rawText.split('\n');
    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isNotEmpty) {
        list.add(_LineData(text: line));
      }
    }
    return list;
  }
}

/// Dữ liệu bổ trợ cho mỗi dòng văn bản
class _LineData {
  final String text;
  final double? top;
  final double? height;

  _LineData({required this.text, this.top, this.height});
}

/// Ứng viên số tiền tìm được
class _AmountCandidate {
  final double amount;
  final bool hasKeyword;
  final bool isLowerHalf;
  final double yRatio;
  final String originalText;

  _AmountCandidate({
    required this.amount,
    required this.hasKeyword,
    required this.isLowerHalf,
    required this.yRatio,
    required this.originalText,
  });
}

