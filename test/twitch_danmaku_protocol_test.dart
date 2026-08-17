import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/danmaku/twitch_danmaku.dart';

void main() {
  group('Twitch IRC protocol', () {
    test('keeps messages whose user has no configured color', () {
      final danmaku = TwitchDanmaku();
      final messages = danmaku.parseMessages(
        '@color=;display-name=Viewer;id=m1;tmi-sent-ts=1700000000000;user-id=u1 '
        ':viewer!viewer@viewer.tmi.twitch.tv PRIVMSG #room :hello',
      );

      expect(messages, hasLength(1));
      expect(messages.single.userName, 'Viewer');
      expect(messages.single.userId, 'u1');
      expect(messages.single.messageId, 'm1');
      expect(messages.single.message, 'hello');
      expect(messages.single.color.toString(), '#ffffff');
      expect(messages.single.sentAt?.millisecondsSinceEpoch, 1700000000000);
    });

    test('decodes every line and IRC escaped display names', () {
      final danmaku = TwitchDanmaku();
      final messages = danmaku.parseMessages(
        '@color=#00FF7F;display-name=First\\sUser;id=m1 '
        ':first!first@first.tmi.twitch.tv PRIVMSG #room :one\r\n'
        '@color=#FF0000;display-name=;id=m2 '
        ':second!second@second.tmi.twitch.tv PRIVMSG #room :two',
      );

      expect(messages.map((message) => message.userName), ['First User', 'second']);
      expect(messages.map((message) => message.message), ['one', 'two']);
      expect(messages.map((message) => message.color.toString()), ['#00ff7f', '#ff0000']);
    });
  });
}
