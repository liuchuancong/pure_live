import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/gift_value.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The gift line's numbers: the combo's running count, what it is worth, the
/// tier the chat list filters by and the words the line writes.

LiveGift _gift({
  int count = 1,
  int? comboTotal,
  double? unitPrice,
  double? totalValue,
  LiveGiftUnit unit = LiveGiftUnit.goldSeed,
}) => LiveGift(
  giftId: 'g',
  name: 'Gift',
  count: count,
  value: LiveGiftValue(unit: unit, unitPrice: unitPrice, totalValue: totalValue),
  combo: LiveGiftCombo(comboTotal: comboTotal),
);

Future<String?> _text(WidgetTester tester, LiveGift gift, {required bool inYuan}) async {
  String? text;
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            text = giftValueText(context, gift, inYuan: inYuan);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return text;
}

void main() {
  test('the shown count is the combo total when it is larger', () {
    expect(giftShownCount(_gift(comboTotal: 50)), 50);
    expect(giftShownCount(_gift(count: 3)), 3);
  });

  test('a combo is worth its unit price times the shown count', () {
    expect(giftShownValue(_gift(comboTotal: 50, unitPrice: 1000)), 50000);
    expect(giftShownValue(_gift(count: 2, totalValue: 2000)), 2000);
  });

  test('a free or unvalued gift has no value', () {
    expect(giftShownValue(_gift(unit: LiveGiftUnit.free, totalValue: 100)), isNull);
    expect(giftShownValue(_gift(unit: LiveGiftUnit.silver, totalValue: 100)), isNull);
    expect(giftShownValue(_gift()), isNull);
  });

  test('the tier follows the yuan thresholds', () {
    expect(giftShownTierOf(_gift(totalValue: 1000)), LiveGiftTier.normal); // 1 yuan
    expect(giftShownTierOf(_gift(totalValue: 10000)), LiveGiftTier.valuable); // 10 yuan
    expect(giftShownTierOf(_gift(totalValue: 100000)), LiveGiftTier.precious); // 100 yuan
    expect(giftShownTierOf(_gift(unit: LiveGiftUnit.silver, totalValue: 10000000)), LiveGiftTier.normal);
  });

  test('only valuable gifts pass the filter when it is on', () {
    final cheap = _gift(totalValue: 1000);
    final rich = _gift(totalValue: 10000);
    expect(giftLineVisible(cheap, valuableOnly: false), isTrue);
    expect(giftLineVisible(cheap, valuableOnly: true), isFalse);
    expect(giftLineVisible(rich, valuableOnly: true), isTrue);
    expect(giftLineVisible(null, valuableOnly: true), isFalse);
    expect(giftLineVisible(null, valuableOnly: false), isTrue);
  });

  testWidgets('the value is written in the platform unit or in yuan', (tester) async {
    final seeds = _gift(totalValue: 1000);
    expect(await _text(tester, seeds, inYuan: false), '1000 金瓜子');
    expect(await _text(tester, seeds, inYuan: true), '1 元');

    final fen = _gift(unit: LiveGiftUnit.fen, totalValue: 250);
    expect(await _text(tester, fen, inYuan: false), '2.5 元');

    final bits = _gift(unit: LiveGiftUnit.bits, totalValue: 140);
    expect(await _text(tester, bits, inYuan: false), '140 Bits');
    expect(await _text(tester, _gift(unit: LiveGiftUnit.silver, totalValue: 100), inYuan: false), isNull);
  });
}
