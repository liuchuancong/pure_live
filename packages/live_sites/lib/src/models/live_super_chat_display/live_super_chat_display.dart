// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// How and for how long a paid message is shown: the display window and the
/// card's colors, or the sticker picture when the message is one.
@immutable
final class LiveSuperChatDisplay {
  /// Creates the display settings.
  const LiveSuperChatDisplay({
    required this.startTime,
    required this.endTime,
    this.backgroundColor = '',
    this.backgroundBottomColor = '',
    this.image = '',
  });

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

  @override
  String toString() => 'LiveSuperChatDisplay($startTime..$endTime)';
}
