import 'package:flutter/material.dart';

abstract final class K {
  // 現場の黒板っぽい深緑 + 安全オレンジ（出面の紺・琥珀とは別の見た目）
  static const green = Color(0xFF23463B);
  static const greenDeep = Color(0xFF17312A);
  static const orange = Color(0xFFE8590C);
  static const paper = Color(0xFFF7F6F1);
  static const grid = Color(0xFFE4E1D8);
  static const off = Color(0xFFECEAE3);
  static const ink = Color(0xFF1D2321);
  static const muted = Color(0xFF66706B);
  static const sunday = Color(0xFFC0392B);
  static const saturday = Color(0xFF2E6DB4);
  static const todayFill = Color(0x1FE8590C);

  /// 現場の色（8色）
  static const siteColors = [
    Color(0xFF2F80C8), // 青
    Color(0xFFE07A1F), // 橙
    Color(0xFF2E9D5B), // 緑
    Color(0xFFC2416B), // 赤紫
    Color(0xFF7A55C7), // 紫
    Color(0xFF1F9AA5), // 青緑
    Color(0xFFB08A1E), // 黄土
    Color(0xFF6B7280), // 灰
  ];
  static const siteColorNames = ['青', '橙', '緑', '赤紫', '紫', '青緑', '黄土', '灰'];
  static Color site(int i) => siteColors[i % siteColors.length];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansJP',
    colorScheme: ColorScheme.fromSeed(
      seedColor: K.green,
      primary: K.green,
      secondary: K.orange,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: K.paper,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: K.green,
      foregroundColor: Colors.white,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansJP',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: K.orange,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: K.green,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
