import 'package:media_core/media_core.dart' show PlayerSource;

/// The volume an engine open must start at.
///
/// libmpv starts every freshly created engine at 100%, and the room's saved
/// level used to land only after `open()` had already produced audio — one
/// loud frame leaked through before the saved (or muted) level applied, even
/// for rooms saved at zero. The two hosts that open sources declare the level
/// here, and the kernel's `beforeOpen` hook applies it to libmpv before the
/// first `loadfile`.
abstract final class OpenVolume {
  /// [PlayerSource.metadata] key carrying this open's initial volume
  /// (0.0–1.0). Per-source, so each multiview cell opens at its own level.
  static const String metadataKey = 'pure_live.open-volume';

  /// The level for the next open that carries no metadata declaration — the
  /// live-room facade path, where the level belongs to the room being opened.
  static double? pending;

  /// The level [source] must start at, falling back to [pending] when the
  /// source declares none. [pending] is read, not consumed: a line sweep
  /// re-runs `beforeOpen` for every fallback source and each attempt must
  /// start at the declared level; the next declaring play overwrites it.
  static double? resolve(PlayerSource source) {
    final declared = source.metadata[metadataKey];
    if (declared is num) {
      return declared.clamp(0.0, 1.0).toDouble();
    }
    return pending;
  }
}
