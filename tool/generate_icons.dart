// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  const int size = 512;
  final canvas = img.Image(width: size, height: size, numChannels: 4);

  // 1. Tạo nền Gradient hiện đại: Deep Slate to Emerald Cyan (#0F172A -> #064E3B)
  for (int y = 0; y < size; y++) {
    final double t = y / size;
    // Gradient từ Deep Slate Navy (15, 23, 42) xuống Dark Emerald (6, 78, 59)
    final int r = (15 * (1 - t) + 6 * t).round();
    final int g = (23 * (1 - t) + 78 * t).round();
    final int b = (42 * (1 - t) + 59 * t).round();
    for (int x = 0; x < size; x++) {
      // Bo góc Squircle (App icon rounded corners)
      final double dx = (x - size / 2).abs() / (size / 2);
      final double dy = (y - size / 2).abs() / (size / 2);
      // Phương trình squircle: dx^4 + dy^4 <= 1
      if (pow(dx, 4) + pow(dy, 4) <= 0.88) {
        canvas.setPixelRgba(x, y, r, g, b, 255);
      } else {
        canvas.setPixelRgba(x, y, 0, 0, 0, 0); // Trong suốt
      }
    }
  }

  // 2. Vẽ Vòng sáng Emerald Accent bao quanh
  img.drawCircle(
    canvas,
    x: 256,
    y: 256,
    radius: 195,
    color: img.ColorRgba8(16, 185, 129, 60), // #10B981 viền mờ
  );

  // 3. Vẽ Ví tiền / Thẻ chi tiêu (Finance Card / Wallet)
  // Thân ví: Hình chữ nhật bo góc lớn
  const int cardLeft = 140;
  const int cardTop = 175;
  const int cardRight = 372;
  const int cardBottom = 345;

  // Vẽ nền ví màu Emerald Gradient sang trọng
  for (int y = cardTop; y <= cardBottom; y++) {
    final double t = (y - cardTop) / (cardBottom - cardTop);
    final int r = (16 * (1 - t) + 5 * t).round();
    final int g = (185 * (1 - t) + 150 * t).round();
    final int b = (129 * (1 - t) + 105 * t).round();
    for (int x = cardLeft; x <= cardRight; x++) {
      // Bán kính bo góc ví
      final bool inLeftTop = (x < cardLeft + 25 && y < cardTop + 25 &&
          (pow(x - (cardLeft + 25), 2) + pow(y - (cardTop + 25), 2) > 625));
      final bool inRightTop = (x > cardRight - 25 && y < cardTop + 25 &&
          (pow(x - (cardRight - 25), 2) + pow(y - (cardTop + 25), 2) > 625));
      final bool inLeftBottom = (x < cardLeft + 25 && y > cardBottom - 25 &&
          (pow(x - (cardLeft + 25), 2) + pow(y - (cardBottom - 25), 2) > 625));
      final bool inRightBottom = (x > cardRight - 25 && y > cardBottom - 25 &&
          (pow(x - (cardRight - 25), 2) + pow(y - (cardBottom - 25), 2) > 625));

      if (!inLeftTop && !inRightTop && !inLeftBottom && !inRightBottom) {
        canvas.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  // 4. Vẽ nắp ví / đường cắt gấp
  img.fillRect(
    canvas,
    x1: cardLeft + 2,
    y1: cardTop + 45,
    x2: cardRight - 2,
    y2: cardTop + 50,
    color: img.ColorRgba8(6, 78, 59, 180),
  );

  // 5. Vẽ Đồng xu vàng Golden Coin (#F59E0B) ở góc phải của ví
  const int coinX = 300;
  const int coinY = 255;
  const int coinRadius = 38;

  // Viền ngoài đồng xu vàng
  img.fillCircle(
    canvas,
    x: coinX,
    y: coinY,
    radius: coinRadius,
    color: img.ColorRgba8(245, 158, 11, 255), // Amber 500
  );
  // Lõi đồng xu
  img.fillCircle(
    canvas,
    x: coinX,
    y: coinY,
    radius: coinRadius - 6,
    color: img.ColorRgba8(251, 191, 36, 255), // Amber 400
  );
  // Ký hiệu tiền tệ / Đô la hoặc Đồng ở tâm đồng xu
  img.fillRect(
    canvas,
    x1: coinX - 4,
    y1: coinY - 18,
    x2: coinX + 4,
    y2: coinY + 18,
    color: img.ColorRgba8(180, 83, 9, 255),
  );
  img.fillRect(
    canvas,
    x1: coinX - 12,
    y1: coinY - 10,
    x2: coinX + 12,
    y2: coinY - 4,
    color: img.ColorRgba8(180, 83, 9, 255),
  );
  img.fillRect(
    canvas,
    x1: coinX - 12,
    y1: coinY + 4,
    x2: coinX + 12,
    y2: coinY + 10,
    color: img.ColorRgba8(180, 83, 9, 255),
  );

  // 6. Vẽ Biểu đồ phân tích tài chính (3 cột tăng trưởng mini bên trái ví)
  const int barBottom = 315;
  // Cột 1 (Thấp)
  img.fillRect(
    canvas,
    x1: 170,
    y1: barBottom - 40,
    x2: 186,
    y2: barBottom,
    color: img.ColorRgba8(255, 255, 255, 210),
  );
  // Cột 2 (Vừa)
  img.fillRect(
    canvas,
    x1: 196,
    y1: barBottom - 70,
    x2: 212,
    y2: barBottom,
    color: img.ColorRgba8(255, 255, 255, 230),
  );
  // Cột 3 (Cao)
  img.fillRect(
    canvas,
    x1: 222,
    y1: barBottom - 100,
    x2: 238,
    y2: barBottom,
    color: img.ColorRgba8(255, 255, 255, 255),
  );

  // 7. Vẽ Tia quét AI Scanner Line (#38BDF8 Sky Blue) tượng trưng cho OCR
  for (int x = cardLeft - 15; x <= cardRight + 15; x++) {
    for (int dy = -2; dy <= 2; dy++) {
      final int alpha = (255 - dy.abs() * 70).clamp(0, 255);
      canvas.setPixelRgba(x, 150 + dy, 56, 189, 248, alpha);
    }
  }

  // Lưu icon 512x512 vào thư mục assets
  Directory('assets/icons').createSync(recursive: true);
  File('assets/icons/app_logo.png').writeAsBytesSync(img.encodePng(canvas));
  print('Đã tạo assets/icons/app_logo.png (512x512)');

  // Các kích thước icon của Android launcher
  final androidSizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in androidSizes.entries) {
    final resized = img.copyResize(
      canvas,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
    print('Đã xuất Android icon: ${entry.key} (${entry.value}x${entry.value})');
  }

  // Xuất cho iOS icon 1024x1024 nếu thư mục tồn tại
  final iosPath = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';
  if (File(iosPath).existsSync()) {
    final ios1024 = img.copyResize(canvas, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);
    File(iosPath).writeAsBytesSync(img.encodePng(ios1024));
    print('Đã cập nhật iOS 1024x1024 AppIcon');
  }

  print('TẤT CẢ ICON LAUNCHER ĐÃ ĐƯỢC CẬP NHẬT THÀNH CÔNG!');
}
