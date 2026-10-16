/// System-volume API support reported for the current runtime platform.
///
/// These flags describe plugin/platform API support, not guaranteed hardware
/// availability. For example, a Linux system may have no usable ALSA mixer.
final class SystemVolumeCapabilities {
  /// Creates an immutable capability description.
  const new({
    required this.canRead,
    required this.canWrite,
    required this.canObserve,
    required this.canMute,
    required this.canControlSystemUi,
    required this.platformName,
  });

  /// Whether the platform API can read the system output volume.
  final bool canRead;

  /// Whether the platform API can set the system output volume.
  final bool canWrite;

  /// Whether volume-change events can be observed.
  final bool canObserve;

  /// Whether mute/unmute operations are available.
  ///
  /// Mute semantics differ by platform; see the service documentation.
  final bool canMute;

  /// Whether the native volume overlay can be shown or hidden through the API.
  /// This option is supported on Android and iOS only.
  final bool canControlSystemUi;

  /// Runtime platform label for diagnostics, not intended for feature branching.
  final String platformName;

  /// Whether the volume slider and basic system-volume controls can be offered.
  bool get canOfferVolumeControl => canRead && canWrite;
}
