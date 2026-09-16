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
    required this.hover,
    required this.sidebar,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.onBrandSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
  });

  /// Page background.
  final Color canvas;

  /// Panels, dialogs, inputs.
  final Color surface;

  /// Quiet fill for table headers, selected rows and tracks.
  final Color surfaceMuted;

  /// Row and menu hover.
  final Color hover;
  final Color sidebar;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Primary action blue.
  final Color brand;
  final Color onBrand;

  /// Tonal blue for secondary emphasis: the "New" button, selected nav item,
  /// active filters.
  final Color brandSoft;
  final Color onBrandSoft;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  static const light = AppColors(
    canvas: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF8F9FA),
    hover: Color(0xFFF1F3F4),
    sidebar: Color(0xFFF8FAFD),
    border: Color(0xFFE3E5E8),
    borderStrong: Color(0xFFC7CACF),
    textPrimary: Color(0xFF1F1F1F),
    textSecondary: Color(0xFF444746),
    textMuted: Color(0xFF6F7378),
    brand: Color(0xFF0B57D0),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFD3E3FD),
    onBrandSoft: Color(0xFF041E49),
    success: Color(0xFF146C2E),
    successSoft: Color(0xFFE6F4EA),
    warning: Color(0xFF9A5B00),
    warningSoft: Color(0xFFFEF3D9),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFCE8E6),
    info: Color(0xFF0B57D0),
    infoSoft: Color(0xFFE8F0FE),
  );

  static const dark = AppColors(
    canvas: Color(0xFF131314),
    surface: Color(0xFF1B1B1D),
    surfaceMuted: Color(0xFF232326),
    hover: Color(0xFF2A2A2D),
    sidebar: Color(0xFF131314),
    border: Color(0xFF303134),
    borderStrong: Color(0xFF45474A),
    textPrimary: Color(0xFFE3E3E3),
    textSecondary: Color(0xFFC4C7C5),
    textMuted: Color(0xFF8E918F),
    brand: Color(0xFFA8C7FA),
    onBrand: Color(0xFF062E6F),
    brandSoft: Color(0xFF0842A0),
    onBrandSoft: Color(0xFFD3E3FD),
    success: Color(0xFF6DD58C),
    successSoft: Color(0xFF0F3A1D),
    warning: Color(0xFFF6C35B),
    warningSoft: Color(0xFF3B2B06),
    danger: Color(0xFFF2B8B5),
    dangerSoft: Color(0xFF4F1612),
    info: Color(0xFFA8C7FA),
    infoSoft: Color(0xFF0B2A5C),
  );

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? hover,
    Color? sidebar,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brand,
    Color? onBrand,
    Color? brandSoft,
    Color? onBrandSoft,
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
      hover: hover ?? this.hover,
      sidebar: sidebar ?? this.sidebar,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      brandSoft: brandSoft ?? this.brandSoft,
      onBrandSoft: onBrandSoft ?? this.onBrandSoft,
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
      hover: c(hover, other.hover),
      sidebar: c(sidebar, other.sidebar),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      brand: c(brand, other.brand),
      onBrand: c(onBrand, other.onBrand),
      brandSoft: c(brandSoft, other.brandSoft),
      onBrandSoft: c(onBrandSoft, other.onBrandSoft),
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
