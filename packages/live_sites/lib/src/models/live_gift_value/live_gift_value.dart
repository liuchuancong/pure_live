// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/common/gift/gift_value.dart';
import 'package:live_sites/src/models/live_gift_tier/live_gift_tier.dart';
import 'package:live_sites/src/models/live_gift_unit/live_gift_unit.dart';
import 'package:meta/meta.dart';

/// What a gift is worth: the currency it is priced in, the unit price and the
/// total of this message, and whether the platform marks it free.
@immutable
final class LiveGiftValue {
  /// Creates the value of a gift.
  const LiveGiftValue({this.unit = LiveGiftUnit.other, this.unitPrice, this.totalValue, this.free = false});

  /// The unit of [unitPrice] and [totalValue].
  final LiveGiftUnit unit;

  /// The price of one, in [unit]; null when unknown.
  final int? unitPrice;

  /// What this message's gifts are worth together, in [unit]; null when unknown.
  final int? totalValue;

  /// The platform marks it free (Bilibili silver gifts, Baidu's 拍拍, KilaKila's
  /// 克拉之星, a niconico gift of no points).
  final bool free;

  /// [giftTierOf] this value.
  LiveGiftTier get tier => giftTierOf(unit, totalValue, free: free);

  @override
  String toString() => 'LiveGiftValue($unit, unit: $unitPrice, total: $totalValue, free: $free)';
}
