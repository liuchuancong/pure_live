import 'package:live_device/src/audio/volume/system_volume_capabilities.dart';
import 'package:live_device/src/audio/volume/system_volume_exception.dart';

/// Controls and observes the operating-system output volume.
///
/// Values exposed by this contract use integer percentages in the range 0–100.
/// This is the device/system volume, not the media player's own gain. Playback
/// volume should continue to use the playback engine when only the stream's
/// audio level needs to change.
///
/// Control targets the system default render endpoint only; there is no way to
/// name another output. Windows resolves `GetDefaultAudioEndpoint(eRender,
/// eMultimedia)` with no endpoint enumeration, macOS resolves
/// `kAudioHardwarePropertyDefaultOutputDevice`, and Linux opens the ALSA card
/// literally named `default`. Switching the OS default device changes what this
/// service reads and writes; a non-default device is not addressable here.
///
/// The percentage is also a single folded value. On macOS, when a device exposes
/// no master volume the plugin averages the channel volumes for a read and
/// writes one value to every channel for a set, so per-channel balance is not
/// representable through this contract.
abstract interface class SystemVolumeService {
  /// Reads the current system volume as a percentage from 0 to 100.
  Future<int> getVolume();

  /// Sets the system volume and returns the value requested by the caller.
  ///
  /// [percentage] must be within 0–100. Hardware and OS volume steps may mean
  /// that the effective value is rounded by the platform.
  Future<int> setVolume(int percentage);

  /// Reads the platform's mute state.
  ///
  /// On iOS and some older Android versions, mute is implemented by setting
  /// volume to zero and restoring a previously saved volume when unmuted.
  Future<bool> isMuted();

  /// Mutes or unmutes system output.
  Future<void> setMuted({required bool muted});

  /// Emits system-volume changes, including the initial value when listening.
  ///
  /// Cancel the subscription when the consumer no longer needs updates. Each
  /// stream owns and cancels its own native listener.
  Stream<int> watchVolume();

  /// Returns support declared for the current runtime platform.
  ///
  /// A platform may support the API while still failing at runtime when no
  /// audio endpoint or mixer is available. Such failures are surfaced as
  /// [SystemVolumeException].
  Future<SystemVolumeCapabilities> getCapabilities();

  /// Configures whether Android/iOS show the system volume overlay when this
  /// service changes volume. Returns false on platforms where this option does
  /// not exist; no setting is changed in that case.
  bool setSystemUiVisible({required bool visible});
}
