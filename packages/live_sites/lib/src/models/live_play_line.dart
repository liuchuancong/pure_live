import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_play_line.freezed.dart';
part 'live_play_line.g.dart';

/// One stream line of one quality, self-describing: URL, headers, codec,
/// and the lease that says when the URL dies.
///
/// `lease` replaces the scattered refresh/expiry resolvers of earlier
/// versions — everything a replayer needs to decide "reuse or refetch"
/// travels with the line.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class PlayLease with _$PlayLease {
  /// A lease; [expiresAt] null means the URL has no known deadline.
  const factory PlayLease({DateTime? refreshAt, DateTime? expiresAt, @Default(false) bool cutsConnection}) = _PlayLease;

  /// Restores a lease from JSON.
  factory PlayLease.fromJson(Map<String, Object?> json) => _$PlayLeaseFromJson(json);
}

/// Whether a lease has a deadline at all.
extension PlayLeaseDeadline on PlayLease {
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
@freezed
abstract class LivePlayLine with _$LivePlayLine {
  /// A line description.
  const factory LivePlayLine({
    required String url,
    @Default(<String, String>{}) Map<String, String> headers,
    @Default(StreamFormat.other) StreamFormat format,
    String? codec,
    String? lineId,
    PlayLease? lease,
    int? width,
    int? height,
  }) = _LivePlayLine;

  /// Restores a line from JSON.
  factory LivePlayLine.fromJson(Map<String, Object?> json) => _$LivePlayLineFromJson(json);
}
