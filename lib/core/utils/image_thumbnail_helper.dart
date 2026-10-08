import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Helper xử lý nén ảnh thu nhỏ (Thumbnail Caching) và giải phóng bộ nhớ
class ImageThumbnailHelper {
  ImageThumbnailHelper._();

  /// Xử lý ảnh gốc: Nén thành ảnh thu nhỏ (thumbnail), lưu vào thư mục lưu trữ ứng dụng,
  /// sau đó xóa file ảnh gốc để tiết kiệm dung lượng bộ nhớ.
  ///
  /// Trả về đường dẫn của file thumbnail đã tạo (dùng để lưu vào database).
  static Future<String?> processAndCacheThumbnail(
    String originalImagePath, {
    int targetWidth = 320,
    int quality = 75,
  }) async {
    try {
      final originalFile = File(originalImagePath);
      if (!await originalFile.exists()) {
        debugPrint('⚠️ [ThumbnailHelper] File ảnh gốc không tồn tại: $originalImagePath');
        return null;
      }

      // 1. Đọc và decode dữ liệu ảnh
      final Uint8List imageBytes = await originalFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        debugPrint('❌ [ThumbnailHelper] Không thể giải mã định dạng ảnh.');
        return null;
      }

      // 2. Nén thu nhỏ ảnh (Resize giữ nguyên tỉ lệ khung hình)
      final img.Image thumbnailImage = img.copyResize(
        decodedImage,
        width: targetWidth,
        interpolation: img.Interpolation.linear,
      );

      // 3. Encode thành định dạng JPG với chất lượng nén tối ưu
      final List<int> thumbnailBytes = img.encodeJpg(thumbnailImage, quality: quality);

      // 4. Lấy thư mục lưu trữ của ứng dụng (Application Storage Directory)
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory thumbnailDir = Directory(join(appDocDir.path, 'thumbnails'));

      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      // 5. Lưu ảnh thu nhỏ với tên định danh timestamp duy nhất
      final String thumbnailFileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String thumbnailPath = join(thumbnailDir.path, thumbnailFileName);
      final File thumbnailFile = File(thumbnailPath);

      await thumbnailFile.writeAsBytes(thumbnailBytes);
      debugPrint('✅ [ThumbnailHelper] Đã lưu thumbnail thành công tại: $thumbnailPath');

      // 6. Xóa ảnh gốc để tiết kiệm dung lượng bộ nhớ thiết bị
      try {
        await originalFile.delete();
        debugPrint('🗑️ [ThumbnailHelper] Đã xóa ảnh gốc thành công: $originalImagePath');
      } catch (e) {
        debugPrint('⚠️ [ThumbnailHelper] Lỗi khi xóa file ảnh gốc: $e');
      }

      return thumbnailPath;
    } catch (e, stack) {
      debugPrint('❌ [ThumbnailHelper] Lỗi trong quá trình xử lý thumbnail: $e\n$stack');
      return null;
    }
  }
}

