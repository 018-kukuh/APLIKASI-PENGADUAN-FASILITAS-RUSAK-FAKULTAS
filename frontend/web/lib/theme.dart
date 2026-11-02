import 'package:flutter/material.dart';

/// Warna diambil dari logo Universitas Madura.
const kNavy = Color(0xFF14196B);
const kNavyLight = Color(0xFF2A31A8);
const kRed = Color(0xFFD71920);
const kGold = Color(0xFFFFC82C);
const kBg = Color(0xFFF3F5FB);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kNavy,
    primary: kNavy,
    secondary: kGold,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kNavy, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: kNavy.withAlpha(30),
      checkmarkColor: kNavy,
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: kGold.withAlpha(140),
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
    ),
  );
}
