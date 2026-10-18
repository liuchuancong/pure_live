import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart' as screenutil;

/// The four layout classes used by the adaptive shell.
///
/// The thresholds are deliberately tuned for a media application rather than
/// generic web breakpoints:
///
/// | Class | Width | Navigation |
/// | --- | --- | --- |
/// | compact | `< 600` | bottom bar or drawer |
/// | medium | `600 - 1023` | icon rail |
/// | expanded | `1024 - 1439` | labelled sidebar |
/// | large | `>= 1440` | labelled sidebar / TV rail |
enum AdaptiveBreakpoint {
  /// `< 600` — phone width: bottom bar or drawer.
  compact(minWidth: 0, label: 'Compact'),

  /// `600 - 1023` — tablet width: icon rail.
  medium(minWidth: 600, label: 'Medium'),

  /// `1024 - 1439` — desktop width: labelled sidebar.
  expanded(minWidth: 1024, label: 'Expanded'),

  /// `>= 1440` — wide desktop: labelled sidebar.
  large(minWidth: 1440, label: 'Large');

  new({required this.minWidth, required this.label});

  /// Inclusive lower bound of this class in logical pixels.
  final double minWidth;

  /// Human-readable name, useful in debug overlays.
  final String label;

  /// Whether this is the narrowest class.
  bool get isCompact => this == AdaptiveBreakpoint.compact;

  /// Whether this is the `600 - 1023` class.
  bool get isMedium => this == AdaptiveBreakpoint.medium;

  /// Whether this is the `1024 - 1439` class.
  bool get isExpanded => this == AdaptiveBreakpoint.expanded;

  /// Whether this is the widest class.
  bool get isLarge => this == AdaptiveBreakpoint.large;

  /// Whether this class is medium or wider.
  bool get isAtLeastMedium => index >= AdaptiveBreakpoint.medium.index;

  /// Whether this class is expanded or wider.
  bool get isAtLeastExpanded => index >= AdaptiveBreakpoint.expanded.index;

  /// Whether this class is [other] or wider.
  bool isAtLeast(AdaptiveBreakpoint other) => index >= other.index;

  /// Whether this class is narrower than [other].
  bool isSmallerThan(AdaptiveBreakpoint other) => index < other.index;

  /// The next wider class, null at the top.
  AdaptiveBreakpoint? get next {
    final nextIndex = index + 1;
    return nextIndex < AdaptiveBreakpoint.values.length ? AdaptiveBreakpoint.values[nextIndex] : null;
  }

  /// The next narrower class, null at the bottom.
  AdaptiveBreakpoint? get previous {
    final previousIndex = index - 1;
    return previousIndex >= 0 ? AdaptiveBreakpoint.values[previousIndex] : null;
  }

  /// Picks a value for the current class while falling back to the nearest
  /// defined class.
  T resolve<T>({required T compact, T? medium, T? expanded, T? large}) {
    return switch (this) {
      AdaptiveBreakpoint.compact => compact,
      AdaptiveBreakpoint.medium => medium ?? compact,
      AdaptiveBreakpoint.expanded => expanded ?? medium ?? compact,
      AdaptiveBreakpoint.large => large ?? expanded ?? medium ?? compact,
    };
  }
}

/// Breakpoint helpers backed by `flutter_screenutil_plus`.
///
/// `flutter_screenutil_plus` supplies the CSS-like [screenutil.Breakpoints]
/// model and the container-aware `screenutil.LayoutScope`. Using a layout
/// scope means nested panes (for example a split view) respond to their own
/// width instead of the viewport width.
abstract final class AdaptiveBreakpoints {
  /// The class lower bounds, in logical pixels.
  static const double compact = 0;

  /// The medium class lower bound.
  static const double medium = 600;

  /// The expanded class lower bound.
  static const double expanded = 1024;

  /// The large class lower bound.
  static const double large = 1440;

