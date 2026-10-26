import 'dart:math' as math;

import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/translations.dart';

/// The count a gift line shows: the platform's running combo total when it
/// is larger than this hit's count.
int giftShownCount(LiveGift gift) {
  final combo = gift.combo.comboTotal ?? 0;
  return combo > gift.count ? combo : gift.count;
}

/// The key that groups one combo: the platform's own when it has one, else
/// the sender, kind and gift (and receiver, for a cross-room gift).
String giftComboKeyOf(LiveMessage message, LiveGift gift) {
  final platform = gift.combo.comboKey.trim();
  if (platform.isNotEmpty) return 'combo:$platform';
  final sender = message.sender;
  final id = gift.giftId.trim().isNotEmpty ? gift.giftId.trim() : gift.name.trim();
  final receiver = gift.recipientName.trim();
  return 'sender:${gift.kind.name}:${sender?.userId ?? ''}\u0000${sender?.userName ?? ''}\u0000$id'
      '${receiver.isEmpty ? '' : '\u0000→$receiver'}';
}

/// The count a combo starts with: the platform's running count when it
/// joined during a combo, else the message's.
int giftComboStart(LiveGift gift) => math.max(gift.combo.comboTotal ?? 0, gift.count);

/// The count of a combo that showed [shown] once [gift] counts on it.
int giftComboTotal(int shown, LiveGift gift) {
  final running = gift.combo.comboTotal;
  if (running == null) return shown + gift.count;
  if (running == gift.count) return math.max(shown, running);
  return math.max(running, shown + gift.count);
}

/// Whether a combo whose last gift said [running] started again at [gift].
bool giftComboRestarted(int? running, LiveGift gift) {
  final next = gift.combo.comboTotal;
  return next != null && running != null && next <= running;
}

/// Whether [gift] is the platform's summary of a combo: it carries the
/// combo key and its running count is its own count.
bool giftIsComboSummary(LiveGift gift) =>
    gift.combo.comboKey.trim().isNotEmpty && gift.combo.comboTotal == gift.count;

/// The value of [count] gifts like [gift], in its unit.
double? giftValueOfCount(LiveGift gift, int count) {
  final unitPrice = gift.value.unitPrice;
  if (unitPrice != null) return unitPrice * count;
  final value = gift.value.totalValue;
  if (value == null) return null;
  return value * count / math.max(gift.count, 1);
}

/// The tier a gift's line shows, with the combo count the platform reports:
/// a combo climbs tiers as it grows.
LiveGiftTier giftLineTier(LiveGift gift) {
  final shown = giftShownCount(gift);
  final unitPrice = gift.value.unitPrice;
  final total = shown != gift.count && unitPrice != null && unitPrice > 0
      ? unitPrice * shown
      : gift.value.totalValue;
  return giftShownTier(gift.value.unit, total);
}

/// The gift's name, falling back to its id and then to a generic mark.
String giftNameText(Translations t, LiveGift gift) {
  final name = gift.name.trim();
  if (name.isNotEmpty) return name;
  final id = gift.giftId.trim();
  return id.isEmpty ? t.room.giftLineUnnamed : t.room.giftLineNumbered(id: id);
}

/// How the gift was given; a cross-room gift names its receiver.
String giftVerbText(Translations t, LiveGift gift, String anchorName) {
  final receiver = gift.recipientName.trim();
  if (gift.kind == LiveGiftKind.normal && receiver.isNotEmpty && receiver != anchorName.trim()) {
    return t.room.giftLineSentTo(name: receiver);
  }
  return switch (gift.kind) {
    LiveGiftKind.normal => t.room.giftLineSent,
    LiveGiftKind.subscription => t.room.giftLineGifted,
    LiveGiftKind.tip => t.room.giftLineTipped,
  };
}

/// The count of [gift] as the line shows it, or the combo's [count] when
/// the caller has accumulated one.
String giftCountText(Translations t, LiveGift gift, {int? count}) {
  final shown = count ?? giftShownCount(gift);
  return switch (gift.kind) {
    LiveGiftKind.subscription => t.room.giftLineMonths(count: '$shown'),
    LiveGiftKind.tip when shown == 1 => '',
    _ => t.room.giftLineCount(count: '$shown'),
  };
}

/// The gift in words: "送出 小心心 ×3", without the value a chat line adds.
String giftSentenceText(Translations t, LiveGift gift, String anchorName, {int? count}) {
  final shown = giftCountText(t, gift, count: count);
  return '${giftVerbText(t, gift, anchorName)} ${giftNameText(t, gift)}${shown.isEmpty ? '' : ' $shown'}';
}
