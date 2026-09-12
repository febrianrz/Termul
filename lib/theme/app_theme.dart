import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0E1116),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF12161C),
        elevation: 0,
      ),
    );
  }
}
