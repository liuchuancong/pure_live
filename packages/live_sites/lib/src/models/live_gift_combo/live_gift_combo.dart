import 'dart:math' as math;

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';

// What makes a combo of a platform's gifts: the chat list's merging, the flying
// gifts and the recorded chat count a combo the same way, through these rules.

/// The character that separates the fields of a combo key, so a sender or gift
/// name containing the separator cannot forge another combo.
final String _fieldSeparator = String.fromCharCode(0);

/// What the gifts of one combo share: the platform's combo key, or the sender
/// (id and name) and the gift (its id, else its name) of that kind.
String giftComboKey(LiveMessage message, LiveGift gift) {
  if (gift.comboKey.isNotEmpty) return 'combo:${gift.comboKey}';
  final giftKey = gift.id.isNotEmpty ? gift.id : gift.name;
  // A gift to someone else is another combo (a streamer sends the same gift to
  // ten viewers in turn); no receiver keeps the plain key.
  final receiver = gift.receiverName.isEmpty ? '' : '$_fieldSeparator->${gift.receiverName}';
  return 'sender:${gift.kind.name}:${message.userId}$_fieldSeparator${message.userName}$_fieldSeparator$giftKey$receiver';
}

/// The count of a combo that showed [shown] once [gift] counts on it: the
/// platform's running count when it has one ([LiveGift.comboTotal]; Douyu's
/// `hits` counts gifts, Huya's `iItemGroup` sends, Bilibili's `COMBO_SEND` is the
/// whole combo so far), else the sum of the counts.
int giftComboTotal(int shown, LiveGift gift) {
  final running = gift.comboTotal;
  if (running == null) return shown + gift.count;
  // The message counts the whole combo (Bilibili's COMBO_SEND).
  if (running == gift.count) return math.max(shown, running);
  return math.max(running, shown + gift.count);
}

/// The count a combo starts with at [gift]: the platform's count so far when it
/// joined during a combo, else the message's.
int giftComboStart(LiveGift gift) => math.max(gift.comboTotal ?? 0, gift.count);

/// Whether a combo whose last gift said [running] (the platform's count) started
/// again at [gift]: its count went back.
bool giftComboRestarted(int? running, LiveGift gift) {
  final next = gift.comboTotal;
  return next != null && running != null && next <= running;
}

/// Whether [gift] is a platform's summary of a combo: a combo key and a running
/// count equal to its own count (Bilibili's `COMBO_SEND`, which comes about 5 s
/// after the combo's last send).
bool giftIsComboSummary(LiveGift gift) => gift.comboKey.isNotEmpty && gift.comboTotal == gift.count;

/// The value of [count] gifts like [gift], in its unit: its unit price times
/// [count], or its value scaled from its own count; null when it has neither.
int? giftValueOfCount(LiveGift gift, int count) {
  if (gift.unitPrice case final price?) return price * count;
  final value = gift.totalValue;
  return value == null ? null : (value * count / gift.count).round();
}
