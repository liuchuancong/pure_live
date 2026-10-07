import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/core/platform/platform_utils.dart';

/// The panel's physical cutout, in logical pixels.
///
/// Flutter's `MediaQuery.padding` is not enough for a video player. It is
/// derived from the window's *stable* insets, and this app asks Android for
/// `windowLayoutInDisplayCutoutMode=shortEdges`: with that mode the insets
/// collapse to zero the moment the status bar hides — which is exactly the
/// immersive fullscreen a player spends its time in. The cutout is a physical
/// feature of the panel, so the top controls of a portrait fullscreen ended up
/// partly under it even though the same bar cleared the status bar perfectly in
/// windowed mode.
///
/// The host answers the real numbers over `pure_live/display_cutout` (Android's
/// `DisplayCutout.safeInset*`); every other platform reports nothing and the
/// player falls back to `MediaQuery.padding`, which is correct there.
///
/// Responsibilities:
///
/// - own the host's cutout reading
/// - hand the player chrome an inset it can trust in any system-UI mode
///
/// It does not:
///
/// - draw anything
/// - decide where controls go (a player's chrome does)
class DisplayCutout {
  DisplayCutout._();

  static const MethodChannel _channel = MethodChannel('pure_live/display_cutout');

  /// The host's last reading; all zeros until one arrives.
  static final ValueNotifier<EdgeInsets> insets = ValueNotifier<EdgeInsets>(EdgeInsets.zero);

  static bool _supported = true;

  /// Asks the host for the panel's cutout insets.
  ///
  /// Safe to call repeatedly: the platform reports a fixed physical fact, and a
  /// platform without the channel answers "nothing" for the rest of the session
  /// instead of throwing on every presentation change.
  static Future<void> refresh() async {
    if (!_supported) return;
    if (!PlatformUtils.isAndroid) {
      _supported = false;
      return;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getInsets');
      if (result == null) return;
      final top = _asDouble(result['top']);
      final bottom = _asDouble(result['bottom']);
      final left = _asDouble(result['left']);
      final right = _asDouble(result['right']);
      final ratio = WidgetsBinding.instance.platformDispatcher.views.isEmpty
          ? 1.0
          : WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final logical = EdgeInsets.fromLTRB(
        left / ratio,
        top / ratio,
        right / ratio,
        bottom / ratio,
      );
      if (insets.value != logical) insets.value = logical;
    } on MissingPluginException {
      _supported = false;
    } on PlatformException {
      // A vendor build that refuses the query keeps MediaQuery as the only
      // source, which is the pre-existing behavior.
    }
  }

  static double _asDouble(Object? value) => value is num ? value.toDouble() : 0;

  /// The top inset [context] must clear, cutout included.
  ///
  /// The larger of the two wins: `MediaQuery.padding` already accounts for the
  /// status bar in windowed modes, while the cutout reading is the only number
  /// that survives immersive mode.
  static double topInsetOf(BuildContext context) {
    final media = MediaQuery.of(context);
    final system = media.padding.top > media.viewPadding.top ? media.padding.top : media.viewPadding.top;
    return system > insets.value.top ? system : insets.value.top;
  }

  /// The bottom inset [context] must clear, cutout included.
  static double bottomInsetOf(BuildContext context) {
    final media = MediaQuery.of(context);
    final system = media.padding.bottom > media.viewPadding.bottom ? media.padding.bottom : media.viewPadding.bottom;
    return system > insets.value.bottom ? system : insets.value.bottom;
  }
}
