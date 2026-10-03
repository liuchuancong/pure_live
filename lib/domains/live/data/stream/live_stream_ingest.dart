/// Turns a site's per-line declaration into the ingest decision.
///
/// The rule is the one the transport already follows, only fed by facts instead
/// of by a per-platform branch: a container the player's own FFmpeg cannot parse
/// (codec-id-12 HEVC inside FLV) is remuxed by a local FFmpeg into a loopback
/// HLS tree, a playlist with bare-name children is rewritten over loopback, and
/// everything else is handed to the player untouched - relaying costs a process,
/// a port and one to three seconds of start-up.
library;

import 'package:media_core_ingest/media_core_ingest.dart';
import 'package:pure_live/shared/platforms/live_site.dart';

/// Ingest needs implied by [facts]; empty when nothing was declared or the line
/// is ordinary.
Set<IngestNeed> ingestNeedsFor(LiveStreamFacts? facts) {
  if (facts == null) return const <IngestNeed>{};
  final needs = <IngestNeed>{};
  final codec = (facts.codec ?? '').toLowerCase();
  if (facts.format == LiveStreamFormat.flv && codec == 'hevc') {
    needs.add(IngestNeed.legacyContainer);
  }
  if (facts.unresolvedChildren) needs.add(IngestNeed.relativeChildren);
  return Set<IngestNeed>.unmodifiable(needs);
}

/// Whether this line must be remuxed by FFmpeg before the player can read it.
bool requiresFfmpegRemux(LiveStreamFacts? facts) =>
    resolveIngestPlan(needs: ingestNeedsFor(facts)).strategy == IngestStrategy.ffmpegRelay;

/// Whether this line must be served as a rewritten manifest over loopback.
bool requiresManifestRelay(LiveStreamFacts? facts) {
  if (facts == null) return false;
  final sourceIsManifest = facts.format == LiveStreamFormat.hls;
  return resolveIngestPlan(needs: ingestNeedsFor(facts), sourceIsManifest: sourceIsManifest).strategy ==
      IngestStrategy.manifestRelay;
}

/// Whether the line can be treated as a manifest by the native resolver.
///
/// An undeclared line falls back to the URL shape; a declared `other` line (IPTV
/// MPEG-TS, udpxy, a suffix-less FLV/MP4) is never one, so the manifest probe is
/// skipped instead of reading a media body as a playlist.
bool isDeclaredManifest(LiveStreamFacts? facts, Uri uri) =>
    facts == null ? isHlsManifestUri(uri) : facts.format == LiveStreamFormat.hls;
