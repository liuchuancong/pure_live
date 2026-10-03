import 'package:media_core_ingest/media_core_ingest.dart';

/// Providers whose manifests cannot be handed to the native resolver as they
/// are, keyed by host suffix.
///
/// Observed: TwitCasting's `tc-hls` playlists list their children as bare names
/// (`media.95.mp4`). A resolver that no longer knows the manifest URL looks for
/// them next to itself, so playback dies with
/// `No protocol handler found to open URL \tc.livehls\...\media.95.mp4`. The
/// fix belongs to the ingest layer (media_core_ingest), not to this app.
///
/// Long term this declaration belongs on the site adapter, next to the other
/// per-platform playback facts; until then one table keeps the decision out of
/// the transport branch.
const Map<String, Set<IngestNeed>> _hostIngestNeeds = <String, Set<IngestNeed>>{
  'twitcasting.tv': <IngestNeed>{IngestNeed.relativeChildren},
};

/// Ingest needs declared for [source], by host suffix.
Set<IngestNeed> playbackIngestNeeds(Uri source) {
  final String host = source.host.toLowerCase();
  for (final MapEntry<String, Set<IngestNeed>> entry in _hostIngestNeeds.entries) {
    if (host == entry.key || host.endsWith('.${entry.key}')) return entry.value;
  }
  return const <IngestNeed>{};
}
