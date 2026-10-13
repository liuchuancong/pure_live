// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_gift/live_gift_unit.dart';
import 'package:meta/meta.dart';

/// A super chat (paid message).
@immutable
final class LiveSuperChatMessage {
  /// Creates a message.
  const LiveSuperChatMessage({
    required this.userName,
    required this.face,
    required this.message,
    required this.price,
    required this.startTime,
    required this.endTime,
    required this.backgroundColor,
    required this.backgroundBottomColor,
    this.messageId = '',
    this.priceText = '',
    this.unit = LiveGiftUnit.other,
    this.image = '',
  });

  /// The platform's id for the event, when it has one. Some message-board APIs
  /// rebuild [startTime] from a countdown on every poll, so equality by time
  /// would make the same paid message look new.
  final String messageId;

  /// Sender name.
  final String userName;

  /// Sender avatar URL.
  final String face;

  /// Text.
  final String message;

  /// Price in [unit]; for a platform that only writes its price ([priceText] in
  /// the buyer's currency: YouTube) the number read from that text
  /// (`superChatAmount`), which only orders and compares.
  final int price;

  /// The price as the platform shows it (`$5.00`, `1,000 cheese`), when [price]
  /// alone cannot say it; empty otherwise.
  final String priceText;

  /// The unit of [price].
  final LiveGiftUnit unit;

  /// Start of display.
  final DateTime startTime;

  /// End of display.
  final DateTime endTime;

  /// Top background colour.
  final String backgroundColor;

  /// Bottom background colour.
  final String backgroundBottomColor;

  /// The picture the message is, an https URL (YouTube's Super Sticker); empty
  /// for a message of text.
  final String image;

  /// Same [messageId] when either has one; otherwise same sender, text and price.
  @override
  bool operator ==(Object other) {
    if (other is! LiveSuperChatMessage) return false;
    if (messageId.isNotEmpty || other.messageId.isNotEmpty) {
      return messageId.isNotEmpty && other.messageId == messageId;
    }
    return other.userName == userName && other.message == message && other.price == price;
  }

  @override
  int get hashCode => messageId.isNotEmpty ? messageId.hashCode : Object.hash(userName, message, price);
}
