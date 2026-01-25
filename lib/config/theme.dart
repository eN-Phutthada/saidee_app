import 'package:flutter/material.dart';

class AppTheme {
  // --- Color Palette (อิงตาม UI ใหม่) ---
  static const Color primaryColor = Color(0xFF2CB834); // เขียวสด (Main)
  static const Color darkGreen = Color(
    0xFF1B8022,
  ); // เขียวเข้ม (Background Shape)
  static const Color lightBg = Color(
    0xFFF5F9FF,
  ); // พื้นหลังขาวอมฟ้า (Light Mode)
  static const Color darkBg = Color(0xFF121212); // พื้นหลังดำ (Dark Mode)
  static const Color errorColor = Color(0xFFD32F2F);

  // --- Light Theme ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Kanit', // อย่าลืมลงทะเบียน Font ใน pubspec.yaml
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBg,

    // ตั้งค่าสีหลัก
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: primaryColor,
      surface: Colors.white,
      error: errorColor,
    ),

    // ตั้งค่า AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, // โปร่งใสเพื่อให้เห็น BG
      foregroundColor: Colors.black, // สีไอคอน/ข้อความ
      elevation: 0,
      centerTitle: true,
    ),

    // ตั้งค่าช่องกรอกข้อความ (Input Style)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white, // พื้นหลังช่องกรอกสีขาว
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // ไม่มีเส้นขอบ
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.5,
        ), // เวลาจิ้มมีขอบสีเขียว
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      hintStyle: TextStyle(color: Colors.grey[400]),
    ),

    // ตั้งค่าปุ่มกด (Button Style)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Kanit',
        ),
      ),
    ),

    // ปุ่มแบบมีขอบ (Outlined Button)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Kanit',
        ),
      ),
    ),
  );

  // --- Dark Theme ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Kanit',
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBg,

    // ตั้งค่าสี Dark Mode
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: primaryColor,
      surface: const Color(0xFF1E1E1E), // สีพื้นผิวของ Card ใน Dark Mode
      error: errorColor,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),

    // Input Style สำหรับ Dark Mode
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C), // พื้นหลังช่องกรอกสีเทาเข้ม
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      hintStyle: TextStyle(color: Colors.grey[600]),
    ),

    // Button Style สำหรับ Dark Mode
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Kanit',
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Kanit',
        ),
      ),
    ),
  );
}
