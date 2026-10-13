// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_gift_unit/live_gift_unit.dart';
import 'package:live_sites/src/models/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/live_super_chat_price/live_super_chat_price.dart';
import 'package:meta/meta.dart';

/// A super chat (paid message).
///
/// The sender (name, avatar) and text live here; the cost is a
/// [LiveSuperChatPrice] and the display window and card colors are a
/// [LiveSuperChatDisplay], reached through the delegating getters below.
@immutable
final class LiveSuperChatMessage {
  /// Creates a message.
  LiveSuperChatMessage({
    required this.userName,
    required this.face,
    required this.message,
    required int price,
    required DateTime startTime,
    required DateTime endTime,
    String backgroundColor = '',
    String backgroundBottomColor = '',
    this.messageId = '',
    String priceText = '',
    LiveGiftUnit unit = LiveGiftUnit.other,
    String image = '',
  }) : priceInfo = LiveSuperChatPrice(price: price, priceText: priceText, unit: unit),
       display = LiveSuperChatDisplay(
         startTime: startTime,
         endTime: endTime,
         backgroundColor: backgroundColor,
         backgroundBottomColor: backgroundBottomColor,
         image: image,
       );

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

  /// The price (amount, text, unit).
  final LiveSuperChatPrice priceInfo;

  /// The display window and card colors.
  final LiveSuperChatDisplay display;

  /// Price in [unit] (delegates to [priceInfo]).
  int get price => priceInfo.price;

  /// The platform's own price text (delegates to [priceInfo]).
  String get priceText => priceInfo.priceText;

  /// The currency of [price] (delegates to [priceInfo]).
  LiveGiftUnit get unit => priceInfo.unit;

  /// Start of display (delegates to [display]).
  DateTime get startTime => display.startTime;

  /// End of display (delegates to [display]).
  DateTime get endTime => display.endTime;

  /// Top background colour (delegates to [display]).
  String get backgroundColor => display.backgroundColor;

  /// Bottom background colour (delegates to [display]).
  String get backgroundBottomColor => display.backgroundBottomColor;

  /// The sticker picture URL (delegates to [display]).
  String get image => display.image;

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
