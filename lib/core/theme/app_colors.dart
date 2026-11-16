import 'package:flutter/material.dart';

/// Colour tokens extracted from the Smart Pantry design (light and dark
/// frames). Values were read from the Figma export's vector fills; see
/// docs/IMPLEMENTATION_NOTES.md for the light → dark mapping.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.primaryBorder,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.cameraSurface,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color primaryBorder;
  final Color warning;
  final Color warningSurface;
  final Color danger;
  final Color dangerSurface;

  /// Dark scanner / viewfinder backdrop (stays dark in both themes).
  final Color cameraSurface;

  static const light = AppColors(
    background: Color(0xFFF9FAFB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF3F4F6),
    border: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF111827),
    textMuted: Color(0xFF6B7280),
    primary: Color(0xFF111827),
    onPrimary: Color(0xFFFFFFFF),
    primaryBorder: Color(0xFF111827),
    warning: Color(0xFFB45309),
    warningSurface: Color(0xFFFFFBEB),
    danger: Color(0xFFB91C1C),
    dangerSurface: Color(0xFFFEF2F2),
    cameraSurface: Color(0xFF111827),
  );

  static const dark = AppColors(
    background: Color(0xFF0F141B),
    surface: Color(0xFF111827),
    surfaceMuted: Color(0xFF1F2937),
    border: Color(0xFF1F2937),
    textPrimary: Color(0xFFF9FAFB),
    textMuted: Color(0xFF9CA3AF),
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF111827),
    primaryBorder: Color(0xFFE5E7EB),
    warning: Color(0xFFF59E0B),
    warningSurface: Color(0xFF292113),
    danger: Color(0xFFFCA5A5),
    dangerSurface: Color(0xFF2A171B),
    cameraSurface: Color(0xFF0B0F14),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textMuted,
    Color? primary,
    Color? onPrimary,
    Color? primaryBorder,
    Color? warning,
    Color? warningSurface,
    Color? danger,
    Color? dangerSurface,
    Color? cameraSurface,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryBorder: primaryBorder ?? this.primaryBorder,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      cameraSurface: cameraSurface ?? this.cameraSurface,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textMuted: l(textMuted, other.textMuted),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryBorder: l(primaryBorder, other.primaryBorder),
      warning: l(warning, other.warning),
      warningSurface: l(warningSurface, other.warningSurface),
      danger: l(danger, other.danger),
      dangerSurface: l(dangerSurface, other.dangerSurface),
      cameraSurface: l(cameraSurface, other.cameraSurface),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
