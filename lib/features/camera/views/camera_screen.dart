import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/camera_view_model.dart';
import '../widgets/camera_crop_overlay.dart';
import '../widgets/camera_viewfinder.dart';
import '../widgets/capture_button.dart';
import '../widgets/flash_toggle_button.dart';
import '../widgets/focus_ring_widget.dart';
import '../../ocr/views/review_transaction_screen.dart';
import '../../analytics/views/expense_analytics_screen.dart';

/// Màn hình chính chụp hóa đơn (CameraScreen) theo kiến trúc MVVM
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late CameraViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Ẩn thanh trạng thái hệ thống để trải nghiệm chụp toàn màn hình immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _viewModel = CameraViewModel();
    _viewModel.initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Xử lý giải phóng / phục hồi camera khi ứng dụng ẩn hoặc hiện
    _viewModel.handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Khôi phục lại thanh trạng thái hệ thống
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _viewModel.dispose();
    super.dispose();
  }

  /// Xử lý khi nhấn nút chụp ảnh
  Future<void> _handleCapture(BuildContext context) async {
    final imageFile = await _viewModel.takePicture();
    if (!context.mounted) return;

    if (imageFile != null) {
      // Hiển thị dialog / bottom sheet xem trước kết quả ảnh đã chụp
      _showCapturedPreviewDialog(context, imageFile.path);
    } else if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Dialog preview nhanh ảnh hóa đơn vừa chụp trước khi chuyển sang Phase 2 (OCR)
  void _showCapturedPreviewDialog(BuildContext context, String imagePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hóa đơn đã chụp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Chụp lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewTransactionScreen(imagePath: imagePath),
                          ),
                        );
                      },
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Xử lý OCR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CameraViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<CameraViewModel>(
          builder: (context, vm, child) {
            // 1. Trạng thái lỗi
            if (vm.errorMessage != null && !vm.isInitialized) {
              return _buildErrorState(vm);
            }

            // 2. Trạng thái đang tải khởi tạo camera
            if (!vm.isInitialized || vm.controller == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang khởi động Camera...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final screenSize = MediaQuery.of(context).size;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Layer 1: Live Viewfinder với Gesture lấy nét (Focus Tap)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    vm.setFocusAndExposurePoint(details.localPosition, screenSize);
                  },
                  child: CameraViewfinder(controller: vm.controller!),
                ),

                // Layer 2: Framing Crop Overlay (Tối 4 góc, sáng ô chữ nhật ở giữa)
                const CameraCropOverlay(),

                // Layer 3: Hiệu ứng Focus Ring khi người dùng chạm lấy nét
                if (vm.focusScreenOffset != null)
                  FocusRingWidget(position: vm.focusScreenOffset!),

                // Layer 4: Dòng chữ hướng dẫn người dùng canh lề
                Positioned(
                  top: screenSize.height * 0.73,
                  left: 20,
                  right: 20,
                  child: const Center(
                    child: Text(
                      'Căn chỉnh hóa đơn nằm gọn trong khung hình',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black87,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Layer 5: Top Navigation & Action Controls (SafeArea)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Nút đóng/quay lại
                          IconButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Đóng',
                          ),

                          // Tiêu đề
                          const Text(
                            'Quét hóa đơn',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),

                          // Nút Flash Toggle
                          FlashToggleButton(
                            flashMode: vm.flashMode,
                            onToggle: vm.toggleFlash,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Layer 6: Bottom Bar chứa nút chụp ảnh nổi bật
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Nút trợ giúp / Tips chụp
                          IconButton(
                            icon: const Icon(
                              Icons.wb_incandescent_outlined,
                              color: Colors.white70,
                              size: 26,
                            ),
                            tooltip: 'Mẹo chụp rõ nét',
                            onPressed: () => _showTipsDialog(context),
                          ),

                          // NÚT CHỤP HÌNH TRÒN NỔI BẬT
                          CaptureButton(
                            isCapturing: vm.isCapturing,
                            onTap: () => _handleCapture(context),
                          ),

                          // Nút mở màn hình Thống kê biểu đồ CustomPainter
                          IconButton(
                            icon: const Icon(
                              Icons.insights_rounded,
                              color: Colors.white70,
                              size: 26,
                            ),
                            tooltip: 'Thống kê chi tiêu',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ExpenseAnalyticsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Giao diện thông báo lỗi khi không thể mở camera
  Widget _buildErrorState(CameraViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              color: AppColors.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Không thể truy cập Camera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vm.errorMessage ?? 'Vui lòng cấp quyền camera trong Cài đặt thiết bị.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => vm.initializeCamera(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog mẹo chụp hóa đơn chuẩn xác cho OCR
  void _showTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Mẹo chụp hóa đơn', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Đặt hóa đơn trên mặt phẳng tương phản màu sắc.', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('2. Giữ camera song song, tránh bóng che và lóa sáng.', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('3. Chạm vào chữ trên màn hình để lấy nét trước khi bấm chụp.', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
