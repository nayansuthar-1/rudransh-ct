import 'package:flutter/widgets.dart';

enum ScreenSize { mobile, tablet, laptop, desktop }

/// Layout breakpoints used across the admin panel.
class Breakpoints {
  const Breakpoints._();

  static const double mobile = 680;
  static const double tablet = 1024;
  static const double laptop = 1360;

  static ScreenSize of(double width) {
    if (width < mobile) return ScreenSize.mobile;
    if (width < tablet) return ScreenSize.tablet;
    if (width < laptop) return ScreenSize.laptop;
    return ScreenSize.desktop;
  }
}

extension ResponsiveContext on BuildContext {
  Size get screen => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;

  ScreenSize get screenSize => Breakpoints.of(screenWidth);

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isLaptop => screenSize == ScreenSize.laptop;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  /// True when the sidebar collapses into a drawer.
  bool get useDrawerNav => screenWidth < Breakpoints.tablet;

  /// True when the sidebar renders as a narrow icon rail.
  bool get useRailNav =>
      screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.laptop;

  /// Pick a value per breakpoint, falling back to the smaller definition.
  T responsive<T>({required T mobile, T? tablet, T? laptop, T? desktop}) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.laptop:
        return laptop ?? tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? laptop ?? tablet ?? mobile;
    }
  }

  /// Horizontal padding for page content.
  double get pageGutter =>
      responsive(mobile: 16, tablet: 24, laptop: 32, desktop: 32);
}
