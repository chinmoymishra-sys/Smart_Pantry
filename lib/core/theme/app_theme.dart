import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.textMuted,
      onSecondary: c.surface,
      error: c.danger,
      onError: c.surface,
      surface: c.surface,
      onSurface: c.textPrimary,
      outline: c.border,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: c.background,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: AppTypography.fontFamily,
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.textPrimary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.primary,
        contentTextStyle: AppTypography.body.copyWith(color: c.onPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
