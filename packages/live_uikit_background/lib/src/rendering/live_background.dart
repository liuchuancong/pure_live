/// The single entry point every page and adapter uses to paint a
/// background.
///
/// [LiveBackground] reads the sealed [BackgroundConfig], dispatches to
/// the matching view and lays the caller's child on top. Style adapters
/// must not re-implement BoxFit, placeholder, failure fallback, underlay
/// or video pause — they compose this widget the same way business
/// pages do.
///
/// Passing `null` for `config` keeps the widget tree stable when a
/// caller toggles the background on and off: the same `Stack` shape is
/// rendered in both states with an empty placeholder below the child,
/// so a page or route hosting the dispatcher is never remounted when
/// the user selects or clears a wallpaper.
///
/// `paused` is a caller-owned runtime signal; the video view forwards
/// it to the `BackgroundVideoSource` so an app-level state manager
/// (Riverpod, GetX, a route-aware observer, ...) can decide when the
/// background should stop decoding. This package does not read
/// `AppLifecycleState` on its own.
library;

import 'package:flutter/widgets.dart';
import 'package:live_uikit_background/src/models/background_config/background_config.dart';
import 'package:live_uikit_background/src/rendering/background_layer_stack_view.dart';
import 'package:live_uikit_background/src/rendering/background_overlay_view.dart';
import 'package:live_uikit_background/src/rendering/gradient_background_view.dart';
import 'package:live_uikit_background/src/rendering/image_background_view.dart';
import 'package:live_uikit_background/src/rendering/solid_background_view.dart';
import 'package:live_uikit_background/src/rendering/video_background_view.dart';

/// Paints [config] behind [child], filling the parent's box.
///
/// Wrap the widget in a `Positioned.fill` or `Stack` when composing it
/// with foreground content, or use it as the outer container of a page.
/// When [clip] is not `null` the background and its child are clipped
/// to [borderRadius], which is what rounded cards and TV tiles need
/// without each surface writing its own ClipRRect.
class LiveBackground extends StatelessWidget {
  /// Renders [config] (or an empty placeholder when `null`) and layers
  /// [child] on top.
  const new({required this.config, this.child, this.clip, this.borderRadius, this.paused = false, super.key});

  /// The background description to paint. `null` renders an empty base
  /// layer so callers can toggle the background without remounting
  /// their subtree.
  final BackgroundConfig? config;

  /// Foreground content placed above the background.
  final Widget? child;

  /// Optional clip applied to the whole stack; keep `null` for pages.
  final Clip? clip;

  /// Corner radius used when [clip] is set.
  final BorderRadius? borderRadius;

  /// Forwarded to [VideoBackgroundView]; ignored by every other view.
  /// The caller owns the policy — this widget never queries the
  /// framework's lifecycle on its own.
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final body = Stack(fit: StackFit.expand, children: [_renderBase(config), ?child]);
    final behavior = clip;
    if (behavior == null) return body;
    return ClipRRect(clipBehavior: behavior, borderRadius: borderRadius ?? BorderRadius.zero, child: body);
  }

  Widget _renderBase(BackgroundConfig? config) {
    if (config == null) return const SizedBox.shrink();
    final painted = switch (config) {
      final SolidBackground solid => SolidBackgroundView(config: solid),
      final GradientBackground gradient => GradientBackgroundView(config: gradient),
      final ImageBackground image => ImageBackgroundView(config: image),
      final VideoBackground video => VideoBackgroundView(config: video, paused: paused),
      final BackgroundLayerStack stack => BackgroundLayerStackView(stack: stack),
    };
    return BackgroundOverlayView(overlay: config.overlay, child: painted);
  }
}
