import 'dart:collection';

import 'package:live_sites/live_sites.dart';
import 'package:pure_live/modules/live/room/chat/gift_text.dart';

/// One gift line for the chat list: [replaceId] names the line this one
/// updates (a combo's count grew), null for a new line.
final class GiftChatLine {
  const GiftChatLine(this.message, {this.replaceId});

  final LiveMessage message;
  final String? replaceId;
}

/// The reference's gift lines for the chat list: every gift gets one line,
/// and a combo's later gifts update that same line (the count and value
/// grow, and it moves to the bottom) instead of stacking. With [aboveTier]
/// on, free and cheap gifts stay out; a combo is counted out of sight and
/// gets one line once its total is worth [LiveGiftTier.valuable], the line
/// showing the whole total as the combo goes on.
final class GiftChatFilter {
  GiftChatFilter({required this.clock});

  /// How long after a combo's last gift the next one still counts on it,
  /// the same window the flying gifts use.
  static const Duration comboWindow = Duration(seconds: 5);

  /// How long after a combo's last gift its platform summary still updates
  /// the same line (Bilibili's `COMBO_SEND`, the reference's 15 s).
  static const Duration summaryWindow = Duration(seconds: 15);

  /// Combos remembered; the least recent goes first.
  static const int _maxCombos = 256;

  /// What "now" is.
  final DateTime Function() clock;
  final LinkedHashMap<String, _Combo> _combos = LinkedHashMap();
  bool _aboveTier = false;
  int _sequence = 0;

  /// Whether cheap gifts stay out of the list.
  bool get aboveTier => _aboveTier;

  set aboveTier(bool value) {
    if (value == _aboveTier) return;
    _aboveTier = value;
    _combos.clear();
  }

  /// Forgets the combos counted out of sight (the gift switch went off).
  void clear() => _combos.clear();

  /// The line to show for [message], or null while its combo is still below
  /// the tier. Off the tier gate, every gift keeps a line and a combo
  /// updates it in place.
  GiftChatLine? add(LiveMessage message) {
    final gift = message.payload;
    if (gift is! LiveGift || message.isLocal) return GiftChatLine(message);
    final now = clock();
    final key = giftComboKeyOf(message, gift);
    final window = giftIsComboSummary(gift) ? summaryWindow : comboWindow;
    var combo = _combos.remove(key);
    if (combo != null && (now.difference(combo.at) > window || giftComboRestarted(combo.running, gift))) {
      combo = null;
    }
    final total = combo == null ? giftComboStart(gift) : giftComboTotal(combo.total, gift);
    final tier = giftShownTier(gift.value.unit, giftValueOfCount(gift, total));
    final lineId = combo?.lineId ?? _newLineId(message, now);
    _combos[key] = _Combo(
      at: now,
      total: total,
      running: gift.combo.comboTotal ?? combo?.running,
      lineId: !_aboveTier || tier != LiveGiftTier.normal ? lineId : combo?.lineId,
    );
    if (_combos.length > _maxCombos) _combos.remove(_combos.keys.first);
    if (!_aboveTier) {
      return GiftChatLine(_line(message, gift, total, lineId), replaceId: combo?.lineId);
    }
    if (tier == LiveGiftTier.normal) return null;
    return GiftChatLine(_line(message, gift, total, lineId), replaceId: combo?.lineId);
  }

  String _newLineId(LiveMessage message, DateTime now) {
    final existing = message.messageId.trim();
    if (existing.isNotEmpty) return existing;
    _sequence++;
    return 'gift-line-${now.microsecondsSinceEpoch}-$_sequence';
  }

  LiveMessage _line(LiveMessage message, LiveGift gift, int total, String lineId) {
    var next = total > giftShownCount(gift) ? _withCount(message, gift, total) : message;
    if (next.messageId != lineId) next = next.rebuild((b) => b..messageId = lineId);
    return next;
  }

  LiveMessage _withCount(LiveMessage message, LiveGift gift, int total) {
    final price = gift.value.unitPrice;
    final value = price != null
        ? LiveGiftValue.of(unit: gift.value.unit, unitPrice: price, totalValue: price * total)
        : gift.value;
    final counted = gift.rebuild((b) {
      b.count = total;
      b.value.replace(value);
    });
    return message.rebuild((b) => b..payload = counted);
  }
}

/// One combo seen while the tier gate held: when its last gift came, the
/// running total, the platform's running count, and the line it got once it
/// was worth showing (null while below the tier).
final class _Combo {
  const _Combo({required this.at, required this.total, required this.running, required this.lineId});

  final DateTime at;
  final int total;
  final int? running;
  final String? lineId;
}
