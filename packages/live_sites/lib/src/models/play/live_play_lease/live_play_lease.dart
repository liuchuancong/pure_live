import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_play_lease.freezed.dart';

/// The lifetime of a short-lived signed play URL.
///
/// [refreshAt] is when a player should re-resolve; [expiresAt] is when the
/// old URL is certain to fail. A prefetched URL stays usable between the two,
/// while an expired cache entry must be discarded.
@freezed
abstract class LivePlayLease with _$LivePlayLease {
  /// Creates a LivePlayLease with already-normalized fields.
  const factory LivePlayLease({
    required DateTime refreshAt,
    DateTime? expiresAt,
    @Default(false) bool requiresReconnect,
  }) = _LivePlayLease;
}
