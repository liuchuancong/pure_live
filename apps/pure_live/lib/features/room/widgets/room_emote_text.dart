import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveEmote;

/// The text of a danmaku with its emote codes replaced by the pictures the
/// platform ships for them.
///
/// A site hands the codes and the images together (`LiveMessage.emotes`: the
/// code exactly as it appears in the text, and the address of its picture), so
/// `[笑哭]` can be drawn as the glyph the platform's own clients show instead of
/// as five characters of brackets. The split is deliberately dumb: the earliest
/// code found at each step wins, so overlapping codes resolve the way the site
/// writes them rather than by a longer-match table nobody maintains.
///
/// Two failures keep their text. A code whose picture never arrives falls back
/// to the code, so a dead CDN costs a bracket and not the message, and a
/// message with no emotes is one span — no walk, no allocation.
List<InlineSpan> emoteSpans({required String text, required List<LiveEmote> emotes, TextStyle? style}) {
  final pictures = {
    for (final emote in emotes)
      if (emote.code.isNotEmpty && emote.url.isNotEmpty) emote.code: emote.url,
  };
  if (text.isEmpty || pictures.isEmpty) {
    return [TextSpan(text: text, style: style)];
  }
  final size = (style?.fontSize ?? 14.0) * 1.2;
  final spans = <InlineSpan>[];
  var rest = text;
  while (rest.isNotEmpty) {
    var bestCode = '';
    var bestIndex = -1;
    for (final code in pictures.keys) {
      final index = rest.indexOf(code);
      if (index >= 0 && (bestIndex < 0 || index < bestIndex || (index == bestIndex && code.length > bestCode.length))) {
        bestCode = code;
        bestIndex = index;
      }
    }
    if (bestIndex < 0) {
      spans.add(TextSpan(text: rest, style: style));
      break;
    }
    if (bestIndex > 0) {
      spans.add(TextSpan(text: rest.substring(0, bestIndex), style: style));
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: CachedNetworkImage(
          imageUrl: pictures[bestCode]!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => Text(bestCode, style: style),
        ),
      ),
    );
    rest = rest.substring(bestIndex + bestCode.length);
  }
  return spans;
}