  /// The wide-window bound beyond which gutters stop growing.
  static const double wide = 1920;

  /// The adaptive shell's breakpoint configuration exposed for screenutil
  /// widgets.
  static const screenutil.Breakpoints screenUtil = screenutil.Breakpoints(
    sm: medium,
    md: expanded,
    lg: large,
    xl: wide,
    xxl: 2560,
  );

  /// Resolves an [AdaptiveBreakpoint] from a raw width.
  static AdaptiveBreakpoint fromWidth(double width) {
    if (!width.isFinite) {
      return AdaptiveBreakpoint.compact;
    }
    return switch (screenUtil.getBreakpoint(width)) {
      screenutil.Breakpoint.xs => AdaptiveBreakpoint.compact,
      screenutil.Breakpoint.sm => AdaptiveBreakpoint.medium,
      screenutil.Breakpoint.md => AdaptiveBreakpoint.expanded,
      screenutil.Breakpoint.lg => AdaptiveBreakpoint.large,
      screenutil.Breakpoint.xl => AdaptiveBreakpoint.large,
      screenutil.Breakpoint.xxl => AdaptiveBreakpoint.large,
    };
  }

  /// Resolves the breakpoint from the nearest screenutil layout scope.
  ///
  /// Outside a layout scope, the viewport width from [MediaQuery] is used.
  static AdaptiveBreakpoint of(BuildContext context) => fromWidth(widthOf(context));

  /// The width of the nearest layout scope, or the viewport width.
  static double widthOf(BuildContext context) => screenutil.LayoutScope.sizeOf(context).width;

  /// Sensible horizontal page gutters for each layout class.
  static double pageGutter(AdaptiveBreakpoint breakpoint) {
    return breakpoint.resolve<double>(compact: 16, medium: 24, expanded: 32, large: 40);
  }
}

/// Convenience accessors for the current adaptive layout class.
extension AdaptiveBreakpointContext on BuildContext {
  /// The layout class of the nearest layout scope (or viewport).
  AdaptiveBreakpoint get adaptiveBreakpoint => AdaptiveBreakpoints.of(this);

  /// Whether the window is in the compact class.
  bool get isCompactLayout => adaptiveBreakpoint.isCompact;

  /// Whether the window is in the medium class.
  bool get isMediumLayout => adaptiveBreakpoint.isMedium;

  /// Whether the window is in the expanded class.
  bool get isExpandedLayout => adaptiveBreakpoint.isExpanded;

  /// Whether the window is in the large class.
  bool get isLargeLayout => adaptiveBreakpoint.isLarge;

  /// Resolves a value using the current breakpoint.
  T adaptiveValue<T>({required T compact, T? medium, T? expanded, T? large}) {
    return adaptiveBreakpoint.resolve<T>(compact: compact, medium: medium, expanded: expanded, large: large);
  }

  /// The horizontal page gutter for the current breakpoint.
  double get pageGutter => AdaptiveBreakpoints.pageGutter(adaptiveBreakpoint);
}

/// Rebuilds when the nearest layout width changes class.
class AdaptiveBreakpointBuilder extends StatelessWidget {
  /// Builds [builder] with the current class.
  const new({required this.builder, super.key});

  /// Called with the resolved class.
  final Widget Function(BuildContext context, AdaptiveBreakpoint breakpoint) builder;

  @override
  Widget build(BuildContext context) => builder(context, AdaptiveBreakpoints.of(context));
}

/// A small debug label that makes breakpoint changes visible while developing.
class AdaptiveBreakpointBadge extends StatelessWidget {
  /// The debug badge.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final breakpoint = AdaptiveBreakpoints.of(context);
    return Semantics(
      label: 'Layout ${breakpoint.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xCC0B84F3), borderRadius: BorderRadius.circular(999)),
        child: Text(
          '${breakpoint.label} · ${AdaptiveBreakpoints.widthOf(context).round()}',
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
