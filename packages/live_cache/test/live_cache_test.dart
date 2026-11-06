import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_cache/live_cache.dart';
import 'package:live_net/live_net.dart';
import 'package:path/path.dart' as p;

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

final class _FakeImageHttp implements LiveHttp {
  new({Uint8List? body, this.delay = Duration.zero})
    : statusCode = 200,
      headers = const {'etag': '"v1"'},
      body = body ?? _png;

  Uint8List body;
  int statusCode;
  Map<String, String> headers;
  Duration delay;
  bool notModifiedWhenValidated = false;
  int requests = 0;
  Map<String, String> lastHeaders = const {};

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    requests++;
    lastHeaders = request.headers;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (notModifiedWhenValidated && request.headers.containsKey('if-none-match')) {
      return _FakeStreamedResponse(statusCode: 304, headers: headers, chunks: const []);
    }
    return _FakeStreamedResponse(
      statusCode: statusCode,
      headers: headers,
      chunks: statusCode >= 200 && statusCode < 300 ? [body] : const [],
    );
  }

  @override
  Future<LiveResponse> send(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

final class _FakeStreamedResponse implements LiveStreamedResponse {
  new({required this.statusCode, required this.headers, required this.chunks});

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  final List<Uint8List> chunks;

  @override
  Stream<Uint8List> get stream => Stream<Uint8List>.fromIterable(chunks);

  @override
  Future<void> close() async {}
}

LiveCacheManager _manager(
  Directory root,
  LiveHttp http, {
  ImageCacheConfig image = const ImageCacheConfig(autoClean: false, maxDiskBytes: 10 * 1024 * 1024),
}) => LiveCacheManager(
  directory: Directory(p.join(root.path, 'live_cache')),
  http: http,
  config: LiveCacheConfig(image: image),
);

ImageCacheRequest _request(
  String path, {
  ImageCachePolicy policy = ImageCachePolicies.general,
  String? cacheKey,
  String? version,
}) => ImageCacheRequest(
  url: Uri.parse('https://images.example.test/$path'),
  policy: policy,
  cacheKey: cacheKey,
  version: version,
);

Directory _newTempDir() => Directory.systemTemp.createTempSync('live_cache_test_');

Future<File?> _firstImage(Directory root) async {
  await for (final entity in Directory(p.join(root.path, 'live_cache', 'images')).list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.img')) {
      return entity;
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() {
    root = _newTempDir();
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  group('image disk cache', () {
    test('fetches once, then answers from disk', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      await manager.initialize();

      final first = await manager.image.resolve(_request('cover.png'));
      expect(first.source, CacheSource.network);
      expect(http.requests, 1);

      final second = await manager.image.resolve(_request('cover.png'));
      expect(second.source, CacheSource.disk);
      expect(second.isExpired, isFalse);
      expect(http.requests, 1);
      expect(manager.image.imageStatistics().diskSize, greaterThan(0));

      await manager.dispose();
    });

    test('an expired copy is served stale under stale-while-revalidate', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      final policy = ImageCachePolicies.general.copyWith(
        ttl: const Duration(milliseconds: 10),
        maxStale: const Duration(seconds: 5),
      );
      await manager.initialize();

      await manager.image.resolve(_request('cover.png', policy: policy));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final stale = await manager.image.resolve(_request('cover.png', policy: policy));
      expect(stale.source, CacheSource.disk);
      expect(stale.isStale, isTrue);
      expect(http.requests, 1);

      final fresh = await manager.image.refresh(_request('cover.png', policy: policy));
      expect(fresh, isNotNull);
      expect(fresh!.source, CacheSource.network);
      expect(http.requests, 2);

      await manager.dispose();
    });

    test('a 304 extends the copy instead of downloading it again', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      final policy = ImageCachePolicies.general.copyWith(ttl: const Duration(milliseconds: 10));
      await manager.initialize();

      await manager.image.resolve(_request('cover.png', policy: policy));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      http.notModifiedWhenValidated = true;

      final refreshed = await manager.image.refresh(_request('cover.png', policy: policy));
      expect(refreshed, isNull);
      expect(http.lastHeaders['if-none-match'], '"v1"');

      final again = await manager.image.resolve(_request('cover.png', policy: policy));
      expect(again.source, CacheSource.disk);
      expect(again.isExpired, isFalse);

      await manager.dispose();
    });

    test('refresh failure keeps the stale copy for refreshBeforeDisplay', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      final policy = ImageCachePolicies.preview.copyWith(ttl: const Duration(milliseconds: 10));
      await manager.initialize();

      await manager.image.resolve(_request('preview.png', policy: policy));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      http.statusCode = 500;

      final stale = await manager.image.resolve(_request('preview.png', policy: policy));
      expect(stale.source, CacheSource.disk);
      expect(stale.isStale, isTrue);
      expect(http.requests, 2);

      await manager.dispose();
    });

    test('cacheOnly never opens a connection', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      final policy = ImageCachePolicies.general.copyWith(mode: ImageExpiryMode.cacheOnly);
      await manager.initialize();

      await expectLater(
        manager.image.resolve(_request('missing.png', policy: policy)),
        throwsA(isA<CacheFailure>().having((failure) => failure.kind, 'kind', CacheFailureKind.notFound)),
      );
      expect(http.requests, 0);

      await manager.image.resolve(_request('cached.png'));
      final cached = await manager.image.resolve(_request('cached.png', policy: policy));
      expect(cached.source, CacheSource.disk);
      expect(http.requests, 1);

      await manager.dispose();
    });

    test('concurrent requests share one download', () async {
      final http = _FakeImageHttp(delay: const Duration(milliseconds: 40));
      final manager = _manager(root, http);
      await manager.initialize();

      final first = manager.image.resolve(_request('cover.png'));
      final second = manager.image.resolve(_request('cover.png'));
      expect(identical(first, second), isTrue);

      await Future.wait([first, second]);
      expect(http.requests, 1);

      await manager.dispose();
    });

    test('a different version writes a different file', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      await manager.initialize();

      await manager.image.resolve(_request('cover.png', version: 'v1'));
      await manager.image.resolve(_request('cover.png', version: 'v2'));
      await manager.image.flush();

      final files = Directory(p.join(root.path, 'live_cache', 'images'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.img'))
          .length;
      expect(files, 2);
      expect(manager.image.imageStatistics().fileCount, 2);

      await manager.dispose();
    });

    test('a stable business key absorbs a rotating signed URL', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      await manager.initialize();

      await manager.image.resolve(_request('cover.png?sign=one', cacheKey: 'room-42'));
      await manager.image.resolve(_request('cover.png?sign=two', cacheKey: 'room-42'));

      expect(http.requests, 1);
      await manager.dispose();
    });

    test('a corrupt file is dropped and fetched again', () async {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      await manager.initialize();

      await manager.image.resolve(_request('cover.png'));
      await manager.image.flush();
      final file = await _firstImage(root);
      expect(file, isNotNull);
      await file!.writeAsBytes(Uint8List.fromList(List<int>.filled(64, 0)));

      final again = await manager.image.resolve(_request('cover.png'));
      expect(again.source, CacheSource.network);
      expect(http.requests, 2);

      await manager.dispose();
    });

    test('a body over the per-image cap is refused', () async {
      final http = _FakeImageHttp(body: Uint8List.fromList([..._png, 0, 0, 0, 0]));
      final manager = _manager(root, http);
      final policy = ImageCachePolicies.general.copyWith(maxImageSize: _png.length);
      await manager.initialize();

      await expectLater(
        manager.image.resolve(_request('big.png', policy: policy)),
        throwsA(isA<CacheFailure>().having((failure) => failure.kind, 'kind', CacheFailureKind.tooLarge)),
      );

      await manager.dispose();
    });

    test('a non-image body is refused', () async {
      final http = _FakeImageHttp(body: Uint8List.fromList(utf8.encode('<html>error</html>')));
      final manager = _manager(root, http);
      await manager.initialize();

      await expectLater(
        manager.image.resolve(_request('error.png')),
        throwsA(isA<CacheFailure>().having((failure) => failure.kind, 'kind', CacheFailureKind.unsupportedFormat)),
      );

      await manager.dispose();
    });
  });

  group('index and cleanup', () {
    test('a lost index is rebuilt from the files', () async {
      final http = _FakeImageHttp();
      final first = _manager(root, http);
      await first.initialize();
      await first.image.resolve(_request('cover.png'));
      await first.image.flush();
      await first.dispose();

      final indexPath = p.join(root.path, 'live_cache', 'metadata', 'index.json');
      await File(indexPath).delete();

      final second = _manager(root, http);
      await second.initialize();
      final image = await second.image.resolve(_request('cover.png'));
      expect(image.source, CacheSource.disk);
      expect(http.requests, 1);

      await second.dispose();
    });

    test('partial writes are swept at startup', () async {
      final temporary = Directory(p.join(root.path, 'live_cache', 'temporary'))..createSync(recursive: true);
      final part = File(p.join(temporary.path, 'cover.img.123.part'))..writeAsBytesSync([1, 2, 3]);

      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      await manager.initialize();

      expect(part.existsSync(), isFalse);
      await manager.dispose();
    });

    test('clearAll never leaves the cache root', () async {
      final outside = File(p.join(root.path, 'recording_covers', 'frame.png'))..createSync(recursive: true);
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      await manager.initialize();
      await manager.image.resolve(_request('cover.png'));

      await manager.clearAll();
      expect(outside.existsSync(), isTrue);
      expect(await _firstImage(root), isNull);

      await manager.dispose();
    });

    test('the capacity sweep removes low priority first', () async {
      final http = _FakeImageHttp();
      final manager = _manager(
        root,
        http,
        image: const ImageCacheConfig(autoClean: false, maxDiskBytes: 100, cleanupTargetRatio: 1),
      );
      final low = ImageCachePolicies.general.copyWith(
        category: 'low_category',
        priority: CachePriority.low,
        ttl: const Duration(days: 1),
      );
      final high = ImageCachePolicies.general.copyWith(
        category: 'high_category',
        priority: CachePriority.high,
        ttl: const Duration(days: 1),
      );
      await manager.initialize();
      await manager.image.resolve(_request('low.png', policy: low));
      await manager.image.resolve(_request('high.png', policy: high));
      await manager.image.flush();

      final before = manager.image.imageStatistics();
      expect(before.diskSize, greaterThan(100));
      final result = await manager.image.enforceLimit();
      expect(result.removedFiles, 1);
      expect(manager.image.imageStatistics().categories.map((row) => row.category), contains('high_category'));
      expect(manager.image.imageStatistics().categories.map((row) => row.category), isNot(contains('low_category')));

      await manager.dispose();
    });

    test('hit rate is zero before anything is asked', () {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      expect(manager.statistics().image.hitRate, 0);
      expect(manager.statistics().apiMemory.hitRate, 0);
    });
  });

  group('API memory cache', () {
    test('TTL, LRU and capacity', () async {
      final cache =
          MemoryCache<String, String>(
              config: const MemoryCacheConfig(maxEntries: 2, maxBytes: 1000, defaultTtl: Duration(milliseconds: 20)),
            )
            ..set('a', 'one')
            ..set('b', 'two');
      expect(cache.get('a'), 'one');
      cache.set('c', 'three');
      expect(cache.containsKey('b'), isFalse);
      expect(cache.get('a'), 'one');
      expect(cache.get('c'), 'three');

      cache.set('short', 'lived', ttl: const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(cache.get('short'), isNull);
      expect(cache.statistics.hitCount, greaterThan(0));
      expect(cache.statistics.missCount, greaterThan(0));
      expect(cache.statistics.hitRate, inInclusiveRange(0, 1));
    });

    test('clearExpired and clear', () {
      final cache = MemoryCache<String, String>(config: const MemoryCacheConfig(defaultTtl: Duration(milliseconds: 1)))
        ..set('a', 'one');
      expect(cache.clearExpired(), 0);
      cache.clear();
      expect(cache.length, 0);
    });
  });

  group('image provider', () {
    test('the same request and decode box are one key', () {
      final http = _FakeImageHttp();
      final manager = _manager(root, http);
      final request = _request('cover.png');
      final first = LiveCacheImage(cache: manager.image, request: request);
      final second = LiveCacheImage(cache: manager.image, request: request);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(LiveCacheImage(cache: manager.image, request: request, width: 64)));
    });
  });
}
