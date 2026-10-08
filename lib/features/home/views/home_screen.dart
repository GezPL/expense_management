import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/expense_transaction.dart';
import '../../analytics/views/expense_analytics_screen.dart';
import '../../camera/views/camera_screen.dart';
import '../../ocr/models/expense_category.dart';
import '../viewmodels/home_view_model.dart';
import 'backup_restore_dialog.dart';
import 'budget_settings_dialog.dart';
import 'manual_expense_entry_screen.dart';

/// Màn hình chính Dashboard: Quản lý ngân sách, Lịch sử chi tiêu, Tìm kiếm và Lọc
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    _viewModel.loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// Hộp thoại cài đặt / điều chỉnh hạn mức ngân sách tháng & từng danh mục
  void _showSetBudgetDialog(BuildContext context, {int initialTab = 0}) {
    BudgetSettingsDialog.show(context, _viewModel, initialTab: initialTab);
  }

  /// Mở xem chi tiết giao dịch trong Modal BottomSheet
  void _showTransactionDetail(BuildContext context, ExpenseTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: transaction.category.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(transaction.category.icon, color: transaction.category.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.merchantName,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          transaction.category.displayName,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '- ${NumberFormat('#,###', 'vi_VN').format(transaction.amount)} đ',
                  style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hiển thị ảnh thu nhỏ thumbnail nếu có
            if (transaction.thumbnailPath != null && File(transaction.thumbnailPath!).existsSync()) ...[
              const Text('Ảnh chụp hóa đơn (Đã nén tối ưu):',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(transaction.thumbnailPath!),
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Xóa giao dịch này'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success = await _viewModel.deleteTransaction(transaction);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã xóa giao dịch thành công!')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: const Row(
            children: [
              Icon(Icons.wallet_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Expense Management',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.insights_rounded, color: AppColors.primary),
              tooltip: 'Biểu đồ thống kê',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseAnalyticsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white70),
              tooltip: 'Cài đặt ngân sách',
              onPressed: () => _showSetBudgetDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.backup_rounded, color: Colors.white70),
              tooltip: 'Sao lưu & Phục hồi',
              onPressed: () => BackupRestoreDialog.show(context, _viewModel),
            ),
          ],
        ),
        body: Consumer<HomeViewModel>(
          builder: (context, vm, child) {
            if (vm.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: vm.loadDashboardData,
              color: AppColors.primary,
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // 1. Thẻ Ngân sách Thông minh (Monthly Budget Card)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: _buildBudgetCard(context, vm),
                          ),
                        ),

                        // 2. Thanh tìm kiếm và bộ lọc danh mục
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildSearchBar(vm),
                              ),
                              const SizedBox(height: 12),
                              _buildCategoryFilterChips(vm),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'LỊCH SỬ GIAO DỊCH',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    Text(
                                      '${vm.transactions.length} giao dịch',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),

                        // 3. Danh sách giao dịch
                        if (vm.transactions.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final transaction = vm.transactions[index];
                                  return _buildTransactionItem(context, vm, transaction);
                                },
                                childCount: vm.transactions.length,
                              ),
                            ),
                          ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 90), // Chừa khoảng trống cho Bottom Bar
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 4. Thanh nút thao tác nhanh ở dưới màn hình
        bottomSheet: _buildBottomActionBar(context),
      ),
    );
  }

  /// Thẻ Ngân sách Chi tiêu Tháng (Budget Card) với tiến trình thông minh
  Widget _buildBudgetCard(BuildContext context, HomeViewModel vm) {
    final double remaining = vm.monthlyBudget - vm.totalMonthExpense;
    final double progress = vm.budgetProgress;
    final bool isOver = vm.isOverBudget;

    // Màu sắc thanh tiến trình thay đổi linh hoạt theo mức độ chi tiêu
    Color progressColor;
    if (progress < 0.7) {
      progressColor = AppColors.primary; // Xanh lá
    } else if (progress < 0.9) {
      progressColor = const Color(0xFFF59E0B); // Vàng hổ phách cảnh báo
    } else {
      progressColor = AppColors.error; // Đỏ báo động
    }

    final currentMonthStr = DateFormat('MM/yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOver ? AppColors.error.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ngân sách tháng $currentMonthStr',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              InkWell(
                onTap: () => _showSetBudgetDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: isOver ? AppColors.error : AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Đổi hạn mức',
                        style: TextStyle(
                          color: isOver ? AppColors.error : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${NumberFormat('#,###', 'vi_VN').format(vm.totalMonthExpense.toInt())} đ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${NumberFormat('#,###').format(vm.monthlyBudget.toInt())} đ',
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Thanh tiến trình ngân sách
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã dùng ${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isOver
                    ? 'Vượt ${NumberFormat('#,###').format(-remaining.toInt())} đ!'
                    : 'Còn lại ${NumberFormat('#,###').format(remaining.toInt())} đ',
                style: TextStyle(
                  color: isOver ? AppColors.error : Colors.white54,
                  fontSize: 12,
                  fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),

          // Cảnh báo nếu có danh mục vượt hạn mức
          Builder(
            builder: (context) {
              final overCategories = vm.categoryBudgets.keys.where((c) => vm.isCategoryOverBudget(c)).toList();
              if (overCategories.isEmpty) {
                // Hiển thị nút truy cập nhanh hạn mức danh mục nếu chưa có cảnh báo
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    onTap: () => _showSetBudgetDialog(context, initialTab: 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.category_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          vm.categoryBudgets.isEmpty
                              ? 'Thiết lập hạn mức từng danh mục'
                              : 'Đã đặt ${vm.categoryBudgets.length} hạn mức danh mục',
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: InkWell(
                  onTap: () => _showSetBudgetDialog(context, initialTab: 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cảnh báo: ${overCategories.length} mục (${overCategories.map((c) => c.displayName.split(' ').first).join(', ')}) vượt hạn mức!',
                            style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.error, size: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Thanh tìm kiếm nhanh
  Widget _buildSearchBar(HomeViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: vm.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên quán, cửa hàng...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    vm.setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  /// Thanh cuộn ngang lọc theo 5 danh mục chi tiêu
  Widget _buildCategoryFilterChips(HomeViewModel vm) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Chip "Tất cả"
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: vm.selectedCategory == null,
              onSelected: (_) => vm.setCategoryFilter(null),
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFF1E293B),
              labelStyle: TextStyle(
                color: vm.selectedCategory == null ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          // Các danh mục
          ...ExpenseCategory.values.map((cat) {
            final isSelected = vm.selectedCategory == cat;
            final isOver = vm.isCategoryOverBudget(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  isOver ? Icons.warning_amber_rounded : cat.icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : (isOver ? AppColors.error : cat.color),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.displayName.split(' ').first),
                    if (isOver) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => vm.setCategoryFilter(isSelected ? null : cat),
                selectedColor: isOver ? AppColors.error : cat.color,
                backgroundColor: const Color(0xFF1E293B),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Thẻ hiển thị một giao dịch có hỗ trợ Vuốt để xóa (Dismissible)
  Widget _buildTransactionItem(BuildContext context, HomeViewModel vm, ExpenseTransaction transaction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('trans_${transaction.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Xác nhận xóa?', style: TextStyle(color: Colors.white)),
              content: Text(
                'Bạn có chắc chắn muốn xóa giao dịch tại "${transaction.merchantName}" không?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) {
          vm.deleteTransaction(transaction);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa giao dịch "${transaction.merchantName}"'),
              backgroundColor: const Color(0xFF334155),
            ),
          );
        },
        child: InkWell(
          onTap: () => _showTransactionDetail(context, transaction),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                // Icon danh mục
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: transaction.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(transaction.category.icon, color: transaction.category.color, size: 22),
                ),
                const SizedBox(width: 12),

                // Tên quán & Ngày
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchantName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('dd/MM/yyyy • HH:mm').format(transaction.date),
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Số tiền & Thumbnail
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '- ${NumberFormat('#,###').format(transaction.amount.toInt())} đ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (transaction.thumbnailPath != null) ...[
                      const SizedBox(height: 2),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined, size: 12, color: AppColors.primary),
                          SizedBox(width: 2),
                          Text('Hóa đơn', style: TextStyle(color: AppColors.primary, fontSize: 10)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Trạng thái rỗng khi chưa có giao dịch nào
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có giao dịch chi tiêu',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhập hóa đơn bằng tay, chụp ảnh hóa đơn hoặc chọn từ thư viện để theo dõi chi tiêu!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ManualExpenseEntryScreen()),
                );
                if (added == true) {
                  _viewModel.loadDashboardData();
                }
              },
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              label: const Text(
                'Nhập chi tiêu thủ công',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thanh nút thao tác nhanh ở cạnh dưới (Nhập tay, Thư viện, Camera Scanner)
  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Nút 1: Nhập chi tiêu bằng tay
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const ManualExpenseEntryScreen()),
                  );
                  if (added == true) {
                    _viewModel.loadDashboardData();
                  }
                },
                icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                label: const Text(
                  'Nhập tay',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Nút 2: Chọn ảnh từ thư viện
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _viewModel.pickImageFromGallery(context),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text(
                  'Thư viện',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Nút 3: Mở Camera chụp hóa đơn (Nổi bật)
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  );
                  // Reload lại danh sách sau khi quay về từ Camera
                  _viewModel.loadDashboardData();
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text(
                  'Chụp ảnh',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

