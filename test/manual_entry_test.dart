import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_management/features/home/views/manual_expense_entry_screen.dart';
import 'package:expense_management/features/ocr/models/expense_category.dart';

void main() {
  group('ManualExpenseEntryScreen Widget Tests', () {
    testWidgets('Hiển thị đầy đủ các trường nhập liệu và 8 danh mục chi tiêu', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ManualExpenseEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề màn hình
      expect(find.text('Nhập chi tiêu thủ công'), findsOneWidget);
      expect(find.text('Số tiền chi tiêu'), findsOneWidget);
      expect(find.text('TÊN CỬA HÀNG / DỊCH VỤ'), findsOneWidget);
      expect(find.text('DANH MỤC CHI TIÊU'), findsOneWidget);
      expect(find.text('THỜI GIAN GIAO DỊCH'), findsOneWidget);
      expect(find.text('GHI CHÚ (TÙY CHỌN)'), findsOneWidget);
      expect(find.text('Xác nhận & Lưu Chi Tiêu'), findsOneWidget);

      // Kiểm tra hiển thị đủ các icon của 8 danh mục
      for (final cat in ExpenseCategory.values) {
        expect(find.byIcon(cat.icon), findsWidgets);
      }
    });

    testWidgets('Kiểm tra validation khi chưa nhập dữ liệu mà bấm Lưu', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ManualExpenseEntryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm nút Lưu khi chưa nhập gì
      final saveButton = find.text('Xác nhận & Lưu Chi Tiêu');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Phải xuất hiện thông báo lỗi validation
      expect(find.text('Vui lòng nhập số tiền'), findsOneWidget);
      expect(find.text('Vui lòng nhập tên cửa hàng hoặc mô tả'), findsOneWidget);
    });
  });
}
