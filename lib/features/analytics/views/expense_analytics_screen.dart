import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/local/expense_database_helper.dart';
import '../../ocr/models/expense_category.dart';
import '../painters/category_donut_painter.dart';
import '../painters/weekly_bar_painter.dart';

/// Widget Màn hình Thống kê Trực quan hóa Dữ liệu bằng CustomPainter thuần
class ExpenseAnalyticsScreen extends StatefulWidget {
  const ExpenseAnalyticsScreen({super.key});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  bool _isLoading = true;
  bool _useSampleData = false;

  Map<String, double> _categoryTotals = {
    for (final cat in ExpenseCategory.values) cat.toDbString(): 0.0,
  };

  List<double> _weeklyExpenses = List.filled(7, 0.0);

  // Dữ liệu mẫu minh họa sinh động khi Database chưa có bản ghi (8 danh mục)
  static const Map<String, double> _sampleCategoryTotals = {
    'FOOD': 450000.0,
    'STUDY': 220000.0,
    'TRAVEL': 180000.0,
    'GEAR': 650000.0,
    'ENTERTAINMENT': 300000.0,
    'SHOPPING': 380000.0,
    'HEALTH': 150000.0,
    'BILLS': 420000.0,
  };

  static const List<double> _sampleWeeklyExpenses = [
    120000.0, // T2
    250000.0, // T3
    80000.0,  // T4
    310000.0, // T5
    190000.0, // T6
    540000.0, // T7
    310000.0, // CN
  ];

  @override
  void initState() {
    super.initState();

    // Khởi tạo AnimationController và Tween điều khiển hiệu ứng chuyển động
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Tải dữ liệu thực tế từ SQLite Database
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = ExpenseDatabaseHelper.instance;
      final catTotals = await db.getCategoryTotals();
      final weekly = await db.getWeeklyExpenses();

      final totalExpense = catTotals.values.fold(0.0, (s, v) => s + v);

      if (mounted) {
        setState(() {
          _categoryTotals = catTotals;
          _weeklyExpenses = weekly;
          // Nếu database chưa có dữ liệu, tự động bật cờ dùng dữ liệu mẫu để demo
          _useSampleData = (totalExpense <= 0);
          _isLoading = false;
        });

        // Bắt đầu chạy Animation vẽ biểu đồ
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _useSampleData = true;
          _isLoading = false;
        });
        _animationController.forward(from: 0.0);
      }
    }
  }

  /// Kích hoạt lại Animation vẽ biểu đồ
  void _replayAnimation() {
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = _useSampleData ? _sampleCategoryTotals : _categoryTotals;
    final activeWeekly = _useSampleData ? _sampleWeeklyExpenses : _weeklyExpenses;

    final double totalAmount = activeCategories.values.fold(0.0, (s, v) => s + v);
    final int todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thống kê Chi tiêu',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay_rounded, color: AppColors.primary),
            tooltip: 'Xem lại hiệu ứng',
            onPressed: _replayAnimation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner thông báo nếu đang hiển thị dữ liệu mẫu
                    if (_useSampleData)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Hiển thị dữ liệu trực quan mẫu (Chưa có giao dịch trong DB)',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _useSampleData = false),
                              child: const Text('Xem DB thật', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // ==========================================
                    // BIỂU ĐỒ 1: CATEGORY DONUT CHART (CUSTOMPAINTER)
                    // ==========================================
                    _buildSectionHeader('PHÂN BỐ THEO DANH MỤC', Icons.pie_chart_rounded),
                    const SizedBox(height: 12),
                    _buildDonutChartCard(activeCategories, totalAmount),

                    const SizedBox(height: 24),

                    // ==========================================
                    // BIỂU ĐỒ 2: WEEKLY BAR CHART (CUSTOMPAINTER)
                    // ==========================================
                    _buildSectionHeader('CHI TIÊU THEO TUẦN NÀY', Icons.bar_chart_rounded),
                    const SizedBox(height: 12),
                    _buildWeeklyBarChartCard(activeWeekly, todayIndex),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  /// Card chứa Biểu đồ tròn Animated Donut Chart
  Widget _buildDonutChartCard(Map<String, double> categoryTotals, double totalAmount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Tích hợp AnimatedBuilder điều khiển CustomPainter
          SizedBox(
            height: 230,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: CategoryDonutPainter(
                    categoryTotals: categoryTotals,
                    animationValue: _animation.value,
                    strokeWidth: 28.0,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Legend danh mục chú thích kèm tỷ lệ phần trăm
          Column(
            children: ExpenseCategory.values.map((category) {
              final double amount = categoryTotals[category.toDbString()] ?? 0.0;
              final double percent = totalAmount > 0 ? (amount / totalAmount) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category.displayName,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${NumberFormat('#,###').format(amount.toInt())} đ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Card chứa Biểu đồ cột Weekly Bar Chart
  Widget _buildWeeklyBarChartCard(List<double> weeklyExpenses, int todayIndex) {
    final double weeklyTotal = weeklyExpenses.fold(0.0, (s, v) => s + v);
    final double avgPerDay = weeklyTotal / 7;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tổng tuần này', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat('#,###').format(weeklyTotal.toInt())} đ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Trung bình / ngày', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat('#,###').format(avgPerDay.toInt())} đ',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tích hợp AnimatedBuilder điều khiển WeeklyBarPainter
          SizedBox(
            height: 200,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: WeeklyBarPainter(
                    dailyExpenses: weeklyExpenses,
                    animationValue: _animation.value,
                    currentDayIndex: todayIndex,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.focusRing,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Cột màu vàng biểu thị ngày hôm nay',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

