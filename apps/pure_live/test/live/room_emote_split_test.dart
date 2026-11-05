import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/modules/live/room/chat/room_emotes.dart';

LiveEmote _emote(String code, String url) => LiveEmote.of(code: code, url: url);

void main() {
  group('splitPlatformEmotes', () {
    test("a line without the platform's own emoticons is one piece of words", () {
      expect(splitPlatformEmotes('今天播什么', const <LiveEmote>[]), [(text: '今天播什么', emoteUrl: null)]);
      expect(splitPlatformEmotes('', const <LiveEmote>[]), isEmpty);
    });

    test('a code becomes the picture the platform named, in place', () {
      final pieces = splitPlatformEmotes('主播好[dog]加油', [_emote('[dog]', 'https://p/1.png')]);

      expect(pieces, [
        (text: '主播好', emoteUrl: null),
        (text: '[dog]', emoteUrl: 'https://p/1.png'),
        (text: '加油', emoteUrl: null),
      ]);
    });

    test('the longest code wins where two begin at the same letter', () {
      // A platform can name a short code that is also the head of a longer one;
      // the longer is what the line actually wrote, so it is what gets drawn.
      final pieces = splitPlatformEmotes('[a]b后', [
        _emote('[a]', 'https://p/short.png'),
        _emote('[a]b', 'https://p/long.png'),
      ]);

      expect(pieces, [(text: '[a]b', emoteUrl: 'https://p/long.png'), (text: '后', emoteUrl: null)]);
    });

    test('a code the line does not carry is left out', () {
      // Bilibili names a sticker for the whole text and, beside it, the inline
      // codes of its table; only what the words actually contain may cut them.
      final pieces = splitPlatformEmotes('普通的一句话', [_emote('[dog]', 'https://p/1.png')]);

      expect(pieces, [(text: '普通的一句话', emoteUrl: null)]);
    });

    test('a whole-line sticker is one picture', () {
      expect(splitPlatformEmotes('[表情]', [_emote('[表情]', 'https://p/sticker.png')]), [
        (text: '[表情]', emoteUrl: 'https://p/sticker.png'),
      ]);
    });

    test('an emote without a code or a picture is nothing to draw', () {
      final pieces = splitPlatformEmotes('a[dog]b', [
        _emote('', 'https://p/1.png'),
        _emote('[dog]', ' '),
        _emote('[dog]', 'https://p/2.png'),
      ]);

      // The blank url is not a picture, so the first usable one for that code
      // is the one kept.
      expect(pieces, [
        (text: 'a', emoteUrl: null),
        (text: '[dog]', emoteUrl: 'https://p/2.png'),
        (text: 'b', emoteUrl: null),
      ]);
    });

    test('the same code twice draws twice', () {
      expect(splitPlatformEmotes('[dog][dog]', [_emote('[dog]', 'https://p/1.png')]), [
        (text: '[dog]', emoteUrl: 'https://p/1.png'),
        (text: '[dog]', emoteUrl: 'https://p/1.png'),
      ]);
    });
  });
}
