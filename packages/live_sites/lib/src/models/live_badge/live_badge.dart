// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// A picture a platform shows next to a sender's name (17LIVE's prefix, role,
/// attendance and level badges): what the chat line draws, in the platform's
/// order.
@immutable
final class LiveBadge {
  /// Creates a badge.
  const LiveBadge({required this.url, this.id = ''});

  /// The picture's address (https).
  final String url;

  /// The platform's id for the badge (17LIVE's `styleID`), empty when it has
  /// none.
  final String id;

  @override
  bool operator ==(Object other) => other is LiveBadge && other.url == url && other.id == id;

  @override
  int get hashCode => Object.hash(url, id);

  @override
  String toString() => 'LiveBadge($url${id.isEmpty ? '' : ', $id'})';
}
