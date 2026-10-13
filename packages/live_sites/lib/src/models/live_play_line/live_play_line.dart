// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_play_geometry/live_play_geometry.dart';
import 'package:live_sites/src/models/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/models/live_stream_format/live_stream_format.dart';
import 'package:meta/meta.dart';

/// One playable line and everything needed to open it.
///
/// Request headers and lease times live with the URL here (rather than in a
/// per-platform resolver above), so the player and the recorder need no
/// per-platform code: a line describes itself.
@immutable
final class LivePlayLine {
  /// Creates a line; header names are lower case.
  const LivePlayLine(
    this.url, {
    this.headers = const {},
    this.format,
    this.codec,
    this.lineId,
    this.lease,
    this.geometry = const LivePlayGeometry(),
  });

  /// Media URL.
  final String url;

  /// Request headers the CDN needs.
  final Map<String, String> headers;

  /// Container format, when known.
  final LiveStreamFormat? format;

  /// Video codec when known (`avc`, `hevc`).
  final String? codec;

  /// Line identity stable across renewals (a CDN code), when known.
  final String? lineId;

  /// Renewal rule; null when the URL does not expire while playing.
  final LivePlayLease? lease;

  /// The declared picture geometry (width, height, aspect ratio).
  final LivePlayGeometry geometry;

  /// Picture width the platform declares for this line (delegates to [geometry]).
  int? get width => geometry.width;

  /// Picture height the platform declares for this line (delegates to [geometry]).
  int? get height => geometry.height;

  /// [width] over [height], when both are declared (delegates to [geometry]).
  double? get declaredAspectRatio => geometry.declaredAspectRatio;

  @override
  String toString() => 'LivePlayLine(${lineId ?? url})';
}
