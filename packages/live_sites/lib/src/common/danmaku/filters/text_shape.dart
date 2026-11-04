import 'package:live_sites/src/models/message/live_message/live_message.dart';

/// What a chat message says, for "屏蔽只有表情的弹幕" and "屏蔽超长弹幕"
/// (D02.2 c3): its `length` in characters (code points), each emoticon
/// counting as one, and whether it is nothing but emoticons (`emoteOnly`:
/// emoticon pictures or Unicode emoji, with spaces at most).
typedef DanmakuTextShape = ({int length, bool emoteOnly});

/// Reads the [DanmakuTextShape] of a message; the app's reads the
/// platform's bundled emoticon lists too.
typedef DanmakuTextShaper = DanmakuTextShape Function(LiveMessage message);

/// The shape of a message whose emoticon codes are taken out: [text] is the
/// rest, [emotes] how many were taken out.
DanmakuTextShape danmakuTextShape(String text, {int emotes = 0}) {
  final rest = text.trim();
  final pictographs = rest.isNotEmpty && _emojiOnly.hasMatch(rest);
  return (
    length: emotes + rest.runes.length,
    emoteOnly: rest.isEmpty ? emotes > 0 : pictographs && _pictograph.hasMatch(rest),
  );
}

/// The shape of [message] by the codes it names itself
/// ([LiveMessage.emotes]: CHZZK, YouTube, Bilibili, Kuaishou) and Unicode
/// emoji.
///
/// [emoticonPattern] is how a host adds the platform's bundled list — the
/// codes a site draws from its own sheet without naming them per message
/// (`[笑哭]` on Douyu and Huya). Without it those lines read as the brackets
/// and letters they are typed as, so "屏蔽只有表情的弹幕" — and the length
/// limit beside it — judge a screenful of pictures as ordinary text. The
/// pattern is expected to match one emoticon per match, longest alternative
/// first, which is what a host's drawing catalogue already is.
DanmakuTextShape danmakuMessageShape(LiveMessage message, {RegExp? emoticonPattern}) {
  var text = message.text;
  var emotes = 0;
  if (emoticonPattern case final pattern?) {
    emotes += pattern.allMatches(text).length;
    text = text.replaceAll(pattern, '');
  }
  final codes = {
    for (final emote in message.emotes)
      if (emote.code.isNotEmpty) emote.code,
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final code in codes) {
    final parts = text.split(code);
    emotes += parts.length - 1;
    text = parts.join();
  }
  return danmakuTextShape(text, emotes: emotes);
}

/// Emoji and what joins or changes them (skin tones, flags, keycaps, tags),
/// and spaces.
final RegExp _emojiOnly = RegExp(
  // The analyzer's regex validator does not know the Extended_Pictographic
  // emoji property (UTS #51); Dart's own engine compiles and runs it.
  // ignore: valid_regexps
  r'^[\p{Extended_Pictographic}\u{1F3FB}-\u{1F3FF}\u{1F1E6}-\u{1F1FF}\u{E0020}-\u{E007F}\u200d\ufe0f\u20e3\s]+$',
  unicode: true,
);

/// At least one picture among them (not only joiners and spaces).
final RegExp _pictograph = RegExp(
  // As above: the property is valid for the engine, not for the lint.
  // ignore: valid_regexps
  r'[\p{Extended_Pictographic}\u{1F1E6}-\u{1F1FF}]',
  unicode: true,
);
