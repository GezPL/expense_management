import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/image_thumbnail_helper.dart';
import '../../../data/datasources/local/expense_database_helper.dart';
import '../../../data/models/expense_transaction.dart';
import '../models/expense_category.dart';
import '../services/ocr_service.dart';
import '../services/qr_scanner_service.dart';
import '../services/receipt_parser.dart';
import '../services/viet_qr_parser.dart';

/// ViewModel quản lý dữ liệu và tương tác của màn hình ReviewTransactionScreen (MVVM)
class ReviewTransactionViewModel extends ChangeNotifier {
  final OcrService _ocrService;
  final QrScannerService _qrScannerService;

  ReviewTransactionViewModel({
    OcrService? ocrService,
    QrScannerService? qrScannerService,
  })  : _ocrService = ocrService ?? OcrService(),
        _qrScannerService = qrScannerService ?? QrScannerService();

  bool _isProcessing = false;
  String? _errorMessage;
  int _ocrDurationMs = 0;
  String _rawText = '';
  String? _imagePath;
  bool _isQrDetected = false;
  String? _qrPayload;

  // Controllers cho các TextFormField
  final TextEditingController merchantController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _selectedCategory = ExpenseCategory.food;

  // Getters
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  int get ocrDurationMs => _ocrDurationMs;
  String get rawText => _rawText;
  String? get imagePath => _imagePath;
  DateTime get selectedDate => _selectedDate;
  ExpenseCategory get selectedCategory => _selectedCategory;
  bool get isQrDetected => _isQrDetected;
  String? get qrPayload => _qrPayload;

  String get formattedDate => DateFormat('dd/MM/yyyy').format(_selectedDate);

  /// Khởi tạo và kích hoạt quy trình Quét mã QR hoặc OCR + Regex Parsing tự động từ đường dẫn file ảnh
  Future<void> processReceiptImage(String imagePath) async {
    _imagePath = imagePath;
    _isProcessing = true;
    _errorMessage = null;
    _isQrDetected = false;
    _qrPayload = null;
    notifyListeners();

    try {
      // 1. Bước A: Kiểm tra xem ảnh có chứa mã VietQR / Hóa đơn điện tử không
      VietQrScanResult? qrResult;
      try {
        qrResult = await _qrScannerService.scanImageForQr(imagePath);
      } catch (e) {
        debugPrint('Bỏ qua lỗi quét QR: $e');
      }

      // Nếu phát hiện mã VietQR / Hóa đơn điện tử hợp lệ
      if (qrResult != null && qrResult.isValid) {
        _isQrDetected = true;
        _qrPayload = qrResult.rawPayload;
        _ocrDurationMs = 120; // Phản hồi tức thì từ barcode engine

        merchantController.text = qrResult.merchantName ?? 'Thanh toán VietQR';
        if (qrResult.amount != null && qrResult.amount! > 0) {
          amountController.text = _formatNumber(qrResult.amount!);
        }

        _selectedCategory = qrResult.category;
        _rawText = 'Mã QR đã nhận diện:\n${qrResult.rawPayload}\n\n'
            '${qrResult.note != null ? "Nội dung: ${qrResult.note}\n" : ""}'
            '${qrResult.billNumber != null ? "Số HĐ: ${qrResult.billNumber}\n" : ""}';

        _isProcessing = false;
        notifyListeners();
        return;
      }

      // 2. Bước B: Nếu không có mã QR, chạy Google ML Kit OCR on-device nhận diện chữ
      final ocrResult = await _ocrService.processImage(imagePath);

      if (!ocrResult.isSuccess) {
        _errorMessage = ocrResult.errorMessage ?? 'Không thể nhận diện văn bản.';
        _isProcessing = false;
        notifyListeners();
        return;
      }

      _rawText = ocrResult.rawText;
      _ocrDurationMs = ocrResult.durationMs;

      // 3. Chạy Regex Heuristics Engine để bóc tách thông tin hóa đơn giấy
      final parsedReceipt = ReceiptParser.parse(
        rawText: ocrResult.rawText,
        recognizedText: ocrResult.recognizedText,
        ocrDurationMs: ocrResult.durationMs,
      );

      // 4. Điền sẵn dữ liệu AI vừa trích xuất vào các Controllers
      merchantController.text = parsedReceipt.merchantName;
      amountController.text = _formatNumber(parsedReceipt.totalAmount);

      final now = DateTime.now();
      _selectedDate = parsedReceipt.transactionDate.isAfter(now)
          ? now
          : parsedReceipt.transactionDate;
      _selectedCategory = parsedReceipt.suggestedCategory;

    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi khi phân tích hóa đơn: $e';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Cập nhật danh mục chi tiêu người dùng chọn từ Dropdown
  void setCategory(ExpenseCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Cập nhật ngày giao dịch từ DatePicker (chặn ngày tương lai)
  void setDate(DateTime date) {
    final now = DateTime.now();
    _selectedDate = date.isAfter(now) ? now : date;
    notifyListeners();
  }

  /// Kiểm tra hợp lệ và lấy dữ liệu dạng Map
  Map<String, dynamic>? validateAndGetResult() {
    if (!formKey.currentState!.validate()) {
      return null;
    }

    final cleanedAmountStr = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final amount = double.tryParse(cleanedAmountStr) ?? 0.0;

    return {
      'merchant': merchantController.text.trim(),
      'amount': amount,
      'date': _selectedDate.toIso8601String(),
      'category': _selectedCategory.toDbString(),
      'imagePath': _imagePath,
      'rawText': _rawText,
      'ocrDurationMs': _ocrDurationMs,
      'isQrDetected': _isQrDetected,
    };
  }

  /// Xử lý nén ảnh thu nhỏ, xóa ảnh gốc và lưu bản ghi vào SQLite Database
  Future<ExpenseTransaction?> saveTransactionToDatabase() async {
    if (!formKey.currentState!.validate()) {
      return null;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Nén ảnh thu nhỏ (thumbnail) và xóa ảnh gốc để tiết kiệm bộ nhớ
      String? thumbnailPath;
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        thumbnailPath = await ImageThumbnailHelper.processAndCacheThumbnail(_imagePath!);
      }

      // 2. Chuyển đổi và làm sạch chuỗi số tiền
      final cleanedAmountStr = amountController.text.replaceAll(RegExp(r'[^\d]'), '');
      final amount = double.tryParse(cleanedAmountStr) ?? 0.0;

      // 3. Khởi tạo đối tượng ExpenseTransaction
      final transaction = ExpenseTransaction(
        amount: amount,
        date: _selectedDate,
        merchantName: merchantController.text.trim(),
        category: _selectedCategory,
        thumbnailPath: thumbnailPath,
      );

      // 4. Lưu bản ghi vào bảng transactions trong SQLite
      final int insertedId = await ExpenseDatabaseHelper.instance.insertTransaction(transaction);

      return transaction.copyWith(id: insertedId);
    } catch (e) {
      _errorMessage = 'Lỗi lưu giao dịch vào cơ sở dữ liệu: $e';
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  String _formatNumber(double amount) {
    if (amount == 0) return '';
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(amount.toInt());
  }

  @override
  void dispose() {
    merchantController.dispose();
    amountController.dispose();
    _ocrService.dispose();
    _qrScannerService.dispose();
    super.dispose();
  }
}
