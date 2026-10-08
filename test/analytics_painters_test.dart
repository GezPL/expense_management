import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_management/data/datasources/local/expense_database_helper.dart';
import 'package:expense_management/features/analytics/painters/category_donut_painter.dart';
import 'package:expense_management/features/analytics/painters/monthly_trend_line_painter.dart';
import 'package:expense_management/features/analytics/painters/weekly_bar_painter.dart';

void main() {
  group('CategoryDonutPainter Tests', () {
    test('Khởi tạo và shouldRepaint chính xác khi animation thay đổi', () {
      final totals1 = {'FOOD': 100000.0, 'STUDY': 50000.0};
      final totals2 = {'FOOD': 200000.0, 'STUDY': 50000.0};

      final painter1 = CategoryDonutPainter(
        categoryTotals: totals1,
        animationValue: 0.5,
      );

      final painter2 = CategoryDonutPainter(
        categoryTotals: totals1,
        animationValue: 1.0,
      );

      final painter3 = CategoryDonutPainter(
        categoryTotals: totals2,
        animationValue: 0.5,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isTrue);
      expect(
        painter1.shouldRepaint(CategoryDonutPainter(
          categoryTotals: totals1,
          animationValue: 0.5,
        )),
        isFalse,
      );
    });

    test('Vẽ thành công trên Canvas mà không phát sinh ngoại lệ', () {
      final painter = CategoryDonutPainter(
        categoryTotals: {
          'FOOD': 150000.0,
          'STUDY': 50000.0,
          'TRAVEL': 80000.0,
          'GEAR': 200000.0,
          'ENTERTAINMENT': 70000.0,
        },
        animationValue: 1.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(300, 300);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test('Xử lý trường hợp không có chi tiêu (tổng = 0) mượt mà', () {
      final painter = CategoryDonutPainter(
        categoryTotals: {'FOOD': 0.0, 'STUDY': 0.0},
        animationValue: 1.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(300, 300);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });
  });

  group('WeeklyBarPainter Tests', () {
    test('Khởi tạo với 7 phần tử và assert khi sai số lượng phần tử', () {
      expect(
        () => WeeklyBarPainter(
          dailyExpenses: [10000.0, 20000.0], // Chỉ có 2 phần tử
          animationValue: 1.0,
        ),
        throwsAssertionError,
      );

      final validPainter = WeeklyBarPainter(
        dailyExpenses: [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0],
        animationValue: 1.0,
        currentDayIndex: 2,
      );
      expect(validPainter.dailyExpenses.length, 7);
    });

    test('Vẽ thành công biểu đồ cột 7 ngày trên Canvas', () {
      final painter = WeeklyBarPainter(
        dailyExpenses: [150000.0, 80000.0, 0.0, 220000.0, 190000.0, 500000.0, 300000.0],
        animationValue: 1.0,
        currentDayIndex: 1, // Thứ 3
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(350, 200);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });
  });

  group('MonthlyTrendLinePainter Tests', () {
    test('Khởi tạo và shouldRepaint chính xác khi animation thay đổi', () {
      final data1 = [
        const MonthlyTrendData(label: 'T5', fullLabel: 'Tháng 5/2026', year: 2026, month: 5, amount: 100000.0),
        const MonthlyTrendData(label: 'T6', fullLabel: 'Tháng 6/2026', year: 2026, month: 6, amount: 200000.0),
      ];

      final painter1 = MonthlyTrendLinePainter(
        trendData: data1,
        animationValue: 0.5,
      );

      final painter2 = MonthlyTrendLinePainter(
        trendData: data1,
        animationValue: 1.0,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(
        painter1.shouldRepaint(MonthlyTrendLinePainter(
          trendData: data1,
          animationValue: 0.5,
        )),
        isFalse,
      );
    });

    test('Vẽ thành công biểu đồ đường xu hướng trên Canvas', () {
      final painter = MonthlyTrendLinePainter(
        trendData: [
          const MonthlyTrendData(label: 'T5', fullLabel: 'Tháng 5/2026', year: 2026, month: 5, amount: 500000.0),
          const MonthlyTrendData(label: 'T6', fullLabel: 'Tháng 6/2026', year: 2026, month: 6, amount: 800000.0),
          const MonthlyTrendData(label: 'T7', fullLabel: 'Tháng 7/2026', year: 2026, month: 7, amount: 300000.0),
        ],
        animationValue: 1.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(350, 200);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });

    test('Xử lý trường hợp không có chi tiêu (tất cả các tháng = 0)', () {
      final painter = MonthlyTrendLinePainter(
        trendData: [
          const MonthlyTrendData(label: 'T5', fullLabel: 'Tháng 5/2026', year: 2026, month: 5, amount: 0.0),
          const MonthlyTrendData(label: 'T6', fullLabel: 'Tháng 6/2026', year: 2026, month: 6, amount: 0.0),
        ],
        animationValue: 1.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(350, 200);

      expect(() => painter.paint(canvas, size), returnsNormally);
    });
  });
}

