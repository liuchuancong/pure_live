import 'package:hls/hls.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';

// Re-export the HLS types that play parsers reference directly.
export 'package:hls/hls.dart' show HlsMasterPlaylist, HlsMediaType, HlsRendition, HlsVariant;

/// The parsed result of an HLS master playlist: the master playlist itself and
/// the source URL it was fetched from (variant URIs are resolved against it).
///
/// `null` when the body is not a valid master playlist.
typedef HlsMasterParseResult = ({Uri source, HlsMasterPlaylist master})?;

/// Defensively parses [body] as an HLS master playlist.
///
/// Returns the parsed [HlsMasterPlaylist] together with [masterUrl], or `null`
/// when the body is not a valid playlist or is a media playlist rather than a
/// master. Callers gate on the `#EXTM3U` header before invoking this.
HlsMasterParseResult parseHlsMaster(String body, {required Uri masterUrl}) {
  if (!body.trimLeft().startsWith('#EXTM3U')) return null;
  try {
    final parsed = HlsParser.parse(body);
    if (parsed is HlsMasterPlaylist) return (source: masterUrl, master: parsed);
  } on Object {
    // Not a valid playlist at all.
  }
  return null;
}

/// Resolves a variant [uri] against the [master] URL.
///
/// An absolute URI is returned as-is (so an absolute variant keeps its own
/// path token and a relative one never inherits the master's query).
Uri resolveHlsVariantUri(Uri uri, {required Uri master}) => uri.hasScheme ? uri : master.resolveUri(uri);

/// The video codec an HLS `CODECS` attribute names: [LiveStreamCodec.avc]
/// (`avc1`, `avc3`), [LiveStreamCodec.hevc] (`hvc1`, `hev1`),
/// [LiveStreamCodec.av1] (`av01`), [LiveStreamCodec.vp9] (`vp09`, `vp9`);
/// null when none match.
LiveStreamCodec? hlsVideoCodecOf(String? codecs) {
  for (final entry in (codecs ?? '').toLowerCase().split(',')) {
    switch (entry.trim().split('.').first) {
      case 'avc1' || 'avc3':
        return LiveStreamCodec.avc;
      case 'hvc1' || 'hev1':
        return LiveStreamCodec.hevc;
      case 'av01':
        return LiveStreamCodec.av1;
      case 'vp09' || 'vp9':
        return LiveStreamCodec.vp9;
    }
  }
  return null;
}
