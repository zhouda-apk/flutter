import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  // 初始化 sqflite 數據庫工廠（非 Web 平台）
  if (!isWeb()) {
    sqfliteFfiInit();
  }
  runApp(const OcrNotesApp());
}

/// 檢查是否為 Web 平台
bool isWeb() {
  try {
    return identical(0, 0.0) == false;
  } catch (_) {
    return true;
  }
}

class OcrNotesApp extends StatelessWidget {
  const OcrNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR 筆記',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          primary: const Color(0xFF6C63FF),
        ),
        fontFamily: 'NotoSansTC',
        scaffoldBackgroundColor: const Color(0xFFF5F4F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
