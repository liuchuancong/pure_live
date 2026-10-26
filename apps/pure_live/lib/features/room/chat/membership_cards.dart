import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/chat/gift_text.dart';
import 'package:pure_live/l10n/translations.dart';

/// The start of a membership card's id: the cards this app makes itself,
/// which turning "上舰和开会员进醒目留言" off takes away again.
const String membershipCardIdPrefix = 'membership:';

/// Whether [superChat] is a card [membershipCard] made.
bool isMembershipCard(LiveSuperChatMessage superChat) => superChat.messageId.startsWith(membershipCardIdPrefix);

/// The card among the room's super chats for a membership or subscription
/// the platform reported (the reference's D07.2), or null for any other
/// message:
///
/// - a subscription gift (bilibili's `GUARD_BUY`, another platform's
///   subscription delivered as a gift): the price is what it cost, gold
///   seeds become yuan, another unit stays the platform's; without a price
///   the card names what was bought (舰长); the text is the gift's sentence;
/// - a subscription notice (Twitch, CHZZK, Kick, Picarto): the card names
///   the subscription, since the notice carries no price; the text is the
///   notice without the sender's name before it;
/// - a membership join (YouTube's memberships): the card says 会员, the text
///   is the membership item's own words.
///
/// The card stays as long as a bilibili super chat of its price in yuan
/// would ([membershipCardDuration]), and has no colours or avatar of its
/// own.
LiveSuperChatMessage? membershipCard(LiveMessage message, {required String platform, required DateTime now}) {
  final name = (message.sender?.userName ?? '').trim();
  final String text;
  var price = 0;
  var unit = LiveGiftUnit.other;
  String? label;
  if (message.type == LiveMessageType.gift && message.payload is LiveGift) {
    final gift = message.payload! as LiveGift;
    if (gift.kind != LiveGiftKind.subscription) return null;
    final value = gift.value.totalValue;
    final giftUnit = gift.value.unit;
    if (giftUnitIsFree(giftUnit) || value == null || value <= 0) {
      label = giftNameText(t, gift);
    } else if (giftUnit == LiveGiftUnit.goldSeed) {
      price = (value / giftUnitsPerYuan[LiveGiftUnit.goldSeed]!).round();
      unit = LiveGiftUnit.yuan;
      label = price > 0 ? t.room.giftValueYuan(value: '$price') : giftNameText(t, gift);
    } else {
      price = value.round();
      unit = giftUnit;
      label = _unitValueText(t, giftUnit, price) ?? giftNameText(t, gift);
    }
    text = giftSentenceText(t, gift, '');
  } else if (message.type == LiveMessageType.notice && message.payload == LiveNoticeKind.subscription) {
    final said = message.text.trim();
    if (said.isEmpty) return null;
    label = platform == SiteIds.youtube ? t.room.superChatCardMembership : t.room.superChatCardSubscription;
    final prefix = name.isEmpty ? '' : '$name ';
    final words = said.startsWith(prefix) ? said.substring(prefix.length).trim() : said;
    if (words.isEmpty) return null;
    text = words;
  } else if (message.type == LiveMessageType.membershipJoin) {
    final said = message.text.trim();
    if (said.isEmpty) return null;
    label = platform == SiteIds.youtube ? t.room.superChatCardMembership : t.room.superChatCardSubscription;
    text = said;
  } else {
    return null;
  }
  final start = message.sentAt ?? now;
  final key = message.messageId.isNotEmpty
      ? message.messageId
      : '${message.sender?.userId ?? ''}|$name|${message.sentAt?.millisecondsSinceEpoch ?? ''}|${message.text}';
  return LiveSuperChatMessage.of(
    messageId: '$membershipCardIdPrefix$platform:$key',
    userName: name,
    text: text,
    price: SuperChatPrice.of(amount: price > 0 ? price : null, displayText: label),
    startTime: start,
    endTime: start.add(membershipCardDuration(price, unit)),
  );
}

/// How long a membership card stays: the steps of bilibili's super chats by
/// the price in yuan (30 yuan a minute, 50 two, 100 five, 500 thirty, 1000
/// an hour, 2000 two hours), at least a minute; a minute when the price is
/// unknown or in a unit with no rate in yuan.
Duration membershipCardDuration(int price, LiveGiftUnit unit) {
  final rate = giftUnitsPerYuan[unit];
  final yuan = rate == null || price <= 0 ? 0 : price / rate;
  return switch (yuan) {
    >= 2000 => const Duration(hours: 2),
    >= 1000 => const Duration(hours: 1),
    >= 500 => const Duration(minutes: 30),
    >= 100 => const Duration(minutes: 5),
    >= 50 => const Duration(minutes: 2),
    _ => const Duration(minutes: 1),
  };
}

/// A fen amount as yuan, without trailing zeros ("100", "0.5", "12.34").
String _yuanText(int fen) {
  if (fen % 100 == 0) return '${fen ~/ 100}';
  final text = (fen / 100).toStringAsFixed(2);
  final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// The price in the unit the platform counts it, in the words the chat's
/// gift lines use; null for a unit without a name (the caller shows the
/// gift's own name instead).
String? _unitValueText(Translations t, LiveGiftUnit unit, int value) {
  if (value <= 0) return null;
  final room = t.room;
  return switch (unit) {
    LiveGiftUnit.fen => room.giftValueYuan(value: _yuanText(value)),
    LiveGiftUnit.rmb || LiveGiftUnit.yuan => room.giftValueYuan(value: '$value'),
    LiveGiftUnit.diamond => room.giftValueDiamond(value: '$value'),
    LiveGiftUnit.redBean => room.giftValueRedBean(value: '$value'),
    LiveGiftUnit.point => room.giftValuePoint(value: '$value'),
    LiveGiftUnit.bits => room.giftValueBits(value: '$value'),
    LiveGiftUnit.kicks => room.giftValueKicks(value: '$value'),
    LiveGiftUnit.cheese => room.giftValueCheese(value: '$value'),
    LiveGiftUnit.starBalloon => room.giftValueStarBalloon(value: '$value'),
    LiveGiftUnit.douyinCoin => room.giftValueDouyinCoin(value: '$value'),
    LiveGiftUnit.sixCoin => room.giftValueSixCoin(value: '$value'),
    LiveGiftUnit.acCoin => room.giftValueAcCoin(value: '$value'),
    LiveGiftUnit.starCoin => room.giftValueStarCoin(value: '$value'),
    LiveGiftUnit.heart => room.giftValueHeart(value: '$value'),
    LiveGiftUnit.note => room.giftValueNote(value: '$value'),
    LiveGiftUnit.goldSeed ||
    LiveGiftUnit.free ||
    LiveGiftUnit.silver ||
    LiveGiftUnit.banana ||
    LiveGiftUnit.gold ||
    LiveGiftUnit.other => null,
  };
}
