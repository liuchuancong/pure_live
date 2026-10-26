import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/shared/widgets/loading_style_animations.dart';

/// The app's loading animation, following the appearance choice.
///
/// Every style the reference offers is drawn by the same three packages the
/// reference uses, so a stored key reads the same here; [kLoadingStyleKeys]
/// is that list. The default is the design system's own spinner, which keeps
/// its reduced-motion pulse.
///
/// Use this for page, panel and list loading states. An inline busy mark on
/// a small control keeps `DsSpinner`: the multi-dot styles are not legible
/// at 12–14 px.
class AppLoadingIndicator extends ConsumerWidget {
  /// Creates the loader.
  ///
  /// [size] defaults to the ambient icon size like `DsSpinner`; [color]
  /// defaults to the appearance setting, then the ambient icon colour and
  /// the theme's accent.
  const AppLoadingIndicator({this.size, this.color, this.semanticLabel, super.key});

  /// The box's square side in logical pixels; null follows the icon theme.
  final double? size;

  /// The animation's ink; null follows the loading-colour setting and the
  /// ambient icon colour.
  final Color? color;

  /// Announced by screen readers; null keeps the loader decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(loadingStyleProvider);
    final configured = ref.watch(loadingColorProvider);
    final icon = IconTheme.of(context);
    final dimension = size ?? (icon.size == null ? 14.0 : icon.size! * 14 / 16);
    final colors = DsTheme.colorsOf(context);
    final tint = color ?? configured ?? icon.color ?? colors.accent;
    final Widget loading;
    if (style == 'default') {
      loading = DsSpinner(style: DsSpinnerStyle(size: dimension, color: tint));
    } else {
      final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      loading = TickerMode(
        enabled: !reduced,
        child: SizedBox.square(
          dimension: dimension,
          child: loadingStyleAnimation(
            style,
            color: tint,
            secondary: colors.accent,
            size: dimension,
          ),
        ),
      );
    }
    if (semanticLabel == null) return loading;
    return Semantics(label: semanticLabel, liveRegion: true, child: loading);
  }
}
