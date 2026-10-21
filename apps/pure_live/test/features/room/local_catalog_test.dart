// The local catalogue, pinned: the gift ids are stable, unknown ids fall
// back rather than throwing, and the level arithmetic is the reference's
// 500-step ladder.
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/features/room/local/local_catalog.dart';

void main() {
  test('every gift id is unique and every gift grants experience', () {
    final ids = LocalCatalog.gifts.map((gift) => gift.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final gift in LocalCatalog.gifts) {
      expect(gift.exp, greaterThan(0), reason: gift.id);
      expect(gift.name, isNotEmpty);
      expect(gift.emoji, isNotEmpty);
    }
  });

  test('an unknown id falls back to the first gift', () {
    expect(LocalCatalog.giftOf('no-such-gift').id, LocalCatalog.gifts.first.id);
  });

  test('the level ladder is 500 experience a step, level 1 at zero', () {
    expect(LocalCatalog.levelFor(0), 1);
    expect(LocalCatalog.levelFor(499), 1);
    expect(LocalCatalog.levelFor(500), 2);
    expect(LocalCatalog.levelFor(1499), 3);
    expect(LocalCatalog.levelFor(-10), 1);
  });

  test('the into-level and missing figures add up', () {
    for (final exp in [0, 1, 499, 500, 1234]) {
      expect(LocalCatalog.intoLevel(exp) + LocalCatalog.missingToNext(exp), LocalCatalog.expPerLevel, reason: '$exp');
    }
  });

  test('the presets keep their ids and the unknown id falls back', () {
    final ids = LocalCatalog.presets.map((preset) => preset.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.first, 'clean');
    expect(LocalCatalog.presetOf('no-such-preset').id, 'clean');
  });

  test('a preset states a readable size and weight', () {
    for (final preset in LocalCatalog.presets) {
      expect(preset.fontSize, greaterThanOrEqualTo(14), reason: preset.id);
      expect(preset.fontWeight, inInclusiveRange(100, 900), reason: preset.id);
      expect(preset.strokeWidth, greaterThanOrEqualTo(0), reason: preset.id);
    }
  });
}
