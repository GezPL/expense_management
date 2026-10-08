import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../ocr/models/expense_category.dart';

/// CustomPainter vẽ Biểu đồ tròn phân bố danh mục (Donut/Pie Chart) có Animation
class CategoryDonutPainter extends CustomPainter {
  final Map<String, double> categoryTotals;
  final double animationValue;
  final double strokeWidth;

  CategoryDonutPainter({
    required this.categoryTotals,
    required this.animationValue,
    this.strokeWidth = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Tính tổng số tiền của tất cả các danh mục
    final double totalAmount = categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    // 2. Trường hợp chưa có dữ liệu chi tiêu -> Vẽ vòng tròn xám rỗng
    if (totalAmount <= 0) {
      final emptyPaint = Paint()
        ..color = Colors.white10
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, emptyPaint);
      _drawCenterText(canvas, center, '0 đ', 'Chưa có chi tiêu');
      return;
    }

    // 3. Vẽ vòng nền mờ nhẹ bên dưới
    final backgroundTrackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundTrackPaint);

    // 4. Vẽ các cung tròn tương ứng với tỷ lệ phần trăm của từng danh mục
    double startAngle = -pi / 2; // Bắt đầu từ đỉnh 12 giờ
    const double spacingAngle = 0.04; // Khoảng hở nhỏ giữa các lát cắt (tính bằng radian)

    // Đếm số danh mục có phát sinh chi tiêu
    final activeCategories = categoryTotals.entries.where((e) => e.value > 0).toList();
    final bool hasMultiple = activeCategories.length > 1;

    for (final entry in activeCategories) {
      final double amount = entry.value;
      final double percentage = amount / totalAmount;

      // Góc quét tương ứng của danh mục nhân với animationValue (0.0 -> 1.0)
      double sweepAngle = (2 * pi * percentage) * animationValue;

      // Nếu có nhiều hơn 1 danh mục, trừ khoảng hở nhỏ để các lát cắt không dính vào nhau
      if (hasMultiple && sweepAngle > spacingAngle) {
        sweepAngle -= spacingAngle;
      }

      // Xác định màu sắc theo danh mục
      final category = ExpenseCategory.fromDbString(entry.key);
      final slicePaint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round; // Bo tròn 2 đầu cung cho giao diện hiện đại

      // Vẽ cung tròn bằng canvas.drawArc
      canvas.drawArc(
        rect,
        startAngle + (hasMultiple ? spacingAngle / 2 : 0),
        sweepAngle,
        false,
        slicePaint,
      );

      // Cập nhật góc bắt đầu cho lát cắt kế tiếp
      startAngle += (2 * pi * percentage) * animationValue;
    }

    // 5. Vẽ tổng số tiền ở trung tâm của Donut Chart
    final animatedTotal = totalAmount * animationValue;
    final formattedTotal = '${NumberFormat('#,###', 'vi_VN').format(animatedTotal.toInt())} đ';
    _drawCenterText(canvas, center, formattedTotal, 'Tổng chi tiêu');
  }

  /// Vẽ text hiển thị thông số ở trung tâm Donut bằng TextPainter
  void _drawCenterText(Canvas canvas, Offset center, String mainText, String subText) {
    // 1. Text phụ (Sub label)
    final subSpan = TextSpan(
      text: subText,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
    final subPainter = TextPainter(
      text: subSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // 2. Text chính (Số tiền tổng)
    final mainSpan = TextSpan(
      text: mainText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
    final mainPainter = TextPainter(
      text: mainSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Canh giữa cả hai dòng text
    final totalHeight = subPainter.height + mainPainter.height + 4;
    final startY = center.dy - (totalHeight / 2);

    subPainter.paint(
      canvas,
      Offset(center.dx - (subPainter.width / 2), startY),
    );
    mainPainter.paint(
      canvas,
      Offset(center.dx - (mainPainter.width / 2), startY + subPainter.height + 4),
    );
  }

  @override
  bool shouldRepaint(covariant CategoryDonutPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.categoryTotals != categoryTotals;
  }
}
