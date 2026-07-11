import 'package:flutter/material.dart';

class DarkPalette {
  DarkPalette._();

  static const Color navyDeep = Color(0xFF060B14);
  static const Color navyBase = Color(0xFF0B1524);
  static const Color navyCard = Color(0xFF101E30);

  static const Color leafGreen = Color(0xFF3DDC84);
  static const Color leafGreenDeep = Color(0xFF1FA95C);
  static const Color cyanAccent = Color(0xFF4FD8E8);

  static const Color textPrimary = Color(0xFFF4F8F6);
  static const Color textSecondary = Color(0xFF9AAAB8);
  static const Color textMuted = Color(0xFF63758A);

  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassFill = Color(0x14FFFFFF);

  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [leafGreen, cyanAccent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [navyDeep, navyBase, Color(0xFF0D1B2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}