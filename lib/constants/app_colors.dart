import 'package:flutter/material.dart';

/// 산업용 다크 테마 컬러 팔레트
class AppColors {
  // Primary Colors
  static const Color primaryDark = Color(0xFF1A1A2E);
  static const Color primaryMid = Color(0xFF16213E);
  static const Color primaryLight = Color(0xFF0F3460);
  
  // Background Colors
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF252525);
  static const Color surfaceElevated = Color(0xFF2D2D2D);
  
  // Accent Colors
  static const Color accent = Color(0xFF00D4FF);
  static const Color accentSecondary = Color(0xFF7B68EE);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFFF4757);
  static const Color success = Color(0xFF00E676);
  
  // LED Indicator Colors
  static const Color ledOn = Color(0xFF00FF00);
  static const Color ledOff = Color(0xFF333333);
  static const Color ledWarning = Color(0xFFFFAA00);
  static const Color ledError = Color(0xFFFF0000);
  static const Color ledConnecting = Color(0xFF00AAFF);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF707070);
  static const Color textAccent = Color(0xFF00D4FF);
  
  // Data Display Colors
  static const Color hexText = Color(0xFF00FF88);
  static const Color dataValue = Color(0xFFFFD700);
  static const Color registerAddress = Color(0xFFFF6B6B);
  static const Color timestamp = Color(0xFF888888);
  
  // Border Colors
  static const Color border = Color(0xFF404040);
  static const Color borderLight = Color(0xFF555555);
  static const Color borderFocused = Color(0xFF00D4FF);
  
  // Function Code Colors
  static const Color fcRead = Color(0xFF4CAF50);
  static const Color fcWrite = Color(0xFFFF9800);
  static const Color fcDiagnostic = Color(0xFF9C27B0);
  
  // Metallic Effect Colors
  static const Color metallicLight = Color(0xFF505050);
  static const Color metallicDark = Color(0xFF303030);
  
  // Gradient for Industrial Panel Effect
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2A2A),
      Color(0xFF1A1A1A),
      Color(0xFF252525),
    ],
  );
  
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF404040),
      Color(0xFF2A2A2A),
    ],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00D4FF),
      Color(0xFF0099CC),
    ],
  );
}
