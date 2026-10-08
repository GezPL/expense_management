import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../ocr/models/expense_category.dart';
import '../viewmodels/home_view_model.dart';

/// Hộp thoại quản lý ngân sách & thông báo: Ngân sách tháng, Hạn mức danh mục & Nhắc nhở định kỳ
class BudgetSettingsDialog extends StatefulWidget {
  final HomeViewModel viewModel;
  final int initialTabIndex;

  const BudgetSettingsDialog({
    super.key,
    required this.viewModel,
    this.initialTabIndex = 0,
  });

  static Future<void> show(BuildContext context, HomeViewModel viewModel, {int initialTab = 0}) {
    return showDialog(
      context: context,
      builder: (ctx) => BudgetSettingsDialog(
        viewModel: viewModel,
        initialTabIndex: initialTab,
      ),
    );
  }

  @override
  State<BudgetSettingsDialog> createState() => _BudgetSettingsDialogState();
}

class _BudgetSettingsDialogState extends State<BudgetSettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _monthlyBudgetController;

  bool _reminderEnabled = true;
  int _reminderHour = 20;
  int _reminderMinute = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _monthlyBudgetController = TextEditingController(
      text: NumberFormat('#,###').format(widget.viewModel.monthlyBudget.toInt()),
    );
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    final settings = await NotificationService.instance.getReminderSettings();
    if (mounted) {
      setState(() {
        _reminderEnabled = settings.isEnabled;
        _reminderHour = settings.hour;
        _reminderMinute = settings.minute;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _monthlyBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề & Nút đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Cài đặt & Ngân sách',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab bar chuyển đổi giữa 3 mục: Ngân sách tháng, Danh mục, Nhắc nhở
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: 'Ngân sách'),
                  Tab(text: 'Danh mục'),
                  Tab(text: 'Nhắc nhở'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nội dung theo Tab
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMonthlyBudgetTab(),
                  _buildCategoryBudgetsTab(),
                  _buildReminderTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 1: Cài đặt hạn mức ngân sách tháng
  Widget _buildMonthlyBudgetTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hạn mức tổng chi tiêu tối đa trong tháng:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _monthlyBudgetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              suffixText: 'VNĐ',
              suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Gợi ý mức ngân sách nhanh
          const Text('Gợi ý nhanh:', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [3000000, 5000000, 7000000, 10000000].map((val) {
              return ActionChip(
                backgroundColor: const Color(0xFF0F172A),
                label: Text(
                  '${NumberFormat('#,###').format(val)} đ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                onPressed: () {
                  setState(() {
                    _monthlyBudgetController.text = NumberFormat('#,###').format(val);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Nút lưu
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final cleaned = _monthlyBudgetController.text.replaceAll(RegExp(r'[^\d]'), '');
              final val = double.tryParse(cleaned);
              if (val != null && val > 0) {
                widget.viewModel.updateMonthlyBudget(val);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã cập nhật hạn mức ngân sách tháng!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Lưu hạn mức tháng', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Tab 2: Danh sách hạn mức theo từng danh mục
  Widget _buildCategoryBudgetsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thiết lập hạn mức riêng cho từng mục để nhận cảnh báo khi sắp vượt:',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: ExpenseCategory.values.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = ExpenseCategory.values[index];
              final budget = widget.viewModel.getCategoryBudget(cat);
              final spent = widget.viewModel.getCategoryExpense(cat);
              final hasBudget = budget > 0;
              final progress = widget.viewModel.getCategoryProgress(cat);
              final isOver = widget.viewModel.isCategoryOverBudget(cat);

              Color progressColor = cat.color;
              if (progress >= 1.0) {
                progressColor = AppColors.error;
              } else if (progress >= 0.8) {
                progressColor = const Color(0xFFF59E0B);
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOver
                        ? AppColors.error.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Đã chi: ${NumberFormat('#,###').format(spent.toInt())} đ',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (hasBudget) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Hạn mức: ${NumberFormat('#,###').format(budget.toInt())} đ',
                                style: TextStyle(
                                  color: isOver ? AppColors.error : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isOver
                                    ? 'Vượt ${(spent - budget).toInt()} đ!'
                                    : 'Còn ${(budget - spent).toInt()} đ',
                                style: TextStyle(
                                  color: isOver ? AppColors.error : AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                            onPressed: () => _showEditCategoryBudgetDialog(cat, budget),
                            tooltip: 'Sửa hạn mức',
                            padding: const EdgeInsets.only(left: 6),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            onPressed: () {
                              widget.viewModel.removeCategoryBudget(cat);
                              setState(() {});
                            },
                            tooltip: 'Xóa hạn mức',
                            padding: const EdgeInsets.only(left: 6),
                            constraints: const BoxConstraints(),
                          ),
                        ] else ...[
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Đặt hạn mức', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showEditCategoryBudgetDialog(cat, 0),
                          ),
                        ],
                      ],
                    ),
                    if (hasBudget) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Tab 3: Cài đặt thông báo nhắc nhở chi tiêu định kỳ
  Widget _buildReminderTab() {
    final timeStr = '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Thông báo nhắc nhở ghi chép chi tiêu được lên lịch 100% nội bộ trên thiết bị, không cần mạng Internet.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Công tắc Bật/Tắt nhắc nhở
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhắc nhở hàng ngày',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Nhắc bạn cập nhật chi tiêu vào buổi tối',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _reminderEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) async {
                    setState(() => _reminderEnabled = val);
                    await NotificationService.instance.toggleReminder(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lựa chọn giờ nhắc nhở
          if (_reminderEnabled) ...[
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
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
                  setState(() {
                    _reminderHour = picked.hour;
                    _reminderMinute = picked.minute;
                  });
                  await NotificationService.instance.setReminderTime(picked.hour, picked.minute);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 10),
                        Text('Thời gian nhắc nhở', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Nút thử nghiệm thông báo
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.primary),
            label: const Text('Gửi thông báo thử nghiệm ngay'),
            onPressed: () async {
              await NotificationService.instance.sendTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi thông báo thử nghiệm đến thiết bị!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Hộp thoại nhập hạn mức cho từng danh mục
  void _showEditCategoryBudgetDialog(ExpenseCategory category, double currentBudget) {
    final controller = TextEditingController(
      text: currentBudget > 0 ? NumberFormat('#,###').format(currentBudget.toInt()) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(category.icon, color: category.color, size: 22),
            const SizedBox(width: 8),
            Text(
              'Hạn mức ${category.displayName.split(' ').first}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhập số tiền tối đa cho danh mục ${category.displayName} trong tháng:',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                suffixText: 'VNĐ',
                suffixStyle: TextStyle(color: category.color, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [500000, 1000000, 2000000, 3000000].map((quick) {
                return ActionChip(
                  backgroundColor: const Color(0xFF0F172A),
                  label: Text(
                    '${NumberFormat('#,###').format(quick)} đ',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  onPressed: () {
                    controller.text = NumberFormat('#,###').format(quick);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: category.color),
            onPressed: () {
              final cleaned = controller.text.replaceAll(RegExp(r'[^\d]'), '');
              final val = double.tryParse(cleaned);
              if (val != null && val > 0) {
                widget.viewModel.updateCategoryBudget(category, val);
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật hạn mức ${category.displayName}!'),
                    backgroundColor: category.color,
                  ),
                );
              }
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
