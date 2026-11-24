import 'package:flutter/material.dart';

/// Design Token SIAKAR sesuai DESIGN.md §6
class Tk {
  // Warna Utama
  static const primary = Color(0xFF338F4A);
  static const primaryDark = Color(0xFF1F6B33);
  static const navy = Color(0xFF1E1E49);
  static const background = Color(0xFFFFFEF2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceTint = Color(0xFFF1F7EF);
  static const outline = Color(0xFFCFDDD2);
  static const textMuted = Color(0xFF5B5B7A);
  static const onPrimary = Color(0xFFFFFFFF);

  // Status Kehadiran (DESIGN.md §6.1)
  static const hadirText = Color(0xFF1F6B33);
  static const hadirBg = Color(0xFFE3F3E7);

  static const terlambatText = Color(0xFF9A5B00);
  static const terlambatBg = Color(0xFFFFF1D6);

  static const izinText = Color(0xFF1F4E8C);
  static const izinBg = Color(0xFFE1ECFA);

  static const alpaText = Color(0xFFA32121);
  static const alpaBg = Color(0xFFFBE3E3);

  static const menungguText = Color(0xFF5B5B7A);
  static const menungguBg = Color(0xFFECECF4);

  // Bentuk & Radius (DESIGN.md §6.3)
  static const radiusCard = 12.0;
  static const radiusInput = 10.0;
  static const radiusButton = 12.0;
  static const radiusChip = 999.0;

  // Jarak (Kelipatan 4)
  static const spacing4 = 4.0;
  static const spacing8 = 8.0;
  static const spacing12 = 12.0;
  static const spacing16 = 16.0;
  static const spacing24 = 24.0;
  static const spacing32 = 32.0;

  // Target sentuh minimum
  static const minTouchTarget = 48.0;
}
