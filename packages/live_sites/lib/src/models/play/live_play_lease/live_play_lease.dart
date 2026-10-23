// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';

part 'live_play_lease.g.dart';

/// The lifetime of a short-lived signed play URL.
///
/// [refreshAt] is when a player should re-resolve; [expiresAt] is when the
/// old URL is certain to fail. A prefetched URL stays usable between the two,
/// while an expired cache entry must be discarded.
abstract class LivePlayLease implements Built<LivePlayLease, LivePlayLeaseBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LivePlayLease([void Function(LivePlayLeaseBuilder)? updates]) = _$LivePlayLease;

  /// Creates a LivePlayLease with already-normalized fields.
  factory LivePlayLease.of({required DateTime refreshAt, DateTime? expiresAt, bool requiresReconnect = false}) =>
      LivePlayLease(
        (b) => b
          ..refreshAt = refreshAt
          ..expiresAt = expiresAt
          ..requiresReconnect = requiresReconnect,
      );

  LivePlayLease._();

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LivePlayLeaseBuilder b) => b..requiresReconnect = false;

  /// When a player should re-resolve the URL.
  DateTime get refreshAt;

  /// When the URL is certain to fail.
  DateTime? get expiresAt;

  /// The connection must be rebuilt, not resumed, at [refreshAt].
  bool get requiresReconnect;
}
