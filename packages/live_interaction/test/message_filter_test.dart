import 'package:live_interaction/live_interaction.dart';
import 'package:live_sites/live_sites.dart';
import 'package:test/test.dart';

LiveMessage _chat(
  String text, {
  String user = 'viewer',
  List<LiveEmote> emotes = const [],
  LiveMessageType type = LiveMessageType.chat,
}) => LiveMessage(
  type: type,
  text: text,
  sender: MessageSender(userName: user),
  emotes: emotes,
);

void main() {
  group('block rules', () {
    test('a keyword rule drops the text containing it', () {
      final filter = MessageFilter(
        rules: [const BlockRule(kind: BlockKind.keyword, pattern: '广告')],
      );
      expect(filter.allows(_chat('免费领 广告 链接')), isFalse);
      expect(filter.allows(_chat('今天播什么')), isTrue);
    });

    test('a /regex/ rule matches as a pattern', () {
      final filter = MessageFilter(
        rules: [const BlockRule(kind: BlockKind.keyword, pattern: r'/^出\d+$/')],
      );
      expect(filter.allows(_chat('出12')), isFalse);
      expect(filter.allows(_chat('不出12')), isTrue);
    });

    test('a user rule matches the sender name case-insensitively', () {
      final filter = MessageFilter(
        rules: [const BlockRule(kind: BlockKind.user, pattern: 'Spammer')],
      );
      expect(filter.allows(_chat('hello', user: 'SPAMMER')), isFalse);
      expect(filter.allows(_chat('hello')), isTrue);
    });
  });

  group('live blocks (the danmaku panel’s 屏蔽此用户 / 屏蔽关键词)', () {
    test('addUser drops that sender from now on', () {
      final filter = MessageFilter(rules: const []);
      expect(filter.allows(_chat('hi', user: 'Troll')), isTrue);
      filter.addUser('Troll');
      expect(filter.allows(_chat('again', user: 'troll')), isFalse);
      expect(filter.allows(_chat('still fine', user: 'Other')), isTrue);
    });

    test('addKeyword matches plain words and the /regex/ spelling', () {
      final filter = MessageFilter(rules: const [])
        ..addKeyword('刷屏')
        ..addKeyword(r'/^出\d+$/');
      expect(filter.allows(_chat('别刷屏了')), isFalse);
      expect(filter.allows(_chat('出7')), isFalse);
      expect(filter.allows(_chat('你好')), isTrue);
    });
  });

  group('pure-emoji gate', () {
    test('drops a chat whose emote codes cover the whole text', () {
      final filter = MessageFilter(rules: const []);
      final emotes = [const LiveEmote(code: '[笑]', url: 'https://e/1.png')];
      expect(filter.allows(_chat('[笑][笑]', emotes: emotes)), isFalse);
      expect(filter.allows(_chat('[笑] 好', emotes: emotes)), isTrue);
    });

    test('leaves chats alone when the gate is off', () {
      final filter = MessageFilter(rules: const [], dropPureEmoji: false);
      final emotes = [const LiveEmote(code: '[笑]', url: 'https://e/1.png')];
      expect(filter.allows(_chat('[笑][笑]', emotes: emotes)), isTrue);
    });

    test('a text with no emotes is never "pure emoji"', () {
      final filter = MessageFilter(rules: const []);
      expect(filter.allows(_chat('哈哈哈')), isTrue);
    });
  });

  group('repeat collapse', () {
    test('the second identical chat from another sender inside the window is dropped', () {
      final filter = MessageFilter(rules: const [], collapseRepeated: true, repeatedWindow: const Duration(seconds: 5));
      expect(filter.allows(_chat('666', user: 'a')), isTrue);
      expect(filter.allows(_chat('666', user: 'b')), isFalse);
      expect(filter.allows(_chat('666', user: 'a')), isFalse);
    });

    test('different texts survive', () {
      final filter = MessageFilter(rules: const [], collapseRepeated: true, repeatedWindow: const Duration(seconds: 5));
      expect(filter.allows(_chat('666', user: 'a')), isTrue);
      expect(filter.allows(_chat('888', user: 'b')), isTrue);
    });

    test('the same text after the window passes again', () async {
      final filter = MessageFilter(
        rules: const [],
        collapseRepeated: true,
        repeatedWindow: const Duration(milliseconds: 30),
      );
      expect(filter.allows(_chat('666', user: 'a')), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(filter.allows(_chat('666', user: 'b')), isTrue);
    });

    test('non-chat messages are not collapsed', () {
      final filter = MessageFilter(rules: const [], collapseRepeated: true, repeatedWindow: const Duration(seconds: 5));
      expect(filter.allows(_chat('赠送礼物', type: LiveMessageType.gift, user: 'a')), isTrue);
      expect(filter.allows(_chat('赠送礼物', type: LiveMessageType.gift, user: 'b')), isTrue);
    });

    test('off by default: both copies pass', () {
      final filter = MessageFilter(rules: const []);
      expect(filter.allows(_chat('666', user: 'a')), isTrue);
      expect(filter.allows(_chat('666', user: 'b')), isTrue);
    });

    test('the window and the gate apply live — a settings edit without a reconnect', () {
      final filter = MessageFilter(rules: const []);
      expect(filter.allows(_chat('666', user: 'a')), isTrue);
      expect(filter.allows(_chat('666', user: 'b')), isTrue);
      filter.collapseRepeated = true;
      // The first copy of the fresh era still passes; the memory predates it.
      expect(filter.allows(_chat('777', user: 'a')), isTrue);
      expect(filter.allows(_chat('777', user: 'b')), isFalse);
    });
  });
}
