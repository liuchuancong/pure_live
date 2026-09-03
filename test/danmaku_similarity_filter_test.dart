import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_similarity_filter.dart';

void main() {
  group('DanmakuSimilarityFilter', () {
    test('rejects exact and fuzzy repeats while retaining new text', () {
      final filter = DanmakuSimilarityFilter(similarityThreshold: 80);

      expect(filter.shouldDisplay('hello world'), isTrue);
      expect(filter.shouldDisplay('hello world'), isFalse);
      expect(filter.shouldDisplay('hello wor1d'), isFalse);
      expect(filter.shouldDisplay('completely different'), isTrue);
    });

    test('expires old references using the configured window', () {
      var now = DateTime(2026, 1, 1);
      final filter = DanmakuSimilarityFilter(
        similarityThreshold: 100,
        cacheDuration: const Duration(seconds: 3),
        clock: () => now,
      );

      expect(filter.shouldDisplay('same text'), isTrue);
      now = now.add(const Duration(seconds: 2));
      expect(filter.shouldDisplay('same text'), isFalse);
      now = now.add(const Duration(seconds: 4));
      expect(filter.shouldDisplay('same text'), isTrue);
    });

    test('bounds retained cache and fuzzy comparisons independently', () {
      final filter = DanmakuSimilarityFilter(
        similarityThreshold: 100,
        maxCacheSize: 10,
        maxComparisons: 3,
      );

      for (final text in const [
        'ax0qz',
        'by1rw',
        'cz2sv',
        'du3tx',
        'ev4uy',
        'fw5vz',
        'gx6wa',
        'hy7xb',
        'iz8yc',
        'ja9zd',
        'kb0ae',
      ]) {
        expect(filter.shouldDisplay(text), isTrue);
        expect(filter.lastComparisonCount, lessThanOrEqualTo(3));
      }

      expect(filter.cacheSize, 10);
      expect(filter.maxComparisons, 3);
    });

    test('empty text is ignored and clear resets the cache', () {
      final filter = DanmakuSimilarityFilter();

      expect(filter.shouldDisplay('   '), isFalse);
      expect(filter.shouldDisplay('message'), isTrue);
      filter.clear();
      expect(filter.cacheSize, 0);
      expect(filter.shouldDisplay('message'), isTrue);
    });
  });
}
