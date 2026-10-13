// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_gift_unit/live_gift_unit.dart';
import 'package:meta/meta.dart';

/// What a paid message cost: the numeric price, the platform's own price text
/// when the number alone cannot say it, and the currency [unit] the number is in.
@immutable
final class LiveSuperChatPrice {
  /// Creates the price.
  const LiveSuperChatPrice({this.price = 0, this.priceText = '', this.unit = LiveGiftUnit.other});

  /// Price in [unit]; for a platform that only writes its price ([priceText] in
  /// the buyer's currency: YouTube) the number read from that text
  /// (`superChatAmount`), which only orders and compares.
  final int price;

  /// The price as the platform shows it (`$5.00`, `1,000 cheese`), when [price]
  /// alone cannot say it; empty otherwise.
  final String priceText;

  /// The unit of [price].
  final LiveGiftUnit unit;

  @override
  String toString() => 'LiveSuperChatPrice($price, $priceText, $unit)';
}
