import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/background/tone/analysis/background_analysis_cache.dart';
import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';

BackgroundAnalysisResult _result() => BackgroundAnalysisResult(
  source: BackgroundSampleSource.solid,
  dominant: const Color(0xFF000000),
  representative: const Color(0xFF000000),
  profile: backgroundProfileOf(const [0]),
  regions: const [],
);

void main() {
  group('cache key', () {
    test('carries the algorithm version and sample width', () {
      final key = backgroundAnalysisKey(identity: 'file:///wall.jpg', modifiedMs: 42);
      expect(key, contains('v$kBackgroundAnalysisVersion'));
      expect(key, contains('w$kBackgroundAnalysisSampleWidth'));
    });

    test('a modified file gets a different key', () {
      final first = backgroundAnalysisKey(identity: 'file:///wall.jpg', modifiedMs: 1);
      final second = backgroundAnalysisKey(identity: 'file:///wall.jpg', modifiedMs: 2);
      expect(first, isNot(second));
    });

    test('a network address has no mtime and is keyed by the address', () {
      final key = backgroundAnalysisKey(identity: 'https://example.com/wall.jpg');
      expect(key, contains('remote'));
      expect(key, contains('https://example.com/wall.jpg'));
    });
  });

  group('LRU', () {
    test('recently read entries survive eviction', () {
      final cache = BackgroundAnalysisCache(capacity: 2)
        ..put('a', _result())
        ..put('b', _result());
      expect(cache.get('a'), isNotNull);
      cache.put('c', _result());
      expect(cache.get('b'), isNull);
      expect(cache.get('a'), isNotNull);
      expect(cache.length, 2);
    });

    test('rewriting a key moves it to the front', () {
      final cache = BackgroundAnalysisCache(capacity: 2)
        ..put('a', _result())
        ..put('b', _result())
        ..put('a', _result())
        ..put('c', _result());
      expect(cache.get('a'), isNotNull);
      expect(cache.get('b'), isNull);
    });

    test('clear drops everything', () {
      final cache = BackgroundAnalysisCache(capacity: 2)
        ..put('a', _result())
        ..clear();
      expect(cache.length, 0);
      expect(cache.get('a'), isNull);
    });
  });
}
