import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Nút toggle đèn Flash ở góc trên màn hình camera
class FlashToggleButton extends StatelessWidget {
  final FlashMode flashMode;
  final VoidCallback onToggle;

  const FlashToggleButton({
    super.key,
    required this.flashMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    String tooltip;

    switch (flashMode) {
      case FlashMode.torch:
        icon = Icons.flash_on_rounded;
        iconColor = AppColors.focusRing;
        tooltip = 'Flash: Bật liên tục (Torch)';
        break;
      case FlashMode.auto:
        icon = Icons.flash_auto_rounded;
        iconColor = AppColors.focusRing;
        tooltip = 'Flash: Tự động (Auto)';
        break;
      case FlashMode.off:
      default:
        icon = Icons.flash_off_rounded;
        iconColor = Colors.white;
        tooltip = 'Flash: Tắt';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onToggle,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
