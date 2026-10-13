import 'package:flutter/foundation.dart';

import 'package:live_playback/src/config/playback_config.dart';
import 'package:media_core/media_core.dart';

/// The viewer's playback settings, readable and replaceable while playing.
///
/// [PlaybackConfig] is a value — what the settings *are* — and this is where
/// they live. The distinction matters because settings change while a video is
/// on screen: the viewer turns PiP off in a settings page, and the next
/// backgrounding has to obey the new answer, not the one captured when the
/// service was built.
///
/// A [ValueListenable] rather than a stream so a reader never has to await a
/// delivery to ask "is background playback allowed right now" — the policy
/// checks in the background manager are synchronous decisions on the way out
/// of an event.
final class PlaybackSettings extends ValueNotifier<PlaybackConfig> {
  /// Creates settings over an initial config.
  ///
  /// The super parameter is named `_value` because [ValueNotifier] names its
  /// own positional parameter that way; the call site is `PlaybackSettings(config)`.
  new([super._value = PlaybackConfig.defaults]);

  /// The current settings.
  PlaybackConfig get config => value;

  /// Replaces the settings. Listeners are notified immediately.
  set config(PlaybackConfig next) => value = next;

  /// The device profile the layout strategy is computed from.
  DeviceProfile get deviceProfile => value.deviceProfile;

  /// Whether sound may continue while the app is not visible.
  bool get allowBackgroundPlayback => value.allowBackgroundPlayback;

  /// Whether the picture may move into a system PiP window.
  bool get allowPictureInPicture => value.allowPictureInPicture;

  /// Whether the picture may move into the in-app floating window.
  bool get allowFloatingWindow => value.allowFloatingWindow;

  /// The volume a new session opens at.
  double get defaultVolume => value.defaultVolume;

  /// The playback rate a new session opens at.
  double get defaultPlaybackRate => value.defaultPlaybackRate;

  /// Replaces single fields without writing the whole config out.
  void update({
    DeviceProfile? deviceProfile,
    bool? allowBackgroundPlayback,
    bool? allowPictureInPicture,
    bool? allowFloatingWindow,
    double? defaultVolume,
    double? defaultPlaybackRate,
  }) {
    value = value.copyWith(
      deviceProfile: deviceProfile,
      allowBackgroundPlayback: allowBackgroundPlayback,
      allowPictureInPicture: allowPictureInPicture,
      allowFloatingWindow: allowFloatingWindow,
      defaultVolume: defaultVolume,
      defaultPlaybackRate: defaultPlaybackRate,
    );
  }
}
