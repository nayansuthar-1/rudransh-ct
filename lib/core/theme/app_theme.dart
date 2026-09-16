import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Bundled families (see pubspec.yaml): Google Sans Flex, as used across
/// Gmail, for Latin text; Noto Sans Devanagari picks up every Hindi glyph.
const kFontFamily = 'AppSans';
const kFontFallback = <String>['NotoSansDevanagari'];

/// Equal-width digits so amounts and counts line up in columns.
const kTabular = <FontFeature>[FontFeature.tabularFigures()];

/// Corner radii: 8 for controls and panels, 12 for dialogs.
class Radii {
  const Radii._();

  static const double control = 8;
  static const double panel = 8;
  static const double dialog = 12;
  static const double pill = 6;
}

/// Spacing scale. Every gap in the layout is one of these.
class Space {
  const Space._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppColors.light);
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.brand,
      brightness: brightness,
    ).copyWith(
      primary: c.brand,
      onPrimary: c.onBrand,
      secondary: c.textSecondary,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.borderStrong,
      outlineVariant: c.border,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.surfaceMuted,
      error: c.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      fontFamily: kFontFamily,
      fontFamilyFallback: kFontFallback,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: c.hover,
      focusColor: c.hover,
      visualDensity: VisualDensity.standard,
      // Buttons set their own 34–42px minimum sizes; the default 48px
      // padding would make every table row 64px tall.
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(Radii.control)),
    );
    const buttonText = TextStyle(
      fontFamily: kFontFamily,
      fontFamilyFallback: kFontFallback,
      fontWeight: FontWeight.w500,
      fontSize: 14,
      letterSpacing: 0.1,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    const buttonMinSize = Size(0, 40);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: base.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
        fontFamily: kFontFamily,
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 18),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel),
          side: BorderSide(color: c.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.dialog),
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.sidebar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel),
          side: BorderSide(color: c.border),
        ),
        textStyle: TextStyle(
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
          fontSize: 13.5,
          color: c.textPrimary,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: kFontFamily,
            fontFamilyFallback: kFontFallback,
            fontSize: 13.5,
            color: c.textPrimary,
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.panel),
              side: BorderSide(color: c.border),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF3C4043),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF303030),
        actionTextColor: const Color(0xFFA8C7FA),
        elevation: 2,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brand,
        linearTrackColor: c.brandSoft,
        circularTrackColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
        border: _outline(c.borderStrong),
        enabledBorder: _outline(c.borderStrong),
        disabledBorder: _outline(c.border),
        focusedBorder: _outline(c.brand, width: 2),
        errorBorder: _outline(c.danger),
        focusedErrorBorder: _outline(c.danger, width: 2),
        errorStyle: TextStyle(color: c.danger, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          overlayColor: c.onBrand,
          disabledBackgroundColor: c.hover,
          disabledForegroundColor: c.textMuted,
          elevation: 0,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brand,
          backgroundColor: c.surface,
          side: BorderSide(color: c.borderStrong),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          shape: controlShape,
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(8),
          iconSize: 18,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onBrand : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : c.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onBrand),
        side: BorderSide(color: c.borderStrong, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.borderStrong,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.brandSoft,
        side: BorderSide(color: c.borderStrong),
        labelStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 13,
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
        ),
        checkmarkColor: c.onBrandSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.surface,
        headerForegroundColor: c.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.dialog),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.textMuted.withValues(alpha: 0.4)),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.control),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
