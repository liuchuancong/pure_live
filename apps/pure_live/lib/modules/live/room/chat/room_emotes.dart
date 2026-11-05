import 'package:live_sites/live_sites.dart';

/// One piece a chat line splits into: its words, or the picture a platform
/// named for a code inside them.
typedef ChatEmotePiece = ({String text, String? emoteUrl});

/// Cuts [words] at every occurrence of a code [emotes] names, in order, so a
/// platform's own emoticon lands exactly where its code was written.
///
/// The bundled atlas is the first source every line is read through; this is
/// the fallback for the emoticons it does not carry, which four platforms hand
/// in their message (`bilibili`'s whole-line sticker and its inline `[dog]`
/// codes, `chzzk`'s `{:이모티콘:}`, `kuaishou`'s `[…]`, `youtube`'s
/// custom-emoji shortcuts). A code
/// the message does not actually contain is ignored, and where two of a site's
/// codes begin at the same letter the longer one wins, because that is what the
/// line actually wrote.
List<ChatEmotePiece> splitPlatformEmotes(String words, Iterable<LiveEmote> emotes) {
  if (words.isEmpty || emotes.isEmpty) return [if (words.isNotEmpty) (text: words, emoteUrl: null)];
  final codes = <String, String>{};
  for (final emote in emotes) {
    final code = emote.code.trim();
    if (code.isEmpty || emote.url.trim().isEmpty) continue;
    if (!words.contains(code)) continue;
    codes.putIfAbsent(code, () => emote.url.trim());
  }
  if (codes.isEmpty) return [if (words.isNotEmpty) (text: words, emoteUrl: null)];
  final ordered = codes.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  final pieces = <ChatEmotePiece>[];
  final plain = StringBuffer();
  var at = 0;
  while (at < words.length) {
    String? found;
    for (final code in ordered) {
      if (words.startsWith(code, at)) {
        found = code;
        break;
      }
    }
    if (found == null) {
      plain.writeCharCode(words.codeUnitAt(at));
      at += 1;
      continue;
    }
    if (plain.isNotEmpty) {
      pieces.add((text: plain.toString(), emoteUrl: null));
      plain.clear();
    }
    pieces.add((text: found, emoteUrl: codes[found]));
    at += found.length;
  }
  if (plain.isNotEmpty) pieces.add((text: plain.toString(), emoteUrl: null));
  return List<ChatEmotePiece>.unmodifiable(pieces);
}
