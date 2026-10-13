import 'package:media_core/presentation/device_profile.dart';

/// What the viewer allows and what device the system is on.
///
/// Every field here is the *host's* answer, not a value this package can
/// detect: the app knows whether the viewer enabled background playback, which
/// screen it is drawing on, and what volume a new room should start at. The
/// service only reads the config and obeys it, which is what keeps the same
/// code running on a phone, a tablet and a desktop with no branching.
final class PlaybackConfig {
  /// Creates a config.
  const new({
    this.deviceProfile = DeviceProfile.mobile,
    this.allowBackgroundPlayback = true,
    this.allowPictureInPicture = true,
    this.allowFloatingWindow = true,
    this.defaultVolume = 1.0,
    this.defaultPlaybackRate = 1.0,
  });

  /// The device profile the layout strategy is computed from.
  final DeviceProfile deviceProfile;

  /// Whether sound may continue while the app is not visible.
  ///
  /// When false, backgrounding pauses playback instead of playing to nobody.
  final bool allowBackgroundPlayback;

  /// Whether the picture may move into a system PiP window.
  ///
  /// The platform must also support it — the presentation manager reports
  /// that — so this stays the viewer's permission, not the capability.
  final bool allowPictureInPicture;

  /// Whether the picture may move into the in-app floating window.
  final bool allowFloatingWindow;

  /// The volume a new session opens at, `0.0`–`1.0`.
  final double defaultVolume;

  /// The playback rate a new session opens at.
  final double defaultPlaybackRate;

  /// The defaults: phone, everything allowed, full volume.
  static const PlaybackConfig defaults = PlaybackConfig();

  /// A copy with fields replaced.
  PlaybackConfig copyWith({
    DeviceProfile? deviceProfile,
    bool? allowBackgroundPlayback,
    bool? allowPictureInPicture,
    bool? allowFloatingWindow,
    double? defaultVolume,
    double? defaultPlaybackRate,
  }) {
    return PlaybackConfig(
      deviceProfile: deviceProfile ?? this.deviceProfile,
      allowBackgroundPlayback: allowBackgroundPlayback ?? this.allowBackgroundPlayback,
      allowPictureInPicture: allowPictureInPicture ?? this.allowPictureInPicture,
      allowFloatingWindow: allowFloatingWindow ?? this.allowFloatingWindow,
      defaultVolume: defaultVolume ?? this.defaultVolume,
      defaultPlaybackRate: defaultPlaybackRate ?? this.defaultPlaybackRate,
    );
  }
}
