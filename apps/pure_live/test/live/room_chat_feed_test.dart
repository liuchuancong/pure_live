import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart'
    show RoomChatController, kRoomChatGiftLimit, kRoomChatLimit, kRoomGiftLinesPerSecond, roomChatProvider;

LiveMessage _chat(String id, {String userName = '', bool local = false}) => LiveMessage.normalized(
  text: 'line $id',
  sender: MessageSender.of(userId: 'u-$id', userName: userName),
  messageId: id,
  isLocal: local,
);

LiveMessage _words(String id, String text, {bool local = false}) =>
    LiveMessage.normalized(text: text, messageId: id, isLocal: local);

LiveMessage _gift(String id, {double? totalValue, bool local = false}) => LiveMessage.normalized(
  type: LiveMessageType.gift,
  messageId: id,
  isLocal: local,
  payload: LiveGift.of(
    giftId: id,
    name: 'gift $id',
    value: LiveGiftValue.of(unit: LiveGiftUnit.fen, totalValue: totalValue),
  ),
);

List<String> _ids(ProviderContainer container) =>
    container.read(roomChatProvider).map((line) => line.messageId).toList(growable: false);

void main() {
  late ProviderContainer container;
  late RoomChatController chat;

  setUp(() {
    container = ProviderContainer();
    chat = container.read(roomChatProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('the gift lines', () {
    test('gift lines stop at their quota and leave the talk alone', () {
      // A gift every 200 ms: under the rate, so this test sees the quota
      // alone.
      var tick = 0;
      chat.clock = () => DateTime(2026).add(Duration(milliseconds: tick += 200));
      for (var i = 0; i < kRoomChatLimit; i++) {
        chat.add(_chat('c$i'));
      }
      for (var i = 0; i < 70; i++) {
        chat.add(_gift('g$i', totalValue: 100));
      }

      final lines = container.read(roomChatProvider);
      expect(lines, hasLength(kRoomChatLimit));
      expect(chat.giftLines, kRoomChatGiftLimit);
      expect(lines.first.messageId, 'c60');
      expect(lines.last.messageId, 'g69');
    });

    test('a second starts at most ten new gift lines, a valuable one exempt', () {
      var now = DateTime(2026);
      chat.clock = () => now;
      for (var i = 0; i < kRoomGiftLinesPerSecond; i++) {
        chat.add(_gift('g$i', totalValue: 100));
      }
      // Over the rate: a cheap gift waits, a valuable one (1000 fen and up,
      // the 「值钱」 judgment the list already uses) gets its line all the same.
      chat.add(_gift('over', totalValue: 100));
      expect(chat.giftLines, kRoomGiftLinesPerSecond);
      chat.add(_gift('rich', totalValue: 1000));
      expect(chat.giftLines, kRoomGiftLinesPerSecond + 1);

      // A second later the rate is spent again from zero.
      now = now.add(const Duration(seconds: 1));
      chat.add(_gift('later', totalValue: 100));
      expect(chat.giftLines, kRoomGiftLinesPerSecond + 2);
    });

    test('a combo count that grew replaces its line and is not a new message', () {
      final first = _gift('combo', totalValue: 100);
      chat.add(first);
      expect(chat.added, 1);

      final grown = _gift('combo', totalValue: 100);
      chat.add(grown, replaceId: 'combo');
      expect(_ids(container), ['combo']);
      expect(chat.added, 1);
      expect(container.read(roomChatProvider).single, same(grown));
      expect(chat.replacementOf(first), same(grown));

      // A replace whose line fell off the old end appends instead — and
      // counts, for the list never showed what it updates.
      chat.add(_gift('other', totalValue: 100), replaceId: 'gone');
      expect(chat.added, 2);
      expect(_ids(container), ['combo', 'other']);
    });
  });

  group('the removals a held list missed', () {
    test('removalsSince hands the tests of them over, oldest first', () {
      final a = _chat('a');
      final b = _words('b', 'so secret');
      final c = _chat('c', userName: 'Cara');
      chat
        ..add(a)
        ..add(b)
        ..add(c);
      final held = List.of(container.read(roomChatProvider));
      final seen = chat.added;
      final removals = chat.removals;

      chat
        ..retract(LiveRetraction.of(messageId: 'a'))
        ..removeKeyword('secret')
        ..removeUser('cara');

      expect(chat.added - seen, 0);
      final tests = chat.removalsSince(removals)!;
      expect(tests, hasLength(3));
      final kept = [for (final line in held) if (!tests.any((test) => test(line))) line];
      expect(kept, isEmpty);
      expect(_ids(container), isEmpty);
    });

    test('removalsSince gives up once its tests are forgotten', () {
      for (var i = 0; i < 65; i++) {
        chat.removeKeyword('w$i');
      }
      expect(chat.removalsSince(0), isNull);
      expect(chat.removalsSince(1), isNotNull);
    });

    test('clearing starts the counters again, so a saved place is not taken', () {
      chat
        ..add(_chat('a'))
        ..removeKeyword('w');
      expect(chat.added, 1);
      expect(chat.removals, 1);

      chat.clear();

      expect(chat.added, 0);
      expect(chat.removals, 0);
      expect(chat.removalsSince(0), isEmpty);
      expect(container.read(roomChatProvider), isEmpty);
    });
  });

  group('a block takes the lines already shown', () {
    test('the lines of a blocked viewer go, the local ones stay', () {
      chat
        ..add(_chat('a', userName: 'Bob'))
        ..add(_chat('b', userName: 'Bob'))
        ..add(_chat('mine', userName: 'Me', local: true))
        ..add(_gift('g', totalValue: 100))
        ..removeUser('bob');

      expect(_ids(container), ['mine', 'g']);
    });

    test('a blocked word takes talk and gift lines, not a paid card nor the local ones', () {
      chat
        ..add(_words('a', 'hello there'))
        ..add(_words('b', 'so secret'))
        ..add(LiveMessage.normalized(type: LiveMessageType.gift, text: 'a secret gift', messageId: 'g'))
        ..add(LiveMessage.normalized(type: LiveMessageType.superChat, text: 'secret paid', messageId: 'sc'))
        ..add(_words('mine', 'my secret words', local: true))
        ..removeKeyword('secret');

      expect(_ids(container), ['a', 'sc', 'mine']);
    });

    test('a blocked word written /…/ matches as a pattern', () {
      chat
        ..add(_words('a', 'hello world'))
        ..add(_words('b', 'hello there'))
        ..removeKeyword('/w.rld/');

      expect(_ids(container), ['b']);
    });
  });
}
