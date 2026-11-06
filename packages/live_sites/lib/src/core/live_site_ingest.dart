import 'dart:typed_data' show Uint8List;

/// What a platform's stream needs before a player can open it.
///
/// The app maps these to `media_core_ingest`'s plan; the site only states the
/// fact, it never runs the relay.
enum LiveSiteIngestNeed {
  /// Manifest children are bare names or paths that must be made absolute.
  relativeChildren,

  /// Child URIs are absolute paths a native resolver may read as files.
  absolutePathChildren,

  /// The signed URL expires while the stream is still playing.
  expiringUrl,

  /// The container or codec is outside the player's own FFmpeg.
  legacyContainer,

  /// The manifest's token must be replayed on every child request.
  childToken,

  /// Cookies issued with the manifest belong to its children.
  sessionCookies,

  /// The child bodies themselves are obfuscated (Bigo's per-segment XOR).
  segmentTransform,
}

/// A platform's recipe for the ingest relay: what the player needs, and the
/// pure functions the relay applies while it is between CDN and player.
///
/// The site owns the platform knowledge (Bigo's seed and XOR live in
/// `BigoHlsProtection`); the playback package only executes the two hooks.
final class LiveSiteIngestRecipe {
  /// Creates a recipe.
  const new({required this.needs, this.seedOf, this.transform});

  /// What the stream needs before the player can open it.
  final Set<LiveSiteIngestNeed> needs;

  /// The seed a manifest body carries, or null when it is not protected.
  final int? Function(String manifest)? seedOf;

  /// Restores one child body with the manifest's seed.
  final Uint8List Function(Uint8List body, int seed)? transform;
}
