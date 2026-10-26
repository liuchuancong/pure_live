import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/translations.dart';

/// The count a gift line shows: the platform's running combo total when it
/// is larger than this hit's count.
int giftShownCount(LiveGift gift) {
  final combo = gift.combo.comboTotal ?? 0;
  return combo > gift.count ? combo : gift.count;
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
