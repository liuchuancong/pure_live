import 'package:flutter/foundation.dart' show immutable;
import 'package:media_core_danmaku/media_core_danmaku.dart'
    show DanmakuColor, DanmakuMessage, DanmakuMessageType, DanmakuPlacement;

/// One danmaku line as a danmaku file carries it: where it sits on the media's
/// timeline, what it says, and the few presentation facts the file formats
/// keep.
///
/// This is the one shape the app's danmaku files agree on — a live recording,
/// a downloaded video's sidecar and a fetched Bilibili XML all become this
/// before a format writer sees them. The live renderer's [DanmakuMessage]
/// is a different thing: it carries a wall clock and a session, not a media
/// offset, so the conversion is explicit in both directions.
@immutable
final class DanmakuEntry {
  /// One line at [time] (from the media's start).
  const DanmakuEntry({
    required this.time,
    required this.text,
    this.color = DanmakuColor.white,
    this.placement = DanmakuPlacement.scroll,
    this.fontSize = 25,
    this.user = '',
    this.id = '',
  });

  /// A line from a renderer message anchored at [time].
  factory DanmakuEntry.fromMessage(DanmakuMessage message, {required Duration time}) => DanmakuEntry(
    time: time,
    text: message.text,
    color: message.color,
    placement: message.style?.placement ?? DanmakuPlacement.scroll,
    fontSize: message.style?.fontSize.round() ?? 25,
    user: message.userName,
    id: message.messageId,
  );

  /// The line's offset from the media's start.
  final Duration time;

  /// What it says.
  final String text;

  /// The text color the platform sent.
  final DanmakuColor color;

  /// Whether it scrolls, or is pinned to the top or bottom.
  final DanmakuPlacement placement;

  /// The platform's own text size (`25` on Bilibili is the default row).
  final int fontSize;

  /// The sender's display name, when the source names one.
  final String user;

  /// The platform's message id, empty when it has none.
  final String id;

  /// The offset in seconds, the unit every file format stores.
  double get seconds => time.inMilliseconds / 1000;

  /// Whether the line has anything to show.
  bool get isEmpty => text.trim().isEmpty;

  /// The renderer's shape for this line, its id kept when the source had one.
  DanmakuMessage toMessage() =>
      DanmakuMessage(type: DanmakuMessageType.chat, userName: user, text: text, color: color, messageId: id);

  /// A copy with the named field replaced.
  DanmakuEntry copyWith({
    Duration? time,
    String? text,
    DanmakuColor? color,
    DanmakuPlacement? placement,
    int? fontSize,
  }) => DanmakuEntry(
    time: time ?? this.time,
    text: text ?? this.text,
    color: color ?? this.color,
    placement: placement ?? this.placement,
    fontSize: fontSize ?? this.fontSize,
    user: user,
    id: id,
  );

  @override
  String toString() => 'DanmakuEntry(${seconds.toStringAsFixed(2)}s: $text)';
}
