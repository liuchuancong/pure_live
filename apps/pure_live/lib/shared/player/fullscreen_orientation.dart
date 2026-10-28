import 'dart:async' show unawaited;

import 'package:live_device/live_device.dart' show ScreenOrientationPreference, ScreenOrientationService;
import 'package:pure_live/features/settings/settings.dart' show PortraitFullscreenPolicy;

/// Which way the phone turns when a stream goes system-fullscreen.
///
/// This is the room page's long-standing rule — the viewer's portrait-live
/// policy applied to the picture's own shape — shared by every page that can
/// take the whole screen (the room, VOD, IPTV), so one setting decides for
/// all of them. Desktop and web answer inert at the service.
ScreenOrientationPreference fullscreenOrientationFor({
  required PortraitFullscreenPolicy policy,
  required double aspectRatio,
}) {
  final portraitStream = aspectRatio.isFinite && aspectRatio > 0 && aspectRatio < 1;
  return switch (policy) {
    PortraitFullscreenPolicy.followSystem => ScreenOrientationPreference.followSystem,
    PortraitFullscreenPolicy.landscape => ScreenOrientationPreference.landscape,
    PortraitFullscreenPolicy.followSource =>
      portraitStream ? ScreenOrientationPreference.portrait : ScreenOrientationPreference.landscape,
  };
}

/// Applies [fullscreenOrientationFor] through [service] without blocking the
/// caller: a refused lock must never keep the player out of fullscreen.
void applyFullscreenOrientation(
  ScreenOrientationService service, {
  required PortraitFullscreenPolicy policy,
  required double aspectRatio,
}) {
  unawaited(service.apply(fullscreenOrientationFor(policy: policy, aspectRatio: aspectRatio)));
}
