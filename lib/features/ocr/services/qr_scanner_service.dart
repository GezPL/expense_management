import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'viet_qr_parser.dart';

/// Dịch vụ nhận diện và giải mã mã QR / Barcode trên ảnh bằng Google ML Kit
class QrScannerService {
  final BarcodeScanner _barcodeScanner;

  QrScannerService({BarcodeScanner? scanner})
      : _barcodeScanner = scanner ??
            BarcodeScanner(formats: [
              BarcodeFormat.qrCode,
              BarcodeFormat.dataMatrix,
              BarcodeFormat.pdf417,
            ]);

  /// Quét mã QR từ tệp ảnh và trả về kết quả VietQR nếu có
  Future<VietQrScanResult?> scanImageForQr(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

      for (final barcode in barcodes) {
        final rawValue = barcode.rawValue;
        if (rawValue != null && rawValue.trim().isNotEmpty) {
          final result = VietQrParser.parse(rawValue);
          if (result.isValid) {
            return result;
          }
        }
      }

      // Nếu có mã QR nhưng không khớp chuẩn VietQR, vẫn trả về payload thô
      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
        return VietQrParser.parse(barcodes.first.rawValue!);
      }
    } catch (e) {
      debugPrint('Lỗi quét QR Barcode qua ML Kit: $e');
    }
    return null;
  }

  /// Giải phóng tài nguyên
  Future<void> dispose() async {
    try {
      await _barcodeScanner.close();
    } catch (_) {}
  }
}

