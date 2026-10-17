import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino progress indicator from a [LanguageProgressSpec] (§9
/// Progress).
///
/// Mapped in both of the spec's states, which the library answers with two
/// different widgets: a known fraction is `cu.CupertinoLinearActivityIndicator`
/// — the fork's own linear bar, whose `progress` is the same 0..1 the contract
/// carries — and a null one is `cu.CupertinoActivityIndicator`, the spinning tick
/// ring iOS uses while work has no measurable end. Two iOS widgets answer the two
/// states; one Material bar with a marquee would answer both.
///
/// The fill colour follows the token, because a bar that is `warning` yellow in
/// this app stays `warning` yellow in iOS; the track, the cap shape and the spin
/// are the library's. [LanguageProgressSpec.height] is the linear bar's own
/// thickness parameter, and it means nothing to a round spinner, so the spinner
/// keeps the library's radius.
///
/// [LanguageProgressSpec.showLabel] draws the percentage beside the bar, and only
/// when the value is known, since a spinner has no percentage to name.
abstract final class CupertinoProgressBuilder {
  /// Builds the indicator for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final theme = LiveTheme.of(context);
    final value = spec.value;

    if (value == null) {
      return cu.CupertinoActivityIndicator(color: spec.barColor);
    }

    final fraction = value.clamp(0.0, 1.0);
    final bar = cu.CupertinoLinearActivityIndicator(
      progress: fraction,
      height: spec.height,
      color: spec.barColor ?? theme.colors.primary,
    );
    if (!spec.showLabel) {
      return bar;
    }
    return Row(
      children: [
        Expanded(child: bar),
        SizedBox(width: theme.token.scale.sizes.sm),
        Text('${(fraction * 100).round()}%', style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
      ],
    );
  }
}
