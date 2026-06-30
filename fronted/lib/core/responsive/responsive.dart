import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities for the KINETIC app.
/// Handles mobile (<600dp) and tablet (≥600dp) layouts.
class Responsive {
  Responsive._();

  // ── Breakpoints ──
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  /// Returns true if the screen is a mobile device.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  /// Returns true if the screen is a tablet.
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  /// Returns true if the screen is a large tablet / small desktop.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// Returns the screen width.
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Returns the screen height.
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  // ── Scaling ──

  /// Horizontal padding based on screen size.
  static double horizontalPadding(BuildContext context) =>
      isMobile(context) ? 24.0 : 40.0;

  /// Content max-width for centering on large screens.
  static double contentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 960;
    if (isTablet(context)) return 720;
    return double.infinity;
  }

  /// Font scale factor for tablet (slightly larger text).
  static double fontScale(BuildContext context) =>
      isMobile(context) ? 1.0 : 1.1;

  /// Scale a value based on device type.
  static double value(BuildContext context, {
    required double mobile,
    required double tablet,
  }) =>
      isMobile(context) ? mobile : tablet;

  /// Grid cross-axis count based on screen size.
  static int gridColumns(BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Returns a different widget based on screen size.
  static T choose<T>(BuildContext context, {
    required T mobile,
    required T tablet,
  }) =>
      isMobile(context) ? mobile : tablet;
}

/// Widget that builds different layouts based on screen size.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isMobile, bool isTablet)
      builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(
          context,
          constraints.maxWidth < Responsive.mobileBreakpoint,
          constraints.maxWidth >= Responsive.mobileBreakpoint,
        );
      },
    );
  }
}

/// Wraps content in a centered, max-width constrained container for tablets.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
        );
    final effectiveMaxWidth =
        maxWidth ?? Responsive.contentMaxWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}
