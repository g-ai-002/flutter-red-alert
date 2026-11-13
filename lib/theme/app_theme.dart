import 'package:flutter/material.dart';

import '../utils/system_ui.dart';

export 'palette.dart';

/// 深色：炭黑底 + 赤红强调，贴合战场氛围。
ThemeData buildDarkTheme({String? fontFamily}) {
  const scheme = ColorScheme.dark(
    primary: Color(0xFFE06A55),
    onPrimary: Color(0xFF2A0B06),
    primaryContainer: Color(0xFF5C1E15),
    onPrimaryContainer: Color(0xFFFADBD2),
    secondary: Color(0xFFD9A94B),
    onSecondary: Color(0xFF2E2210),
    surface: Color(0xFF1D1B18),
    onSurface: Color(0xFFEDE4D4),
    surfaceContainerHighest: Color(0xFF282521),
    onSurfaceVariant: Color(0xFFA99E8C),
    outline: Color(0xFF3B3730),
    outlineVariant: Color(0xFF2C2924),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF3A0A08),
    tertiary: Color(0xFF8FBFAE),
    surfaceTint: Colors.transparent,
  );
  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: const Color(0xFF141311),
    fontFamily: fontFamily,
  );
}

/// 浅色：沙纸底 + 钢灰文字，适合白天查看资料与设置。
ThemeData buildLightTheme({String? fontFamily}) {
  const scheme = ColorScheme.light(
    primary: Color(0xFFB03A2E),
    onPrimary: Color(0xFFFFF8F2),
    primaryContainer: Color(0xFFF3DCD4),
    onPrimaryContainer: Color(0xFF5A1A10),
    secondary: Color(0xFF8A6A33),
    onSecondary: Color(0xFFFFF8F2),
    surface: Color(0xFFFFFBF4),
    onSurface: Color(0xFF2A2620),
    surfaceContainerHighest: Color(0xFFEFE6D6),
    onSurfaceVariant: Color(0xFF746B5D),
    outline: Color(0xFFDDD2BE),
    outlineVariant: Color(0xFFE9E0CF),
    error: Color(0xFFB3261E),
    tertiary: Color(0xFF3F6B5B),
    surfaceTint: Colors.transparent,
  );
  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: const Color(0xFFF5EDDD),
    fontFamily: fontFamily,
  );
}

ThemeData _buildBase({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
  String? fontFamily,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: fontFamily,
  );
  final textTheme = base.textTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    fontFamily: fontFamily,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemOverlayStyleFor(scaffoldColor),
      toolbarHeight: 52,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: fontFamily),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: fontFamily),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      side: BorderSide(color: colorScheme.outline),
      shape: const StadiumBorder(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(fontSize: 13, color: colorScheme.onSurface, fontFamily: fontFamily),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.6),
      thickness: 0.6,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
