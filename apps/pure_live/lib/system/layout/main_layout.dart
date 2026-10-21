import 'package:flutter/widgets.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Shared spacing for the main application pages.
///
/// The values mirror the reference: a compact phone margin, a wider tablet
/// gutter, and a generous desktop canvas that stops growing at a readable
/// maximum rather than stretching cards across an ultrawide window.
abstract final class MainLayout {
  /// The widest page content on desktop.
  static const double maxContentWidth = 1440;

  /// The horizontal page gutter for the current window width — the adaptive
  /// breakpoint ladder (16 / 24 / 32 / 40), so every page agrees with the
  /// shell on how much air a width class gets.
  static double gutterOf(BuildContext context) => AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoints.of(context));

  /// Content padding for a page body: the gutter, with extra air at the top and
  /// bottom of a scroll.
  static EdgeInsets bodyPadding(BuildContext context, {double top = 8, double bottom = 24}) {
    final gutter = gutterOf(context);
    return EdgeInsets.fromLTRB(gutter, top, gutter, bottom);
  }
}
