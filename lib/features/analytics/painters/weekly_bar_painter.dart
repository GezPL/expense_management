import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../../core/constants/app_colors.dart';

/// CustomPainter vẽ Biểu đồ cột chi tiêu hàng tuần (Weekly Bar Chart) bằng Canvas thuần
class WeeklyBarPainter extends CustomPainter {
  final List<double> dailyExpenses; // 7 phần tử ứng với Thứ 2 -> Chủ Nhật
  final double animationValue;     // 0.0 -> 1.0 điều khiển hiệu ứng mọc lên của cột
  final int? currentDayIndex;       // Index ngày hôm nay (0 = T2, 6 = CN) để làm nổi bật cột

  WeeklyBarPainter({
    required this.dailyExpenses,
    required this.animationValue,
    this.currentDayIndex,
  }) : assert(dailyExpenses.length == 7, 'dailyExpenses phải có đúng 7 phần tử.');

  static const List<String> _weekLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  void paint(Canvas canvas, Size size) {
    const double bottomLabelHeight = 28.0;
    const double topPadding = 20.0;
    const double leftAxisPadding = 42.0;

    final double chartWidth = size.width - leftAxisPadding;
    final double chartHeight = size.height - bottomLabelHeight - topPadding;

    // 1. Tự động tính toán giá trị lớn nhất (max value) để chia tỷ lệ trục Y
    final double rawMax = dailyExpenses.fold(0.0, (m, e) => max(m, e));
    // Nếu cả tuần chưa có chi tiêu, đặt mốc mặc định 100.000 đ
    final double maxY = rawMax <= 0 ? 100000.0 : _calculateNiceCeil(rawMax);

    // 2. Vẽ các đường lưới mờ (Grid lines) nằm ngang và nhãn trục Y
    const int gridLineCount = 4; // 0, 33%, 66%, 100%
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridLineCount; i++) {
      final double ratio = i / gridLineCount;
      final double y = topPadding + chartHeight * (1.0 - ratio);

      // Kẻ đường lưới ngang
      canvas.drawLine(
        Offset(leftAxisPadding, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Vẽ nhãn số tiền trục Y bằng TextPainter
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
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(leftAxisPadding - tp.width - 6, y - (tp.height / 2)));
    }

    // 3. Vẽ 7 cột tương ứng với 7 ngày trong tuần
    final double colSlotWidth = chartWidth / 7;
    final double barWidth = min(colSlotWidth * 0.52, 26.0); // Chiều rộng mỗi cột

    for (int i = 0; i < 7; i++) {
      final double amount = dailyExpenses[i];
      final double xCenter = leftAxisPadding + (i * colSlotWidth) + (colSlotWidth / 2);
      final double barLeft = xCenter - (barWidth / 2);

      // Chiều cao cột tương ứng nhân với animationValue
      final double barRatio = (amount / maxY).clamp(0.0, 1.0);
      final double barHeight = chartHeight * barRatio * animationValue;
      final double barTop = topPadding + chartHeight - barHeight;
      final double barBottom = topPadding + chartHeight;

      final bool isToday = (currentDayIndex != null && currentDayIndex == i);

      // Vẽ cột bo góc phía trên (RRect)
      final barRect = Rect.fromLTRB(barLeft, barTop, barLeft + barWidth, barBottom);
      final barRRect = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      // Màu sắc cột: Cột hôm nay có màu nhấn nổi bật (Emerald hoặc Amber)
      final Paint barPaint = Paint()..style = PaintingStyle.fill;
      if (amount > 0) {
        if (isToday) {
          barPaint.color = AppColors.focusRing; // Vàng nổi bật cho ngày hôm nay
        } else {
          barPaint.color = AppColors.primary;   // Xanh ngọc chủ đạo
        }
      } else {
        // Cột ngày 0đ vẽ vệt mờ tối thiểu
        barPaint.color = Colors.white.withValues(alpha: 0.05);
      }

      if (barHeight > 0) {
        canvas.drawRRect(barRRect, barPaint);
      } else {
        // Vẽ vạch tối thiểu ở đáy cột
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(barLeft, barBottom - 2, barLeft + barWidth, barBottom),
            const Radius.circular(2),
          ),
          barPaint,
        );
      }

      // 4. Vẽ nhãn trục X (T2, T3... CN)
      final labelSpan = TextSpan(
        text: _weekLabels[i],
        style: TextStyle(
          color: isToday ? AppColors.focusRing : Colors.white60,
          fontSize: 12,
          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
        ),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(xCenter - (labelPainter.width / 2), size.height - bottomLabelHeight + 6),
      );
    }
  }

  /// Làm tròn mốc cao nhất của trục Y lên số đẹp (Nice round number)
  static double _calculateNiceCeil(double value) {
    if (value <= 0) return 100000.0;
    // Tăng nhẹ 15% để cột cao nhất không bị chạm trần biểu đồ
    final target = value * 1.15;
    final magnitude = pow(10, (log(target) / ln10).floor()).toDouble();
    final factor = target / magnitude;

    if (factor <= 2) return 2 * magnitude;
    if (factor <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  /// Định dạng nhãn trục Y ngắn gọn (vd: 50k, 200k, 1M)
  static String _formatYAxisLabel(double value) {
    if (value <= 0) return '0';
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return NumberFormat('#,###').format(value.toInt());
  }

  @override
  bool shouldRepaint(covariant WeeklyBarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.dailyExpenses != dailyExpenses ||
        oldDelegate.currentDayIndex != currentDayIndex;
  }
}
