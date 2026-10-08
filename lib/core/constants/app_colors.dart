import 'package:flutter/material.dart';

/// Bảng màu dùng chung cho ứng dụng OCR Expense Tracker
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF10B981); // Emerald Green hiện đại
  static const Color primaryDark = Color(0xFF059669);
  static const Color accent = Color(0xFF3B82F6); // Blue

  // Camera UI Colors
  static const Color overlayBackground = Color(0x99000000); // Đen 60% mờ xung quanh
  static const Color cropBorder = Color(0xFFFFFFFF); // Viền khung
  static const Color cropCornerAccent = Color(0xFF10B981); // 4 góc định vị xanh ngọc
  static const Color focusRing = Color(0xFFFFD700); // Vàng nổi bật khi chạm lấy nét
  
  // Neutral Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color textMuted = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFEF4444);
}

