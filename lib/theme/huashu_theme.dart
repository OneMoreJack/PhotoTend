import 'package:flutter/material.dart';

abstract final class HuashuColors {
  static const paper = Color(0xFFF4F0E8);
  static const paperWarm = Color(0xFFFBF7EF);
  static const surface = Color(0xFFFFFCF6);
  static const surfaceAlt = Color(0xFFEDE7DA);
  static const surfaceRaised = Color(0xFFFFFBF3);
  static const surfacePressed = Color(0xFFE8DFD1);
  static const ink = Color(0xFF171A1C);
  static const inkSoft = Color(0xFF343331);
  static const muted = Color(0xFF756F66);
  static const faint = Color(0xFFA99F91);
  static const line = Color(0xFFDCD3C5);
  static const accent = Color(0xFFB55A30);
  static const accentDeep = Color(0xFF7E351F);
  static const accentSoft = Color(0xFFF3D9C8);
  static const positive = Color(0xFF32795A);
  static const danger = Color(0xFFC9493A);
  static const dangerSoft = Color(0xFFFFE3E2);
  static const darkroom = Color(0xFF20201F);
  static const darkroomSoft = Color(0xFF30302E);
}

abstract final class HuashuTheme {
  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: HuashuColors.accent,
      brightness: Brightness.light,
      surface: HuashuColors.paper,
      primary: HuashuColors.accent,
      secondary: HuashuColors.darkroom,
      error: HuashuColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: HuashuColors.paper,
      fontFamily: 'SF Pro Text',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: HuashuColors.paper,
        foregroundColor: HuashuColors.ink,
        titleTextStyle: TextStyle(
          color: HuashuColors.ink,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.transparent),
      dividerTheme: const DividerThemeData(
        color: HuashuColors.line,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HuashuColors.darkroom,
        contentTextStyle: const TextStyle(
          color: HuashuColors.surface,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HuashuColors.accent,
          foregroundColor: HuashuColors.surface,
          disabledBackgroundColor: HuashuColors.line,
          disabledForegroundColor: HuashuColors.muted,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: HuashuColors.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HuashuColors.accent,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: HuashuColors.inkSoft,
          disabledForegroundColor: HuashuColors.faint,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HuashuColors.surface,
        modalBackgroundColor: HuashuColors.surface,
        dragHandleColor: HuashuColors.faint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HuashuColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
