import 'dart:async' show unawaited;

import 'package:live_device/live_device.dart' show ScreenOrientationPreference, ScreenOrientationService;

/// Which way the phone turns when a stream goes system-fullscreen: the
/// picture's own shape decides — upright for a portrait source, sideways for
/// the rest. Every page that can take the whole screen (the room, VOD, IPTV,
/// hongguo) asks the same rule. Desktop and web answer inert at the service.
ScreenOrientationPreference fullscreenOrientationFor({required double aspectRatio}) {
  final portraitStream = aspectRatio.isFinite && aspectRatio > 0 && aspectRatio < 1;
  return portraitStream ? ScreenOrientationPreference.portrait : ScreenOrientationPreference.landscape;
}

/// Applies [fullscreenOrientationFor] through [service] without blocking the
/// caller: a refused lock must never keep the player out of fullscreen.
void applyFullscreenOrientation(ScreenOrientationService service, {required double aspectRatio}) {
  unawaited(service.apply(fullscreenOrientationFor(aspectRatio: aspectRatio)));
}
