import 'package:live_sites/src/common/danmaku/filters/text_shape.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:test/test.dart';

LiveMessage _message(String text, {List<String> codes = const []}) => LiveMessage.normalized(
  text: text,
  emotes: [for (final code in codes) LiveEmote.of(code: code, url: 'https://cdn/emote.png')],
);

void main() {
  group('the shape a content block reads', () {
    test('a line of Unicode emoji is nothing but emoticons', () {
      expect(danmakuMessageShape(_message('😂😂')).emoteOnly, isTrue);
      expect(danmakuMessageShape(_message('😂😂')).length, 2);
    });

    test('a code the message names itself counts as one character', () {
      final shape = danmakuMessageShape(_message('[干杯][干杯]ccc', codes: const ['[干杯]']));

      expect(shape.emoteOnly, isFalse);
      expect(shape.length, 5);
    });

    test('a bracketed code is ordinary text until a catalogue says otherwise', () {
      final shape = danmakuMessageShape(_message('[笑哭][笑哭]'));

      expect(shape.emoteOnly, isFalse);
      expect(shape.length, 8);
    });

    test("the host's catalogue turns those same brackets into pictures", () {
      final atlas = RegExp(r'\[笑哭\]|\[干杯\]');
      final only = danmakuMessageShape(_message('[笑哭] [干杯]'), emoticonPattern: atlas);
      final mixed = danmakuMessageShape(_message('[笑哭]下单'), emoticonPattern: atlas);

      expect(only.length, 2);
      expect(only.emoteOnly, isTrue);
      // One emoticon plus the two words it was sent with — not the eight
      // characters the line is typed as, which is what "屏蔽超长" counts.
      expect(mixed.emoteOnly, isFalse);
      expect(mixed.length, 3);
    });

    test('a catalogue is read before the message names its own codes', () {
      final atlas = RegExp(r'\[笑哭\]');

      expect(danmakuMessageShape(_message('[笑哭]', codes: const ['[笑哭]']), emoticonPattern: atlas).length, 1);
    });
  });
}
