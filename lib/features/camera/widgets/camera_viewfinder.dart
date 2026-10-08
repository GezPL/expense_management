import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Hiển thị luồng Camera trực tiếp tràn toàn màn hình (Live Viewfinder) mà không bị méo tỉ lệ
class CameraViewfinder extends StatelessWidget {
  final CameraController controller;

  const CameraViewfinder({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tỷ lệ aspect ratio của camera preview (thường là 4/3 hoặc 16/9)
        var cameraAspect = controller.value.aspectRatio;
        
        // Khi ở chế độ dọc (portrait), nếu aspect ratio > 1 thì nghịch đảo để vừa khung dọc
        if (cameraAspect > 1) {
          cameraAspect = 1 / cameraAspect;
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth / cameraAspect,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}

