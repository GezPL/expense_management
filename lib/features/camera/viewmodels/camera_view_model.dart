import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// ViewModel quản lý toàn bộ trạng thái và logic của màn hình Camera (MVVM Pattern)
class CameraViewModel extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.off;
  String? _errorMessage;

  // Tọa độ màn hình (dx, dy) để View hiển thị vòng tròn lấy nét (Focus Ring)
  Offset? _focusScreenOffset;
  Timer? _focusResetTimer;

  // Getters
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  bool get isCapturing => _isCapturing;
  FlashMode get flashMode => _flashMode;
  String? get errorMessage => _errorMessage;
  Offset? get focusScreenOffset => _focusScreenOffset;

  /// Khởi tạo camera ban đầu
  Future<void> initializeCamera() async {
    try {
      _errorMessage = null;
      notifyListeners();

      // 1. Lấy danh sách camera trên thiết bị
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _errorMessage = 'Không tìm thấy camera khả dụng trên thiết bị.';
        notifyListeners();
        return;
      }

      // 2. Ưu tiên chọn Camera sau (Back Camera) để chụp hóa đơn
      final backCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // 3. Khởi tạo CameraController với độ phân giải cao để phục vụ OCR
      await _initCameraController(backCamera);
    } on CameraException catch (e) {
      _errorMessage = 'Lỗi khởi tạo camera: ${e.description ?? e.code}';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi không mong muốn: $e';
      notifyListeners();
    }
  }

  /// Khởi tạo controller cho camera cụ thể
  Future<void> _initCameraController(CameraDescription cameraDescription) async {
    // Giải phóng controller cũ nếu có
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.veryHigh, // Độ nét cao cho OCR
      enableAudio: false,        // Chỉ quét ảnh, không cần microphone
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();

    // Mặc định đặt FlashMode theo state hiện tại
    try {
      await _controller!.setFlashMode(_flashMode);
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (_) {
      // Một số máy giả lập hoặc phần cứng không hỗ trợ flash/focus
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Đổi chế độ đèn Flash (Off -> Torch/Bật đèn pin -> Auto -> Off)
  Future<void> toggleFlash() async {
    if (!isInitialized || _controller == null) return;

    try {
      FlashMode nextMode;
      switch (_flashMode) {
        case FlashMode.off:
          nextMode = FlashMode.torch; // Đèn pin liên tục để soi rõ hóa đơn
          break;
        case FlashMode.torch:
          nextMode = FlashMode.auto;
          break;
        case FlashMode.auto:
        default:
          nextMode = FlashMode.off;
          break;
      }

      await _controller!.setFlashMode(nextMode);
      _flashMode = nextMode;
      notifyListeners();
    } on CameraException catch (e) {
      _errorMessage = 'Không thể đổi chế độ Flash: ${e.description}';
      notifyListeners();
    }
  }

  /// Xử lý sự kiện chạm màn hình để lấy nét (Focus Tap) và phơi sáng (Exposure)
  Future<void> setFocusAndExposurePoint(Offset localOffset, Size screenSize) async {
    if (!isInitialized || _controller == null) return;

    try {
      // 1. Lưu lại điểm chạm trên màn hình để View vẽ hiệu ứng vòng tròn lấy nét
      _focusScreenOffset = localOffset;
      notifyListeners();

      // Tự động ẩn vòng tròn lấy nét sau 1.5 giây
      _focusResetTimer?.cancel();
      _focusResetTimer = Timer(const Duration(milliseconds: 1500), () {
        _focusScreenOffset = null;
        notifyListeners();
      });

      // 2. Chuẩn hóa tọa độ thành hệ quy chiếu [0.0, 1.0] của camera
      final double x = (localOffset.dx / screenSize.width).clamp(0.0, 1.0);
      final double y = (localOffset.dy / screenSize.height).clamp(0.0, 1.0);
      final normalizedPoint = Offset(x, y);

      // 3. Thiết lập điểm lấy nét và phơi sáng
      await _controller!.setFocusPoint(normalizedPoint);
      await _controller!.setExposurePoint(normalizedPoint);
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (e) {
      // Lỗi nếu camera không hỗ trợ focus tap (simulator hoặc low-end device)
      debugPrint('Lấy nét tại điểm chạm không được hỗ trợ: $e');
    }
  }

  /// Thực hiện chụp ảnh hóa đơn
  Future<XFile?> takePicture() async {
    if (!isInitialized || _controller == null || _isCapturing) {
      return null;
    }

    try {
      _isCapturing = true;
      notifyListeners();

      // Chụp ảnh trả về file tạm XFile
      final XFile image = await _controller!.takePicture();
      return image;
    } on CameraException catch (e) {
      _errorMessage = 'Lỗi khi chụp ảnh: ${e.description ?? e.code}';
      return null;
    } finally {
      _isCapturing = false;
      notifyListeners();
    }
  }

  /// Xử lý vòng đời ứng dụng (App Lifecycle) để giải phóng và khôi phục camera
  void handleAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Khi app bị ẩn hoặc vào background -> giải phóng camera phần cứng
      _controller?.dispose();
      _isInitialized = false;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      // Khi app quay lại foreground -> khởi tạo lại camera
      if (_cameras.isNotEmpty) {
        final backCamera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
        _initCameraController(backCamera);
      } else {
        initializeCamera();
      }
    }
  }

  @override
  void dispose() {
    _focusResetTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
