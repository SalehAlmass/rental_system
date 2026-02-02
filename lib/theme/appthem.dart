import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Colors
  static const Color _lightSeed = Color(0xFF2563EB);
  static const Color _darkSeed = Color(0xFF369ADD);

  static const Color _lightBackground = Colors.white;
  static const Color _darkBackground = Color(0xFF020617);

  static const Color _lightAppBarBg = Color(0xFFEEF2FF);
  static const Color _lightAppBarFg = Color(0xFF1E3A8A);

  static const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius _inputRadius = BorderRadius.all(Radius.circular(14));

  /// 🌞 Light Theme
  static ThemeData lightTheme() {
    return _buildTheme(
      seedColor: _lightSeed,
      brightness: Brightness.light,
      scaffoldBg: _lightBackground,
      cardColor: Colors.white,
      appBarBg: _lightAppBarBg,
      appBarFg: _lightAppBarFg,
      inputFill: const Color(0xFFF1F5F9),
    );
  }

  /// 🌙 Dark Theme
  static ThemeData darkTheme() {
    return _buildTheme(
      seedColor: _darkSeed,
      brightness: Brightness.dark,
      scaffoldBg: _darkBackground,
      cardColor: _darkBackground,
      appBarBg: _darkBackground,
      appBarFg: Colors.white,
    );
  }

  /// 🔧 Shared Theme Builder
  static ThemeData _buildTheme({
    required Color seedColor,
    required Brightness brightness,
    required Color scaffoldBg,
    required Color cardColor,
    required Color appBarBg,
    required Color appBarFg,
    Color? inputFill,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),

      scaffoldBackgroundColor: scaffoldBg,

      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
        margin: EdgeInsets.zero,
      ),

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
      ),

      inputDecorationTheme: inputFill == null
          ? null
          : InputDecorationTheme(
              filled: true,
              fillColor: inputFill,
              border: const OutlineInputBorder(
                borderRadius: _inputRadius,
                borderSide: BorderSide.none,
              ),
            ),
    );
  }
}
