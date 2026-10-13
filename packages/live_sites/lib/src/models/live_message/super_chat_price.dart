import 'package:live_sites/src/models/live_gift/live_gift_unit.dart';

/// The words of a super chat's price: the platform's [priceText] when it gives
/// one; else [price] in [unit] as [unitText] writes it, or the bare number when
/// it has no words for [unit]; empty without a price.
String superChatPriceLabel(
  int price,
  LiveGiftUnit unit,
  String priceText, {
  String? Function(LiveGiftUnit unit, int price)? unitText,
}) {
  final text = priceText.trim();
  if (text.isNotEmpty) return text;
  if (price <= 0) return '';
  return unitText?.call(unit, price) ?? '$price';
}

/// The whole amount in a price the platform only writes (YouTube's
/// `purchaseAmountText`: `$5.00`, `VND1,000,000`, `2,50 EUR`), for ordering and
/// comparing; 0 when it has no number. The first run of digits and separators
/// counts: a last `.` or `,` followed by one or two digits starts the decimals,
/// which are dropped; every other separator groups thousands.
int superChatAmount(String priceText) {
  final match = _amountRun.firstMatch(priceText);
  if (match == null) return 0;
  var digits = match.group(0)!.replaceAll(_spacePattern, '');
  final decimals = RegExp(r'[.,]\d{1,2}$').firstMatch(digits);
  if (decimals != null) digits = digits.substring(0, decimals.start);
  return int.tryParse(digits.replaceAll(RegExp('[.,]'), '')) ?? 0;
}

// Dart's RegExp follows ECMAScript, where `\s` also covers the no-break (U+00A0)
// and narrow no-break (U+202F) spaces platforms write inside an amount, so `\s`
// keeps those separators handled without exotic literals.
final RegExp _amountRun = RegExp(r"\d(?:[\d.,'\s]|\s(?=\d))*");
final RegExp _spacePattern = RegExp(r'\s');
