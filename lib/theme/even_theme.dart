import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// EVEN's visual language: quiet surfaces, confident indigo, clear financial states.
abstract final class EvenPalette {
  static const canvas = Color(0xFFF5F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF0F1F8);
  static const ink = Color(0xFF191B2E);
  static const muted = Color(0xFF777C91);
  static const primary = Color(0xFF5148D9);
  static const primaryDeep = Color(0xFF29265F);
  static const primarySoft = Color(0xFFE9E8FF);
  static const border = Color(0xFFE8E9F1);
  static const positive = Color(0xFF087F62);
  static const positiveSoft = Color(0xFFE1F6EE);
  static const negative = Color(0xFFB94D5B);
  static const negativeSoft = Color(0xFFFCEBED);
  static const warm = Color(0xFFFFF2DE);
}

abstract final class EvenTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: EvenPalette.primary,
      brightness: Brightness.light,
      primary: EvenPalette.primary,
      surface: EvenPalette.canvas,
      error: EvenPalette.negative,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: EvenPalette.canvas,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: EvenPalette.canvas,
        foregroundColor: EvenPalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: EvenPalette.ink, fontSize: 20, fontWeight: FontWeight.w700,
          letterSpacing: -0.45,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: EvenPalette.ink, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.9),
        titleLarge: TextStyle(color: EvenPalette.ink, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.45),
        titleMedium: TextStyle(color: EvenPalette.ink, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: EvenPalette.ink, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: EvenPalette.muted, fontSize: 13, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
      ),
      cardTheme: CardThemeData(
        color: EvenPalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: EvenPalette.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EvenPalette.surfaceSubtle,
        hintStyle: const TextStyle(color: EvenPalette.muted),
        labelStyle: const TextStyle(color: EvenPalette.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: EvenPalette.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: EvenPalette.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: EvenPalette.negative)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: EvenPalette.surface,
        indicatorColor: EvenPalette.primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? EvenPalette.primary : EvenPalette.muted,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? EvenPalette.primary : EvenPalette.muted,
        )),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: EvenPalette.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: EvenPalette.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: EvenPalette.border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: EvenPalette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: EvenPalette.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      )),
    );
  }
}
