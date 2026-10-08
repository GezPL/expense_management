import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/local/expense_database_helper.dart';

/// CustomPainter vẽ Biểu đồ đường xu hướng chi tiêu theo tháng (Monthly Trend Line Chart)
/// Áp dụng đường cong Bezier mềm mại và Gradient phát sáng bằng Canvas toán học thuần túy
class MonthlyTrendLinePainter extends CustomPainter {
  final List<MonthlyTrendData> trendData;
  final double animationValue; // 0.0 -> 1.0 điều khiển hiệu ứng vẽ đường từ trái sang phải
  final int? selectedIndex;

  MonthlyTrendLinePainter({
    required this.trendData,
    required this.animationValue,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trendData.isEmpty) return;

    const double bottomLabelHeight = 28.0;
    const double topPadding = 24.0;
    const double leftAxisPadding = 44.0;
    const double rightPadding = 16.0;

    final double chartWidth = size.width - leftAxisPadding - rightPadding;
    final double chartHeight = size.height - bottomLabelHeight - topPadding;

    // 1. Tìm giá trị chi tiêu lớn nhất để chia tỷ lệ trục Y
    final double rawMax = trendData.fold(0.0, (m, e) => max(m, e.amount));
    final double maxY = rawMax <= 0 ? 100000.0 : _calculateNiceCeil(rawMax);

    // 2. Kẻ các đường lưới mờ ngang (Grid lines) và vẽ nhãn trục Y
    const int gridLineCount = 4;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridLineCount; i++) {
      final double ratio = i / gridLineCount;
      final double y = topPadding + chartHeight * (1.0 - ratio);

      canvas.drawLine(
        Offset(leftAxisPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Nhãn trục Y
      final double yVal = maxY * ratio;
      final String yLabel = _formatYAxisLabel(yVal);
      final textSpan = TextSpan(
        text: yLabel,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftAxisPadding - tp.width - 6, y - tp.height / 2));
    }

    // 3. Tính tọa độ các điểm mốc (Data points)
    final int count = trendData.length;
    final double stepX = count > 1 ? chartWidth / (count - 1) : chartWidth;
    final List<Offset> points = [];

    for (int i = 0; i < count; i++) {
      final double x = leftAxisPadding + i * stepX;
      final double ratio = (trendData[i].amount / maxY).clamp(0.0, 1.0);
      final double y = topPadding + chartHeight * (1.0 - ratio * animationValue);
      points.add(Offset(x, y));

      // Vẽ nhãn tháng ở trục X
      final labelSpan = TextSpan(
        text: trendData[i].label,
        style: TextStyle(
          color: i == count - 1 ? AppColors.primary : Colors.white60,
          fontSize: 11,
          fontWeight: i == count - 1 ? FontWeight.bold : FontWeight.w500,
        ),
      );
      final labelTp = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(
        canvas,
        Offset(x - labelTp.width / 2, size.height - bottomLabelHeight + 6),
      );
    }

    // Nếu không có dữ liệu thực, vẽ đường baseline mờ và thông báo
    if (rawMax <= 0) {
      final emptyText = TextSpan(
        text: 'Chưa có dữ liệu xu hướng',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
      final emptyTp = TextPainter(
        text: emptyText,
        textDirection: TextDirection.ltr,
      )..layout();
      emptyTp.paint(canvas, Offset(leftAxisPadding + chartWidth / 2 - emptyTp.width / 2, topPadding + chartHeight / 2 - emptyTp.height / 2));
      return;
    }

    // 4. Tạo đường cong Bezier mềm mại (Cubic Spline Path)
    final path = Path();
    final fillPath = Path();

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, topPadding + chartHeight);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );

      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Đóng vùng Gradient Fill dưới đường biểu đồ
    fillPath.lineTo(points.last.dx, topPadding + chartHeight);
    fillPath.close();

    // 5. Tô Gradient vùng dưới đường cong (Area Fill)
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.35 * animationValue),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftAxisPadding, topPadding, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 6. Vẽ đường line phát sáng chính (Stroke)
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // 7. Vẽ các điểm nút (Nodes) phát sáng
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final bool isCurrentMonth = (i == count - 1);
      final bool hasExpense = trendData[i].amount > 0;

      if (!hasExpense && !isCurrentMonth) continue;

      // Hào quang ngoài
      final haloPaint = Paint()
        ..color = (isCurrentMonth ? const Color(0xFF38BDF8) : AppColors.primary)
            .withValues(alpha: 0.25 * animationValue)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 8.0, haloPaint);

      // Điểm chính
      final dotPaint = Paint()
        ..color = isCurrentMonth ? const Color(0xFF38BDF8) : AppColors.primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 4.5, dotPaint);

      // Tâm trắng tinh
      final centerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 2.0, centerDot);
    }
  }

  /// Làm tròn trần số tiền đẹp mắt (vd: 120k -> 200k, 1.3tr -> 2tr)
  double _calculateNiceCeil(double value) {
    if (value <= 0) return 100000.0;
    final double magnitude = pow(10, (log(value) / ln10).floor()).toDouble();
    final double normalized = value / magnitude;

    double niceNormalized;
    if (normalized <= 1.0) {
      niceNormalized = 1.0;
    } else if (normalized <= 2.0) {
      niceNormalized = 2.0;
    } else if (normalized <= 5.0) {
      niceNormalized = 5.0;
    } else {
      niceNormalized = 10.0;
    }

    return niceNormalized * magnitude;
  }

  /// Định dạng nhãn số tiền trục Y gọn gàng
  String _formatYAxisLabel(double amount) {
    if (amount <= 0) return '0';
    if (amount >= 1000000) {
      final double mil = amount / 1000000;
      return '${mil.toStringAsFixed(mil % 1 == 0 ? 0 : 1)}M';
    }
    if (amount >= 1000) {
      final int k = (amount / 1000).round();
      return '${k}k';
    }
    return NumberFormat('#,###').format(amount.toInt());
  }

  @override
  bool shouldRepaint(covariant MonthlyTrendLinePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.trendData != trendData ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

