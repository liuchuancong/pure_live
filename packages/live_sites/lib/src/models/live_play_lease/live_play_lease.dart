// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// When a signed play URL must be renewed.
@immutable
final class LivePlayLease {
  /// Creates a lease; [refreshAt] must not be after [expiresAt].
  LivePlayLease({required this.refreshAt, this.expiresAt, this.cutsConnection = false})
    : assert(expiresAt == null || !refreshAt.isAfter(expiresAt), 'refreshAt must not be after expiresAt');

  /// When to fetch a fresh URL.
  final DateTime refreshAt;

  /// When the URL stops opening new connections, if known.
  final DateTime? expiresAt;

  /// Whether expiry also ends an established connection (Douyu), so the renewed
  /// stream must be spliced in; otherwise it is only prefetched.
  final bool cutsConnection;
}
