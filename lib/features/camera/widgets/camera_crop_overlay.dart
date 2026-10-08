import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Widget vẽ lớp phủ làm tối xung quanh và chừa lại khung hình chữ nhật sáng ở giữa
class CameraCropOverlay extends StatelessWidget {
  final Rect? cropRect;

  const CameraCropOverlay({super.key, this.cropRect});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: CropOverlayPainter(),
      ),
    );
  }
}

/// CustomPainter vẽ màn mờ và khung cắt hóa đơn sử dụng PathFillType.evenOdd
class CropOverlayPainter extends CustomPainter {
  final double cornerLength;
  final double cornerThickness;
  final double cornerRadius;

  CropOverlayPainter({
    this.cornerLength = 28.0,
    this.cornerThickness = 4.0,
    this.cornerRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Tính toán kích thước khung chữ nhật canh giữa màn hình phù hợp với hóa đơn
    // Chiều rộng bằng khoảng 80% màn hình, chiều cao theo tỷ lệ hóa đơn dài (khoảng 60-65% chiều cao)
    final double cropWidth = size.width * 0.82;
    final double cropHeight = size.height * 0.62;
    final double left = (size.width - cropWidth) / 2;
    final double top = (size.height - cropHeight) / 2.3; // Đẩy nhẹ lên trên để chừa không gian nút chụp
    final Rect cropRect = Rect.fromLTWH(left, top, cropWidth, cropHeight);
    final RRect cropRRect = RRect.fromRectAndRadius(
      cropRect,
      Radius.circular(cornerRadius),
    );

    // 2. Vẽ lớp nền làm mờ xung quanh (Cut-out overlay bằng evenOdd)
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cropRRect)
      ..fillType = PathFillType.evenOdd;

    final Paint overlayPaint = Paint()
      ..color = AppColors.overlayBackground
      ..style = PaintingStyle.fill;

    canvas.drawPath(backgroundPath, overlayPaint);

    // 3. Vẽ viền mờ của khung chữ nhật
    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(cropRRect, borderPaint);

    // 4. Vẽ 4 góc định vị (Corner Brackets) nổi bật
    final Paint cornerPaint = Paint()
      ..color = AppColors.cropCornerAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerThickness
      ..strokeCap = StrokeCap.round;

    final double cl = cornerLength;
    final double r = cornerRadius;

    // Góc trên - trái (Top-Left)
    final Path topLeft = Path()
      ..moveTo(left, top + cl)
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..lineTo(left + cl, top);
    canvas.drawPath(topLeft, cornerPaint);

    // Góc trên - phải (Top-Right)
    final Path topRight = Path()
      ..moveTo(left + cropWidth - cl, top)
      ..lineTo(left + cropWidth - r, top)
      ..arcToPoint(Offset(left + cropWidth, top + r), radius: Radius.circular(r))
      ..lineTo(left + cropWidth, top + cl);
    canvas.drawPath(topRight, cornerPaint);

    // Góc dưới - trái (Bottom-Left)
    final Path bottomLeft = Path()
      ..moveTo(left, top + cropHeight - cl)
      ..lineTo(left, top + cropHeight - r)
      ..arcToPoint(Offset(left + r, top + cropHeight), radius: Radius.circular(r))
      ..lineTo(left + cl, top + cropHeight);
    canvas.drawPath(bottomLeft, cornerPaint);

    // Góc dưới - phải (Bottom-Right)
    final Path bottomRight = Path()
      ..moveTo(left + cropWidth - cl, top + cropHeight)
      ..lineTo(left + cropWidth - r, top + cropHeight)
      ..arcToPoint(Offset(left + cropWidth, top + cropHeight - r), radius: Radius.circular(r))
      ..lineTo(left + cropWidth, top + cropHeight - cl);
    canvas.drawPath(bottomRight, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
