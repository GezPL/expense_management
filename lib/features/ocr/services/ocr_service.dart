import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ocr_result.dart';

/// Dịch vụ OCR trích xuất văn bản ngoại tuyến (Offline On-device) sử dụng Google ML Kit
class OcrService {
  final TextRecognizer _textRecognizer;

  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
      : _textRecognizer = TextRecognizer(script: script);

  /// Trích xuất toàn bộ khối văn bản (String) đọc được từ đường dẫn file ảnh
  /// Đo tốc độ xử lý on-device (thường đạt mốc < 100ms trên thiết bị di động)
  Future<String> extractRawText(String imagePath) async {
    final result = await processImage(imagePath);
    return result.rawText;
  }

  /// Trích xuất văn bản kèm theo cấu trúc chi tiết (RecognizedText, blocks, lines, bounding boxes)
  Future<OcrResult> processImage(String imagePath) async {
    final stopwatch = Stopwatch()..start();

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        stopwatch.stop();
        return OcrResult.failure(
          'Tệp hình ảnh không tồn tại tại: $imagePath',
          stopwatch.elapsedMilliseconds,
        );
      }

      // Khởi tạo InputImage từ file path
      final inputImage = InputImage.fromFilePath(imagePath);

      // Xử lý nhận diện văn bản on-device
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;

      debugPrint('⚡ [OcrService] Xử lý OCR hoàn tất trong ${duration}ms');

      return OcrResult(
        rawText: recognizedText.text,
        recognizedText: recognizedText,
        durationMs: duration,
        isSuccess: true,
      );
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('❌ [OcrService] Lỗi khi nhận diện văn bản: $e\n$stack');
      return OcrResult.failure(
        'Lỗi nhận diện văn bản: $e',
        stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Giải phóng tài nguyên ML Kit
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

