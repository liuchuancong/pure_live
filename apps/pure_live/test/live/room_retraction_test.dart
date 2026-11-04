import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart' show RoomChatController, roomChatProvider;

LiveMessage _chat(String id, {String userId = '', String userName = ''}) => LiveMessage.normalized(
  text: 'line $id',
  sender: MessageSender.of(userId: userId, userName: userName),
  messageId: id,
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

  test('a retraction by message id takes that line back', () {
    chat
      ..add(_chat('a', userId: 'u1', userName: 'Ann'))
      ..add(_chat('b', userId: 'u2', userName: 'Bob'))
      ..retract(LiveRetraction.of(messageId: 'a'));

    expect(_ids(container), ['b']);
  });

  test('a retraction by user takes one line of chat, matched by id or by name', () {
    chat
      ..add(_chat('a', userId: 'u1', userName: 'Ann'))
      ..add(_chat('b', userId: 'u1', userName: 'Ann'))
      ..add(_chat('c', userId: 'u2', userName: 'Bob'))
      ..retract(LiveRetraction.of(userId: 'U1'));
    expect(_ids(container), ['c']);

    chat
      ..add(_chat('d', userName: 'Ann'))
      ..retract(LiveRetraction.of(userId: 'ann'));

    expect(_ids(container), ['c']);
  });

  test('a retraction of the whole chat leaves the gifts and the notices', () {
    chat
      ..add(_chat('a', userId: 'u1'))
      ..add(LiveMessage.normalized(type: LiveMessageType.notice, text: 'joined', messageId: 'n1'))
      ..add(LiveMessage.normalized(type: LiveMessageType.gift, text: 'gift', messageId: 'g1'))
      ..retract(LiveRetraction.of(all: true));

    expect(_ids(container), ['n1', 'g1']);
  });

  test('a retraction that matches nothing leaves the list alone', () {
    chat.add(_chat('a', userId: 'u1'));
    final before = container.read(roomChatProvider);

    chat.retract(LiveRetraction.of(messageId: 'zz'));

    expect(container.read(roomChatProvider), same(before));
    expect(_ids(container), ['a']);
  });
}
