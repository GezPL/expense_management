import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../models/expense_category.dart';
import '../viewmodels/review_transaction_view_model.dart';

/// Màn hình Đánh giá tương tác (Interactive Review Screen) hiển thị sau khi quét OCR
class ReviewTransactionScreen extends StatefulWidget {
  final String imagePath;

  const ReviewTransactionScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<ReviewTransactionScreen> createState() => _ReviewTransactionScreenState();
}

class _ReviewTransactionScreenState extends State<ReviewTransactionScreen> {
  late final ReviewTransactionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ReviewTransactionViewModel();
    // Bắt đầu quá trình OCR và bóc tách ngay khi mở màn hình
    _viewModel.processReceiptImage(widget.imagePath);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Mở hộp thoại chọn ngày giao dịch (khóa không cho phép chọn ngày tương lai)
  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _viewModel.selectedDate.isAfter(now)
        ? now
        : _viewModel.selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now, // Không thể chọn ngày ở tương lai
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _viewModel.setDate(picked);
    }
  }

  /// Hiển thị toàn bộ văn bản OCR thô (Raw text) để người dùng đối chiếu khi cần
  void _showRawTextBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Văn bản gốc từ AI (Raw OCR Text)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      _viewModel.rawText.isEmpty
                          ? '(Không tìm thấy văn bản)'
                          : _viewModel.rawText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Xử lý bấm nút "Xác nhận & Lưu"
  Future<void> _handleConfirmAndSave(BuildContext context) async {
    final savedTransaction = await _viewModel.saveTransactionToDatabase();
    if (!context.mounted) return;

    if (savedTransaction != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Lưu thành công!', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Giao dịch đã được lưu vĩnh viễn vào SQLite Database:',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              _buildSummaryRow('Mã GD:', '#${savedTransaction.id}'),
              _buildSummaryRow('Cửa hàng:', savedTransaction.merchantName),
              _buildSummaryRow(
                'Số tiền:',
                '${NumberFormat('#,###', 'vi_VN').format(savedTransaction.amount)} đ',
              ),
              _buildSummaryRow('Ngày:', _viewModel.formattedDate),
              _buildSummaryRow('Danh mục:', savedTransaction.category.displayName),
              if (savedTransaction.thumbnailPath != null)
                _buildSummaryRow('Thumbnail:', 'Đã nén đệm & giải phóng ảnh gốc'),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx); // Đóng dialog
                Navigator.pop(context, savedTransaction); // Trả kết quả về
              },
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      );
    } else if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReviewTransactionViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Kiểm tra & Xác nhận',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          actions: [
            Consumer<ReviewTransactionViewModel>(
              builder: (_, vm, child) {
                if (vm.isProcessing) return const SizedBox.shrink();
                return TextButton.icon(
                  onPressed: () => _showRawTextBottomSheet(context),
                  icon: const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                  label: const Text('Raw Text', style: TextStyle(color: AppColors.primary)),
                );
              },
            ),
          ],
        ),
        body: Consumer<ReviewTransactionViewModel>(
          builder: (context, vm, child) {
            // 1. Trạng thái đang quét OCR
            if (vm.isProcessing) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.file(
                            File(widget.imagePath),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AI đang bóc tách hóa đơn...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Google ML Kit đang xử lý ngoại tuyến on-device',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            // 2. Trạng thái lỗi
            if (vm.errorMessage != null && vm.rawText.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        vm.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => vm.processReceiptImage(widget.imagePath),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 3. Form Đánh giá tương tác hoàn chỉnh
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Form(
                      key: vm.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ảnh hóa đơn thu nhỏ kèm chip thông số AI OCR
                          _buildReceiptPreviewCard(context, vm),

                          const SizedBox(height: 20),

                          const Text(
                            'THÔNG TIN BÓC TÁCH TỰ ĐỘNG',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 1. Trường TỔNG TIỀN (Total Amount)
                          _buildAmountField(vm),

                          const SizedBox(height: 16),

                          // 2. Trường TÊN CỬA HÀNG (Merchant Name)
                          _buildMerchantField(vm),

                          const SizedBox(height: 16),

                          // 3. Trường NGÀY GIAO DỊCH (Transaction Date)
                          _buildDateField(context, vm),

                          const SizedBox(height: 16),

                          // 4. Trường CHỌN DANH MỤC CHI TIÊU (Dropdown Category)
                          _buildCategoryDropdown(vm),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // Nút "Xác nhận & Lưu" ở cạnh dưới màn hình
                _buildBottomActionBar(context, vm),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Card xem nhanh ảnh hóa đơn kèm chip tốc độ xử lý OCR
  Widget _buildReceiptPreviewCard(BuildContext context, ReviewTransactionViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(widget.imagePath),
              width: 55,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            'AI OCR: ${vm.ocrDurationMs}ms',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'On-device',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dữ liệu đã trích xuất từ hóa đơn. Bạn có thể sửa đổi nếu cần.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// TextFormField nhập Tổng tiền
  Widget _buildAmountField(ReviewTransactionViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tổng tiền thanh toán',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: vm.amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            prefixIcon: const Icon(Icons.payments_rounded, color: AppColors.primary),
            suffixText: 'VNĐ',
            suffixStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            hintText: '0',
            hintStyle: const TextStyle(color: Colors.white24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Vui lòng nhập số tiền';
            }
            final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
            if (cleaned.isEmpty || double.tryParse(cleaned) == 0) {
              return 'Số tiền không hợp lệ';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// TextFormField nhập Tên cửa hàng
  Widget _buildMerchantField(ReviewTransactionViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tên cửa hàng / Đơn vị bán',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: vm.merchantController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            prefixIcon: const Icon(Icons.storefront_rounded, color: Colors.white70),
            hintText: 'Nhập tên cửa hàng...',
            hintStyle: const TextStyle(color: Colors.white24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Tên cửa hàng không được để trống';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Trường Ngày giao dịch kèm DatePicker
  Widget _buildDateField(BuildContext context, ReviewTransactionViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ngày giao dịch',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 22),
                const SizedBox(width: 14),
                Text(
                  vm.formattedDate,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const Spacer(),
                const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Dropdown chọn Danh mục chi tiêu
  Widget _buildCategoryDropdown(ReviewTransactionViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danh mục chi tiêu',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ExpenseCategory>(
              value: vm.selectedCategory,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
              onChanged: (cat) {
                if (cat != null) vm.setCategory(cat);
              },
              items: ExpenseCategory.values.map((category) {
                return DropdownMenuItem<ExpenseCategory>(
                  value: category,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(category.icon, color: category.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        category.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Thanh nút bấm ở cạnh dưới màn hình
  Widget _buildBottomActionBar(BuildContext context, ReviewTransactionViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _handleConfirmAndSave(context),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
            label: const Text(
              'Xác nhận & Lưu chi tiêu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
