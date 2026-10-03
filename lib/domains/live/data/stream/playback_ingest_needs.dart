import 'package:media_core_ingest/media_core_ingest.dart';

/// Fallback ingest needs for hosts that declare nothing, keyed by host suffix.
///
/// The declaration belongs to the site adapter (`LivePlayStreamFacts`, carried on
/// `LivePlayUrlResolution.streamFacts`); this table is only consulted for a line
/// whose platform said nothing *and* whose manifest could not be read, so an
/// unmigrated site keeps the behaviour it had before the declaration existed.
///
/// Observed: TwitCasting's `tc-hls` playlists list their children as bare names
/// (`media.95.mp4`). A resolver that no longer knows the manifest URL looks for
/// them next to itself, so playback dies with
/// `No protocol handler found to open URL \tc.livehls\...\media.95.mp4`.
const Map<String, Set<IngestNeed>> _hostIngestNeeds = <String, Set<IngestNeed>>{
  'twitcasting.tv': <IngestNeed>{IngestNeed.relativeChildren},
};

/// Ingest needs declared for [source] by host suffix, when nothing better is known.
Set<IngestNeed> playbackIngestNeeds(Uri source) {
  final String host = source.host.toLowerCase();
  for (final MapEntry<String, Set<IngestNeed>> entry in _hostIngestNeeds.entries) {
    if (host == entry.key || host.endsWith('.${entry.key}')) return entry.value;
  }
  return const <IngestNeed>{};
}
