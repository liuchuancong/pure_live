import 'package:meta/meta.dart';

/// One stream line of one quality, self-describing: URL, headers, codec,
/// and the lease that says when the URL dies.
///
/// `lease` replaces the scattered refresh/expiry resolvers of earlier
/// versions — everything a replayer needs to decide "reuse or refetch"
/// travels with the line.
@immutable
final class PlayLease {
  /// A lease; [expiresAt] null means the URL has no known deadline.
  const new({this.refreshAt, this.expiresAt, this.cutsConnection = false});

  /// When the client should proactively refresh the URL.
  final DateTime? refreshAt;

  /// When the URL stops working.
  final DateTime? expiresAt;

  /// Whether using the URL past expiry cuts the current connection.
  final bool cutsConnection;

  /// Whether the lease has a deadline at all.
  bool get isExpiring => expiresAt != null || refreshAt != null;
}

/// The wire format of a line.
enum StreamFormat {
  /// HTTP-FLV.
  flv,

  /// HLS.
  hls,

  /// Anything else the player must sniff.
  other,
}

/// A playable line: identity, transport and lease in one object.
@immutable
final class LivePlayLine {
  /// A line description.
  const new({
    required this.url,
    this.headers = const {},
    this.format = StreamFormat.other,
    this.codec,
    this.lineId,
    this.lease,
    this.width,
    this.height,
  });

  /// Absolute stream URL.
  final String url;

  /// Request headers the player must send.
  final Map<String, String> headers;

  /// Wire format hint for backend selection.
  final StreamFormat format;

  /// Codec hint, when the source declares one (e.g. `avc`, `hevc`).
  final String? codec;

  /// Stable line identifier within one resolution result.
  final String? lineId;

  /// The refresh/expiry lease of [url].
  final PlayLease? lease;

  /// Declared video width, when known.
  final int? width;

  /// Declared video height, when known.
  final int? height;

  @override
  String toString() => 'LivePlayLine(${lineId ?? url}, ${format.name})';
}
