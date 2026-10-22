import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/formatters/formatters.dart' show compactCount;

/// The gift line's numbers (the reference's `gift_words.dart`): how many a
/// gift line shows after "×", what that many is worth, the tier it marks and
/// the value written in the platform's unit or in yuan.

/// The count a gift line shows after "×": the platform's running combo count
/// when it gives one and it is larger than this message's count.
int giftShownCount(LiveGift gift) => math.max(gift.count, gift.combo.comboTotal ?? 0);

/// What the shown count is worth, in the gift's unit: the unit price times
/// the shown count when a combo count is shown, else the message's own value;
/// null for a free gift or an unknown value.
double? giftShownValue(LiveGift gift) {
  final unit = gift.value.unit;
  if (giftUnitIsFree(unit)) {
    return null;
  }
  final shown = giftShownCount(gift);
  final price = gift.value.unitPrice;
  if (shown != gift.count && price != null && price > 0) {
    return price * shown;
  }
  return gift.value.totalValue;
}

/// The tier a gift line marks: its shown value in its unit (a combo climbs as
/// it grows), normal for a free or unrated one.
LiveGiftTier giftShownTierOf(LiveGift gift) => giftShownTier(gift.value.unit, giftShownValue(gift));

/// Whether a gift line survives the "只显示值钱的礼物" switch (a gift without
/// a payload has no value to place and stays out).
bool giftLineVisible(LiveGift? gift, {required bool valuableOnly}) =>
    !valuableOnly || (gift != null && giftShownTierOf(gift) != LiveGiftTier.normal);

/// The value as the line writes it ("2000 金瓜子", "2 元" with [inYuan]); null
/// when there is none to show: free, unknown, zero, or a unit the app does not
/// label.
String? giftValueText(BuildContext context, LiveGift gift, {required bool inYuan}) {
  final value = giftShownValue(gift);
  if (value == null || value <= 0) {
    return null;
  }
  final unit = gift.value.unit;
  final t = context.t.danmaku;
  if (inYuan) {
    final rate = giftUnitsPerYuan[unit];
    if (rate != null) {
      final yuan = value / rate;
      return t.giftValueYuanLabel(value: _amount(context, yuan < 0.01 ? 0.01 : yuan));
    }
  }
  final yuan = switch (unit) {
    LiveGiftUnit.fen => value / 100,
    LiveGiftUnit.yuan || LiveGiftUnit.rmb => value,
    _ => null,
  };
  if (yuan != null) {
    return t.giftValueYuanLabel(value: _amount(context, yuan));
  }
  final amount = _amount(context, value);
  return switch (unit) {
    LiveGiftUnit.goldSeed => t.giftValueGoldSeed(value: amount),
    LiveGiftUnit.diamond => t.giftValueDiamond(value: amount),
    LiveGiftUnit.redBean => t.giftValueRedBean(value: amount),
    LiveGiftUnit.bits => t.giftValueBits(value: amount),
    LiveGiftUnit.kicks => t.giftValueKicks(value: amount),
    LiveGiftUnit.cheese => t.giftValueCheese(value: amount),
    LiveGiftUnit.starBalloon => t.giftValueStarBalloon(value: amount),
    LiveGiftUnit.douyinCoin => t.giftValueDouyinCoin(value: amount),
    LiveGiftUnit.sixCoin => t.giftValueSixCoin(value: amount),
    LiveGiftUnit.acCoin => t.giftValueAcCoin(value: amount),
    LiveGiftUnit.starCoin => t.giftValueStarCoin(value: amount),
    LiveGiftUnit.heart => t.giftValueHeart(value: amount),
    LiveGiftUnit.note => t.giftValueNote(value: amount),
    LiveGiftUnit.point => t.giftValuePoint(value: amount),
    LiveGiftUnit.fen ||
    LiveGiftUnit.yuan ||
    LiveGiftUnit.silver ||
    LiveGiftUnit.banana ||
    LiveGiftUnit.gold ||
    LiveGiftUnit.rmb ||
    LiveGiftUnit.free ||
    LiveGiftUnit.other => null,
  };
}

/// A value as the app writes it ("2000", "0.1", "12.5", "1.2万"): large
/// numbers take the compact form every counter in the app uses.
String _amount(BuildContext context, double value) {
  if (value >= 10000) {
    return compactCount(value.round(), cjk: Localizations.localeOf(context).languageCode == 'zh');
  }
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
