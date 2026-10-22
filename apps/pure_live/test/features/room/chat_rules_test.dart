import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/chat_rules.dart';

/// The chat list's switches, read without a room: a gift line follows its own
/// switch, a membership can also earn a super-chat card.

LiveMessage _message(LiveMessageType type, {String text = 'text', String user = '主播', String avatar = ''}) =>
    LiveMessage.normalized(
      type: type,
      text: text,
      sender: MessageSender.normalized(userName: user, avatarUrl: avatar),
      messageId: 'm1',
    );

void main() {
  test('a gift takes a chat line only while its switch is on', () {
    final gift = _message(LiveMessageType.gift);
    expect(chatLineVisible(gift, showGifts: true), isTrue);
    expect(chatLineVisible(gift, showGifts: false), isFalse);
  });

  test('chat and the quiet types keep their lines', () {
    for (final type in [
      LiveMessageType.chat,
      LiveMessageType.notice,
      LiveMessageType.enter,
      LiveMessageType.membershipJoin,
      LiveMessageType.system,
    ]) {
      expect(chatLineVisible(_message(type), showGifts: false), isTrue, reason: type.name);
    }
    expect(chatLineVisible(_message(LiveMessageType.audienceUpdate), showGifts: true), isFalse);
    expect(chatLineVisible(_message(LiveMessageType.retraction), showGifts: true), isFalse);
  });

  test('a membership earns a super-chat card only when asked', () {
    final join = _message(LiveMessageType.membershipJoin, text: '开通了舰长', user: 'Alice', avatar: 'a.png');
    expect(membershipCard(join, include: false), isNull);

    final card = membershipCard(join, include: true);
    expect(card, isNotNull);
    expect(card!.userName, 'Alice');
    expect(card.faceUrl, 'a.png');
    expect(card.text, '开通了舰长');
    expect(card.messageId, 'm1');
  });

  test('other messages never become super-chat cards', () {
    for (final type in [LiveMessageType.chat, LiveMessageType.gift, LiveMessageType.enter]) {
      expect(membershipCard(_message(type), include: true), isNull, reason: type.name);
    }
    expect(membershipCard(_message(LiveMessageType.membershipJoin, text: ''), include: true), isNull);
  });
}
