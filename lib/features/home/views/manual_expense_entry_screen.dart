import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/local/expense_database_helper.dart';
import '../../../data/models/expense_transaction.dart';
import '../../ocr/models/expense_category.dart';

/// Màn hình Nhập hóa đơn tay (Manual Expense Entry Screen)
/// Cho phép người dùng nhập trực tiếp chi tiêu mà không cần chụp ảnh quét OCR
class ManualExpenseEntryScreen extends StatefulWidget {
  const ManualExpenseEntryScreen({super.key});

  @override
  State<ManualExpenseEntryScreen> createState() => _ManualExpenseEntryScreenState();
}

class _ManualExpenseEntryScreenState extends State<ManualExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  bool _isSaving = false;

  final NumberFormat _currencyFormatter = NumberFormat('#,###', 'vi_VN');

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Xử lý định dạng số tiền khi nhập
  void _onAmountChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.isEmpty) {
      _amountController.value = const TextEditingValue(text: '');
      return;
    }

    final number = int.tryParse(cleaned);
    if (number != null) {
      final formatted = _currencyFormatter.format(number);
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  /// Chọn ngày giao dịch (Chặn tuyệt đối ngày ở tương lai)
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now, // Không cho phép chọn ngày tương lai
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

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  /// Chọn giờ giao dịch
  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  /// Xác nhận và lưu giao dịch vào SQLite
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanedAmount = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final double amount = double.tryParse(cleanedAmount) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hợp lệ lớn hơn 0'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final transaction = ExpenseTransaction(
        amount: amount,
        date: finalDateTime,
        merchantName: _merchantController.text.trim(),
        category: _selectedCategory,
        thumbnailPath: null, // Nhập tay không có thumbnail ảnh
      );

      await ExpenseDatabaseHelper.instance.insertTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã lưu chi tiêu "${transaction.merchantName}" (${_currencyFormatter.format(amount.toInt())} đ)',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true); // Trả về true báo hiệu đã thêm thành công
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu giao dịch: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nhập chi tiêu thủ công',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveTransaction,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
              label: const Text(
                'Lưu',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // 1. Ô NHẬP SỐ TIỀN LỚN NỔI BẬT
              _buildAmountInputCard(),

              const SizedBox(height: 20),

              // 2. TÊN CỬA HÀNG / ĐỊA ĐIỂM
              _buildLabel('TÊN CỬA HÀNG / DỊCH VỤ'),
              const SizedBox(height: 8),
              _buildMerchantField(),

              const SizedBox(height: 20),

              // 3. CHỌN DANH MỤC CHI TIÊU (8 DANH MỤC)
              _buildLabel('DANH MỤC CHI TIÊU'),
              const SizedBox(height: 8),
              _buildCategorySelector(),

              const SizedBox(height: 20),

              // 4. THỜI GIAN GIAO DỊCH (NGÀY & GIỜ)
              _buildLabel('THỜI GIAN GIAO DỊCH'),
              const SizedBox(height: 8),
              _buildDateTimePickers(),

              const SizedBox(height: 20),

              // 5. GHI CHÚ BỔ SUNG (TÙY CHỌN)
              _buildLabel('GHI CHÚ (TÙY CHỌN)'),
              const SizedBox(height: 8),
              _buildNoteField(),

              const SizedBox(height: 32),

              // 6. NÚT XÁC NHẬN & LƯU
              _buildSaveButton(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  /// Card nhập số tiền nổi bật
  Widget _buildAmountInputCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số tiền chi tiêu',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onAmountChanged,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 32, fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập số tiền';
                    }
                    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
                    final numVal = double.tryParse(cleaned);
                    if (numVal == null || numVal <= 0) {
                      return 'Số tiền phải lớn hơn 0';
                    }
                    return null;
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VNĐ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ô nhập Tên cửa hàng / Dịch vụ
  Widget _buildMerchantField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextFormField(
        controller: _merchantController,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Ví dụ: Phúc Long, CGV, Co.opmart, EVN...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
          suffixIcon: _merchantController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                  onPressed: () {
                    _merchantController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (_) => setState(() {}),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Vui lòng nhập tên cửa hàng hoặc mô tả';
          }
          return null;
        },
      ),
    );
  }

  /// Bộ chọn Danh mục chi tiêu dạng Grid 8 mục
  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ExpenseCategory.values.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.95,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final cat = ExpenseCategory.values[index];
          final isSelected = cat == _selectedCategory;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = cat;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? cat.color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: isSelected ? 0.9 : 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cat.icon,
                      size: 20,
                      color: isSelected ? Colors.white : cat.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.displayName.split(' ').first, // 'Food', 'Study', 'Shopping'...
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Chọn Ngày và Giờ
  Widget _buildDateTimePickers() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(_selectedDate);
    final formattedTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        // Chọn Ngày
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Chọn Giờ
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: _selectTime,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    formattedTime,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Ô nhập Ghi chú
  Widget _buildNoteField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 2,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Thêm ghi chú chi tiết nếu cần...',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Icon(Icons.note_alt_outlined, color: Colors.white38, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  /// Nút Lưu chi tiêu
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isSaving ? null : _saveTransaction,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.check_circle_rounded, size: 22),
        label: Text(
          _isSaving ? 'Đang lưu...' : 'Xác nhận & Lưu Chi Tiêu',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

