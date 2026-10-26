import 'dart:async';
import 'dart:collection';

import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/chat/gift_text.dart';
import 'package:pure_live/l10n/translations.dart' as l10n;

/// Which of a room's gifts fly over the picture (the reference's
/// `danmakuShowGifts`, A08.12), so a busy room's gifts never flood it:
///
/// - only gifts worth a mark ([LiveGiftTier.valuable] and up);
/// - a combo (the same sender's same gift within [comboWindow]) flies twice
///   at most: when it first is worth a mark, and once more when it ends if
///   its total grew since;
/// - at most [perSecond] a second; one over it does not fly (the chat list
///   still has it), and an ending combo waits for no one either.
///
/// The gift's words are "名字 送出 礼物 ×N" in [ink]; a precious gift stands
/// at the top for [preciousHold], a valuable one scrolls.
final class GiftFlights {
  GiftFlights({required this.clock, required this.emit, String Function()? streamer}) : streamer = streamer ?? _nobody;

  /// Gifts that fly in one second, at most.
  static const int perSecond = 3;

  /// How long a combo waits for its next gift before it ends.
  static const Duration comboWindow = Duration(seconds: 5);

  /// How often ended combos are looked for.
  static const Duration sweep = Duration(seconds: 1);

  /// How long an ended combo is remembered, so a platform's summary that
  /// comes after the end does not fly the same total again.
  static const Duration summaryWindow = Duration(seconds: 15);

  /// How long a precious gift stands at the top.
  static const Duration preciousHold = Duration(seconds: 4);

  /// The reference's gift gold.
  static const Color ink = Color(0xFFFFD166);

  /// Combos remembered; the least recent goes first.
  static const int _maxCombos = 256;

  static const Duration _second = Duration(seconds: 1);

  static String _nobody() => '';

  /// What "now" is (tests fix it).
  final DateTime Function() clock;

  /// Where a flying gift goes.
  final void Function(BarrageItem item) emit;

  /// The room's streamer, who is not named as every gift's receiver.
  final String Function() streamer;
  final LinkedHashMap<String, _Flight> _combos = LinkedHashMap();
  final ListQueue<DateTime> _flown = ListQueue();
  final Map<String, _Ended> _ended = {};
  Timer? _sweeper;

  /// Takes [message], a platform's gift.
  void add(LiveMessage message) {
    final gift = message.payload;
    if (gift is! LiveGift || message.isLocal) return;
    final now = clock();
    _endBefore(now);
    final key = giftComboKeyOf(message, gift);
    _ended.removeWhere((_, ended) => now.difference(ended.at) > summaryWindow);
    if (giftIsComboSummary(gift) && !_combos.containsKey(key)) {
      // The summary of a combo that already ended (and flew its total).
      final ended = _ended[key];
      if (ended != null && giftComboStart(gift) <= ended.total) return;
    }
    var combo = _combos.remove(key);
    if (combo != null && giftComboRestarted(combo.running, gift)) {
      _end(combo, now: now);
      combo = null;
    }
    final total = combo == null ? giftComboStart(gift) : giftComboTotal(combo.total, gift);
    var flown = combo?.flown ?? 0;
    if (flown == 0 && _worthFlying(gift, total) && _fly(message, gift, total, now)) flown = total;
    _combos[key] = _Flight(
      message,
      gift,
      at: now,
      total: total,
      running: gift.combo.comboTotal ?? combo?.running,
      flown: flown,
    );
    if (_combos.length > _maxCombos) _combos.remove(_combos.keys.first);
    _sweeper ??= Timer.periodic(sweep, (_) => _endBefore(clock()));
  }

  /// Forgets the combos without flying their ends (the switch went off or
  /// the danmaku closed).
  void clear() {
    _combos.clear();
    _ended.clear();
    _flown.clear();
    _sweeper?.cancel();
    _sweeper = null;
  }

  /// Stops for good.
  void dispose() => clear();

  /// Ends the combos whose last gift came more than [comboWindow] before
  /// [now].
  void _endBefore(DateTime now) {
    if (_combos.isEmpty) return;
    final ended = [
      for (final MapEntry(:key, :value) in _combos.entries)
        if (now.difference(value.at) > comboWindow) key,
    ];
    for (final key in ended) {
      final combo = _combos.remove(key)!;
      _end(combo, now: now);
      _ended[key] = _Ended(at: now, total: combo.total);
    }
    if (_combos.isEmpty) {
      _sweeper?.cancel();
      _sweeper = null;
    }
  }

  /// A combo ended: its total flies when it grew since it flew (or it never
  /// flew and is worth it now).
  void _end(_Flight combo, {DateTime? now}) {
    if (combo.total == combo.flown || !_worthFlying(combo.gift, combo.total)) return;
    _fly(combo.message, combo.gift, combo.total, now ?? clock());
  }

  bool _worthFlying(LiveGift gift, int total) =>
      giftShownTier(gift.value.unit, giftValueOfCount(gift, total)) != LiveGiftTier.normal;

  bool _fly(LiveMessage message, LiveGift gift, int total, DateTime now) {
    while (_flown.isNotEmpty && now.difference(_flown.first) >= _second) {
      _flown.removeFirst();
    }
    if (_flown.length >= perSecond) return false;
    _flown.addLast(now);
    emit(_itemFor(message, gift, total));
    return true;
  }

  BarrageItem _itemFor(LiveMessage message, LiveGift gift, int total) {
    final tier = giftShownTier(gift.value.unit, giftValueOfCount(gift, total));
    final precious = tier == LiveGiftTier.precious;
    final name = message.sender?.userName.trim() ?? '';
    final sentence = giftSentenceText(l10n.t, gift, streamer(), count: total);
    return BarrageItem(
      content: name.isEmpty ? sentence : '$name $sentence',
      type: precious ? BarrageType.topFixed : BarrageType.scroll,
      fixedDuration: precious ? preciousHold : null,
      textColor: ink,
      userId: message.sender?.userId,
      userName: name.isEmpty ? null : name,
    );
  }

}

/// One combo on its way: the newest message and its gift, when it came,
/// the running total, the platform's running count, and the total that flew
/// (0 for none).
final class _Flight {
  const _Flight(
    this.message,
    this.gift, {
    required this.at,
    required this.total,
    required this.running,
    required this.flown,
  });

  final LiveMessage message;
  final LiveGift gift;
  final DateTime at;
  final int total;
  final int? running;
  final int flown;
}

/// An ended combo remembered for [GiftFlights.summaryWindow].
final class _Ended {
  const _Ended({required this.at, required this.total});

  final DateTime at;
  final int total;
}
