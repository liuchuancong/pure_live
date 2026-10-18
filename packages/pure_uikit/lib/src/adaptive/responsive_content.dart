import 'package:flutter/widgets.dart';

import 'package:pure_uikit/src/adaptive/adaptive_breakpoints.dart';

/// Centers page content and applies breakpoint-aware gutters.
///
/// [ResponsiveContent] is intentionally layout-only: it does not impose a
/// scroll view, so it can wrap a [CustomScrollView], a dashboard column, or a
/// single card. The default maximum width keeps ultra-wide windows readable.
class ResponsiveContent extends StatelessWidget {
  /// Lays [child] out inside the adaptive gutters.
  const new({
    required this.child,
    this.maxWidth = AdaptiveShellDefault.maxContentWidth,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// The content.
  final Widget child;

  /// Maximum content width; [double.infinity] fills the viewport.
  final double maxWidth;

  /// Additional padding applied inside the adaptive gutters.
  final EdgeInsetsGeometry padding;

  /// The alignment when the window is wider than [maxWidth].
  final AlignmentGeometry alignment;

  /// Resolves the gutter for the width of the given [context].
  static double gutterOf(BuildContext context) => AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoints.of(context));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 0;
        final gutter = AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoints.fromWidth(width));

        Widget content = Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Padding(padding: padding, child: child),
        );

        if (maxWidth.isFinite) {
          content = ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: content);
        }

        return Align(alignment: alignment, child: content);
      },
    );
  }
}

/// A sliver version of [ResponsiveContent] for custom scroll views.
class SliverResponsiveContent extends StatelessWidget {
  /// Pads [sliver] with the adaptive gutters.
  const new({
    required this.sliver,
    this.maxWidth = AdaptiveShellDefault.maxContentWidth,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The content sliver.
  final Widget sliver;

  /// Maximum content width; [double.infinity] fills the viewport.
  final double maxWidth;

  /// Additional padding applied inside the adaptive gutters.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final gutter = AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoints.fromWidth(width));
        final sideInset = maxWidth.isFinite && width > maxWidth ? (width - maxWidth) / 2 + gutter : gutter;

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: sideInset),
          sliver: SliverPadding(padding: padding, sliver: sliver),
        );
      },
    );
  }
}

/// Defaults shared by the adaptive layout primitives.
abstract final class AdaptiveShellDefault {
  /// The widest page content.
  static const double maxContentWidth = 1440;
}
