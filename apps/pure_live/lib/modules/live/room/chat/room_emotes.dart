import 'dart:ui' as ui;

import 'package:flame_barrage/flame_barrage.dart' show EmojiAtlas;
import 'package:flutter/widgets.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show cachedImage;

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

/// A line's words with the platform's emoticons drawn as themselves: the
/// flying layer's own catalogue (its keys are the emoticons' message texts,
/// "[抠鼻]") regex-cut out of the words and painted from the bundled atlas.
/// A catalogue that hasn't loaded — or a word it doesn't know — stays text,
/// exactly as written. Shared by the chat column and the over-picture stream
/// so one line reads the same in both.
List<InlineSpan> chatWordSpans(
  String words,
  TextStyle style,
  double emojiSize, {
  Iterable<LiveEmote> emotes = const [],
}) {
  final atlas = EmojiAtlas.instance;
  final regex = atlas.regex;
  if (regex == null || !regex.hasMatch(words)) return _plainSpans(words, style, emojiSize, emotes);
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in regex.allMatches(words)) {
    final key = match[0]!;
    final info = atlas.find(key);
    final image = info == null ? null : atlas.image(info.id);
    final src = image == null ? null : atlas.getSrcRect(key);
    // A match without a picture is left in the running text: the next
    // flush writes it out as written - and the platform's own emoticon table
    // gets its chance on it there.
    if (image == null || src == null) continue;
    if (match.start > last) spans.addAll(_plainSpans(words.substring(last, match.start), style, emojiSize, emotes));
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AtlasEmoji(image: image, src: src, size: emojiSize),
      ),
    );
    last = match.end;
  }
  if (last < words.length) spans.addAll(_plainSpans(words.substring(last), style, emojiSize, emotes));
  return spans;
}

/// The words the atlas did not draw, with the platform's own emoticons in
/// place: four platforms hand their pictures over inside the message (Bilibili
/// a whole-line sticker or an inline `[dog]`, ChZZK a `{:이모티콘:}`, Kuaishou a
/// `[…]`, YouTube a custom-emoji shortcut), and the bundled sheet cannot cover
/// what a site adds on its own. Without a picture for the code the words stay
/// exactly as written.
List<InlineSpan> _plainSpans(String run, TextStyle style, double emojiSize, Iterable<LiveEmote> emotes) {
  if (run.isEmpty) return const [];
  if (emotes.isEmpty) return [TextSpan(text: run, style: style)];
  final pieces = splitPlatformEmotes(run, emotes);
  if (pieces.length == 1 && pieces.single.emoteUrl == null) return [TextSpan(text: run, style: style)];
  return [
    for (final piece in pieces)
      if (piece.emoteUrl case final String url)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _PlatformEmote(code: piece.text, url: url, size: emojiSize, style: style),
        )
      else
        TextSpan(text: piece.text, style: style),
  ];
}

/// One emoticon the platform supplied: its own picture at the chat line's
/// size, and its code as written when the picture cannot be had - the line
/// then reads exactly as it did before the platform's table was ever read.
final class _PlatformEmote extends StatelessWidget {
  const _PlatformEmote({required this.code, required this.url, required this.size, required this.style});

  final String code;
  final String url;
  final double size;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Image(
      image: cachedImage(url, policy: ImageCachePolicies.chatEmote, height: size.round()),
      height: size,
      errorBuilder: (context, error, stackTrace) => Text(code, style: style),
    ),
  );
}

/// One emoticon of the bundled atlas: a rect of the sheet the flying layer
/// already decoded, painted at the chat line's own size.
final class _AtlasEmoji extends StatelessWidget {
  const _AtlasEmoji({required this.image, required this.src, required this.size});

  final ui.Image image;
  final Rect src;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    // A hair of air on each side, so a run of emoticons reads as a run and
    // not one pasted strip.
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: CustomPaint(size: Size.square(size), painter: _AtlasEmojiPainter(this)),
  );
}

final class _AtlasEmojiPainter extends CustomPainter {
  _AtlasEmojiPainter(this.emoji);

  final _AtlasEmoji emoji;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawImageRect(emoji.image, emoji.src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);

  @override
  bool shouldRepaint(_AtlasEmojiPainter old) =>
      old.emoji.image != emoji.image || old.emoji.src != emoji.src || old.emoji.size != emoji.size;
}
