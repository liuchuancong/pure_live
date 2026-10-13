// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// What a retraction takes back: one message, one sender's messages, or the
/// whole chat.
@immutable
final class LiveRetraction {
  /// The message whose `LiveMessage.messageId` is [messageId].
  const LiveRetraction.message(String this.messageId) : userId = null;

  /// Every message of the sender whose `LiveMessage.userId` is [userId].
  const LiveRetraction.user(String this.userId) : messageId = null;

  /// Every message shown so far.
  const LiveRetraction.all() : messageId = null, userId = null;

  /// The message taken back, for [LiveRetraction.message].
  final String? messageId;

  /// The sender whose messages are taken back, for [LiveRetraction.user].
  final String? userId;

  /// Whether the whole chat is taken back.
  bool get isAll => messageId == null && userId == null;

  @override
  bool operator ==(Object other) => other is LiveRetraction && other.messageId == messageId && other.userId == userId;

  @override
  int get hashCode => Object.hash(messageId, userId);

  @override
  String toString() => messageId != null
      ? 'LiveRetraction.message($messageId)'
      : userId != null
      ? 'LiveRetraction.user($userId)'
      : 'LiveRetraction.all()';
}
