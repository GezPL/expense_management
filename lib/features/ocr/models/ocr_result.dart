import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Kết quả trích xuất văn bản từ OcrService
class OcrResult {
  final String rawText;
  final RecognizedText? recognizedText;
  final int durationMs;
  final bool isSuccess;
  final String? errorMessage;

  const OcrResult({
    required this.rawText,
    this.recognizedText,
    required this.durationMs,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory OcrResult.failure(String error, [int durationMs = 0]) {
    return OcrResult(
      rawText: '',
      recognizedText: null,
      durationMs: durationMs,
      isSuccess: false,
      errorMessage: error,
    );
  }
}

