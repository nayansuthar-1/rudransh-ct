import 'package:flutter/material.dart';

/// Custom design tokens that do not fit inside [ColorScheme].
///
/// Read them from any widget with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.sidebar,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.brandSoft,
    required this.ink,
    required this.slate,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color sidebar;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Primary action blue (the "Add Payment" button in the reference UI).
  final Color brand;
  final Color brandSoft;

  /// Dark button ("Add Agent").
  final Color ink;

  /// Neutral dark button ("नया सदस्य जोड़ें").
  final Color slate;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  static const light = AppColors(
    canvas: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF8FAFC),
    sidebar: Color(0xFFFFFFFF),
    border: Color(0xFFE7EAF0),
    borderStrong: Color(0xFFD3D9E3),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF5B6472),
    textMuted: Color(0xFF98A2B3),
    brand: Color(0xFF2563EB),
    brandSoft: Color(0xFFEAF1FF),
    ink: Color(0xFF2F2A45),
    slate: Color(0xFF4B5563),
    success: Color(0xFF15803D),
    successSoft: Color(0xFFE6F6EC),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFDECEC),
    info: Color(0xFF1D4ED8),
    infoSoft: Color(0xFFE8EFFF),
  );

  static const dark = AppColors(
    canvas: Color(0xFF0F1420),
    surface: Color(0xFF161C2A),
    surfaceMuted: Color(0xFF1C2334),
    sidebar: Color(0xFF131926),
    border: Color(0xFF27303F),
    borderStrong: Color(0xFF394356),
    textPrimary: Color(0xFFE8ECF3),
    textSecondary: Color(0xFF9AA5B6),
    textMuted: Color(0xFF6B7688),
    brand: Color(0xFF60A5FA),
    brandSoft: Color(0xFF1B2740),
    ink: Color(0xFF3B3560),
    slate: Color(0xFF394253),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF14301F),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF37280A),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3A1A1A),
    info: Color(0xFF93B4FF),
    infoSoft: Color(0xFF1A2540),
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? sidebar,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brand,
    Color? brandSoft,
    Color? ink,
    Color? slate,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      sidebar: sidebar ?? this.sidebar,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      ink: ink ?? this.ink,
      slate: slate ?? this.slate,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      sidebar: c(sidebar, other.sidebar),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      brand: c(brand, other.brand),
      brandSoft: c(brandSoft, other.brandSoft),
      ink: c(ink, other.ink),
      slate: c(slate, other.slate),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
