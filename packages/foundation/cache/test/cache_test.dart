// Module: test/cache_test.dart
// Purpose: Verify ttl expiry, eviction order, quota enforcement and namespace isolation.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_cache/pure_live_cache.dart';
import 'package:pure_live_utils/pure_live_utils.dart';
import 'package:test/test.dart';

void main() {
  late FixedClock clock;

  CacheHub hubWith({
    CachePolicy? image,
    CachePolicy? media,
    CachePolicy fallback = const CachePolicy(),
  }) =>
      CacheHub(
        clock: clock,
        defaultPolicy: fallback,
        policies: <CacheNamespace, CachePolicy>{
          if (image != null) CacheNamespace.image: image,
          if (media != null) CacheNamespace.media: media,
        },
      );

  setUp(() => clock = FixedClock(DateTime.utc(2026, 10, 8, 12)));

  test('test_namespaceCache_withinTtl_returnsValue', () {
    final hub = hubWith(image: const CachePolicy(ttl: Duration(minutes: 5)));

    hub.of(CacheNamespace.image).write('a', 1);
    clock.advance(const Duration(minutes: 4));

    expect(hub.of(CacheNamespace.image).read('a'), 1);
  });

  test('test_namespaceCache_pastTtl_dropsEntryAndReturnsNull', () {
    final hub = hubWith(image: const CachePolicy(ttl: Duration(minutes: 5)));
    final cache = hub.of(CacheNamespace.image);
    cache.write('a', 1);

    clock.advance(const Duration(minutes: 5));

    expect(cache.read('a'), isNull);
    // The stale entry is removed on touch, so usage stops reporting it.
    expect(cache.length, 0);
  });

  test('test_namespaceCache_lru_evictsTheLeastRecentlyRead', () {
    final hub = hubWith(
      image: const CachePolicy(maxEntries: 2, eviction: CacheEviction.leastRecentlyUsed),
    );
    final cache = hub.of(CacheNamespace.image);

    cache.write('a', 1);
    clock.advance(const Duration(seconds: 1));
    cache.write('b', 2);
    clock.advance(const Duration(seconds: 1));
    cache.read('a'); // touching a makes b the older access
    clock.advance(const Duration(seconds: 1));
    final evicted = cache.write('c', 3);

    expect(evicted, <String>['b']);
    expect(cache.keys, <String>['a', 'c']);
  });

  test('test_namespaceCache_fifo_evictsTheOldestWritten', () {
    final hub = hubWith(
      image: const CachePolicy(maxEntries: 2, eviction: CacheEviction.firstInFirstOut),
    );
    final cache = hub.of(CacheNamespace.image);

    cache.write('a', 1);
    clock.advance(const Duration(seconds: 1));
    cache.write('b', 2);
    clock.advance(const Duration(seconds: 1));
    cache.read('a');
    clock.advance(const Duration(seconds: 1));
    cache.write('c', 3);

    // Reading a does not save it under FIFO: a is still the oldest write.
    expect(cache.keys, <String>['b', 'c']);
  });

  test('test_namespaceCache_byteQuota_evictsUntilUnderTheCeiling', () {
    final hub = hubWith(image: const CachePolicy(maxBytes: 100));
    final cache = hub.of(CacheNamespace.image);

    cache.write('a', 'x', bytes: 60);
    // Writing b pushes the total over the ceiling, so a is evicted by that write, not by a later one.
    expect(cache.write('b', 'y', bytes: 60), <String>['a']);
    expect(cache.write('c', 'z', bytes: 30), isEmpty);

    expect(cache.usage().bytes, lessThanOrEqualTo(100));
    expect(cache.keys, <String>['b', 'c']);
  });

  test('test_namespaceCache_negativeSize_isClampedToZero', () {
    final cache = hubWith().of(CacheNamespace.metadata);

    cache.write('a', 1, bytes: -50);

    expect(cache.usage().bytes, 0);
  });

  test('test_namespaceCache_rewritingAKey_replacesItsSize', () {
    final cache = hubWith().of(CacheNamespace.metadata);

    cache.write('a', 1, bytes: 10);
    cache.write('a', 2, bytes: 40);

    expect(cache.length, 1);
    expect(cache.usage().bytes, 40);
  });

  test('test_cacheHub_namespacesAreIsolated', () {
    final hub = hubWith();

    hub.of(CacheNamespace.image).write('shared-key', 'image-value');
    hub.of(CacheNamespace.media).write('shared-key', 'media-value');

    expect(hub.of(CacheNamespace.image).read('shared-key'), 'image-value');
    expect(hub.of(CacheNamespace.media).read('shared-key'), 'media-value');

    hub.of(CacheNamespace.image).clear();
    expect(hub.of(CacheNamespace.image).read('shared-key'), isNull);
    expect(hub.of(CacheNamespace.media).read('shared-key'), 'media-value');
  });

  test('test_cacheHub_usage_listsEveryNamespaceAndTotal', () {
    final hub = hubWith();
    hub.of(CacheNamespace.danmaku).write('room-1', 'x', bytes: 7);

    final usage = hub.usage();

    expect(usage, hasLength(CacheNamespace.values.length));
    expect(hub.totalBytes, 7);
    expect(
      usage.firstWhere((item) => item.namespace == CacheNamespace.danmaku).entries,
      1,
    );
  });

  test('test_cacheHub_policyFallsBackToTheDefault', () {
    const custom = CachePolicy(maxEntries: 3);
    final hub = hubWith(image: custom);

    expect(hub.policyFor(CacheNamespace.image).maxEntries, 3);
    expect(hub.policyFor(CacheNamespace.epg).maxEntries, const CachePolicy().maxEntries);
  });

  test('test_namespaceCache_remove_reportsWhetherTheKeyWasThere', () {
    final cache = hubWith().of(CacheNamespace.epg);
    cache.write('a', 1);

    expect(cache.remove('a'), isTrue);
    expect(cache.remove('a'), isFalse);
  });
}
