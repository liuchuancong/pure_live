// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_badge/live_badge.dart';
import 'package:live_sites/src/models/live_message_color/live_message_color.dart';
import 'package:meta/meta.dart';

/// Who sent a danmaku message: their identity, level and the badges the platform
/// shows next to their name. Grouped apart from the message body so the chat can
/// act on the sender (blocking, name style, member color) as one unit.
@immutable
final class LiveMessageSender {
  /// Creates a sender.
  const LiveMessageSender({
    this.userId = '',
    this.userName = '',
    this.userLevel = '',
    this.fansLevel = '',
    this.fansName = '',
    this.nameColor,
    this.badges = const [],
  });

  /// Sender id.
  final String userId;

  /// Sender name.
  final String userName;

  /// Sender level.
  final String userLevel;

  /// Fan badge level.
  final String fansLevel;

  /// Fan badge name.
  final String fansName;

  /// The colour the platform gives the sender's name (17LIVE's `name.textColor`);
  /// null for the chat's default.
  final LiveMessageColor? nameColor;

  /// The badges the platform shows next to the sender's name, in its order; empty
  /// when it shows none.
  final List<LiveBadge> badges;

  @override
  String toString() => 'LiveMessageSender($userName)';
}
