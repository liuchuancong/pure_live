import 'package:flutter/material.dart';

import 'package:pure_uikit/src/adaptive/adaptive_breakpoints.dart';

/// A two-pane content layout that collapses to a vertical flow.
///
/// The layout also checks a minimum primary width so the two-pane split never
/// becomes too cramped just above the breakpoint.
class AdaptiveContentLayout extends StatelessWidget {
  /// Splits [primary] and [secondary] side by side from [sideBySideAt].
  const new({
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 304,
    this.minimumPrimaryWidth = 520,
    this.gap = 24,
    this.sideBySideAt = AdaptiveBreakpoint.expanded,
    this.secondaryFirst = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  /// The main pane.
  final Widget primary;

  /// The side pane.
  final Widget secondary;

  /// Fixed width of the secondary pane on wide layouts.
  final double secondaryWidth;

  /// The split falls back to a column when the primary pane would be narrower.
  final double minimumPrimaryWidth;

  /// The gap between the panes.
  final double gap;

  /// The class from which the panes sit side by side.
  final AdaptiveBreakpoint sideBySideAt;

  /// Whether the secondary pane leads.
  final bool secondaryFirst;

  /// The row's cross alignment.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 0;
        final breakpoint = AdaptiveBreakpoints.fromWidth(width);
        final wideEnough =
            breakpoint.isAtLeast(sideBySideAt) && width >= secondaryWidth + gap + minimumPrimaryWidth;

        if (!wideEnough) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              primary,
              SizedBox(height: gap),
              secondary,
            ],
          );
        }

        final Widget primaryPane = Expanded(child: primary);
        final Widget secondaryPane = SizedBox(width: secondaryWidth, child: secondary);

        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: <Widget>[
            if (secondaryFirst) ...<Widget>[secondaryPane, SizedBox(width: gap), primaryPane] else ...<Widget>[
              primaryPane,
              SizedBox(width: gap),
              secondaryPane,
            ],
          ],
        );
      },
    );
  }
}
