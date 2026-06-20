import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF1A1D26);
  static const surfaceLight = Color(0xFF252932);
  static const accent = Color(0xFF6C5CE7);
  static const accentGlow = Color(0xFF8B7CF6);
  static const connected = Color(0xFF00B894);
  static const connecting = Color(0xFFFDCB6E);
  static const disconnected = Color(0xFF636E72);
  static const error = Color(0xFFE17055);
}

class AppTheme {
  static ThemeData get dark {
    const seed = AppColors.accent;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme.copyWith(
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }
}

String vpnStatusLabel(VpnUiStatus status) {
  return switch (status) {
    VpnUiStatus.disconnected => 'Не защищено',
    VpnUiStatus.connecting => 'Подключение…',
    VpnUiStatus.connected => 'Защищено',
    VpnUiStatus.error => 'Ошибка',
  };
}

Color vpnStatusColor(VpnUiStatus status) {
  return switch (status) {
    VpnUiStatus.disconnected => AppColors.disconnected,
    VpnUiStatus.connecting => AppColors.connecting,
    VpnUiStatus.connected => AppColors.connected,
    VpnUiStatus.error => AppColors.error,
  };
}

enum VpnUiStatus { disconnected, connecting, connected, error }
