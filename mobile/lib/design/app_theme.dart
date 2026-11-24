import 'package:flutter/material.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Tk.background,
      fontFamily: 'DM Sans',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Tk.primary,
        onPrimary: Tk.onPrimary,
        secondary: Tk.navy,
        onSecondary: Tk.onPrimary,
        error: Tk.alpaText,
        onError: Tk.onPrimary,
        surface: Tk.surface,
        onSurface: Tk.navy,
        outline: Tk.outline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Tk.navy,
        foregroundColor: Tk.onPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Tk.onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Tk.primary,
          foregroundColor: Tk.onPrimary,
          minimumSize: const Size(double.infinity, Tk.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tk.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Tk.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tk.radiusInput),
          borderSide: const BorderSide(color: Tk.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tk.radiusInput),
          borderSide: const BorderSide(color: Tk.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tk.radiusInput),
          borderSide: const BorderSide(color: Tk.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tk.radiusInput),
          borderSide: const BorderSide(color: Tk.alpaText),
        ),
        labelStyle: const TextStyle(color: Tk.textMuted),
        hintStyle: const TextStyle(color: Tk.textMuted),
      ),
      cardTheme: CardThemeData(
        color: Tk.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tk.radiusCard),
          side: const BorderSide(color: Tk.outline),
        ),
      ),
    );
  }
}
