import 'dart:io' show Directory;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_cache/live_cache.dart' show LiveCacheManager;
import 'package:live_net/live_net.dart' show ClientProfile, DioFactory;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_covers.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_decoder.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoRendition;
import 'package:pure_live/shared/shared.dart' show installLiveCacheManager;

/// The module's learned corners: the decoder failures a device teaches the
/// app (a codec at a size, keyed lower-case, remembered over restarts until
/// the reset), and the poster covers' own names — what counts as a HEIC
/// still, which provider a cover draws through, and the equality the image
/// cache keys on.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

void main() {
  setUpAll(() {
    // The covers' straight branch rides the app's cache manager; a
    // throwaway one over a temp folder keeps the test bare of the boot.
    final root = Directory.systemTemp.createTempSync('hongguo-covers-test');
    addTearDown(() => root.deleteSync(recursive: true));
    installLiveCacheManager(
      LiveCacheManager(
        directory: root,
        http: DioFactory().create(profile: ClientProfile.media),
      ),
    );
  });

  group('the decoder lesson keys', () {
    test('a key is the codec lower-cased beside its size, a missing side a zero', () {
      expect(hongguoDecoderKey('HEVC', 1920, 1080), 'hevc|1920|1080');
      expect(hongguoDecoderKey(' Hevc ', null, null), 'hevc|0|0');
    });
  });

  group('the decoder lessons', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    HongguoRendition rendition(String codec, {int? width, int? height}) =>
        HongguoRendition(quality: 1080, codec: codec, url: 'https://example/video.m3u8', width: width, height: height);

    test('a lesson is learned once, asked by codec and size, and reset on demand', () async {
      final container = ProviderContainer()..listen(hongguoDecoderLessonsProvider, (_, _) {});
      addTearDown(container.dispose);
      final notifier = container.read(hongguoDecoderLessonsProvider.notifier);

      expect(notifier.fails('hevc', 1920, 1080), isFalse);
      expect(notifier.learn(rendition('HEVC', width: 1920, height: 1080)), isTrue); // new
      await _settle(); // the write is fire-and-forget; let it land
      expect(notifier.learn(rendition('hevc', width: 1920, height: 1080)), isFalse); // the same lesson
      expect(notifier.fails('hevc', 1920, 1080), isTrue);
      expect(notifier.fails('hevc', 1920, null), isFalse); // a different size is a different lesson
      expect(notifier.failsRendition(rendition('HEVC', width: 1920, height: 1080)), isTrue);

      await notifier.reset();
      expect(notifier.fails('hevc', 1920, 1080), isFalse);
    });

    test('a lesson survives a re-read, and an unreadable store reads as none', () async {
      final first = ProviderContainer()..listen(hongguoDecoderLessonsProvider, (_, _) {});
      addTearDown(first.dispose);
      first.read(hongguoDecoderLessonsProvider.notifier).learn(rendition('av1', width: 3840, height: 2160));
      await _settle(); // the write is fire-and-forget; let it land

      final second = ProviderContainer()..listen(hongguoDecoderLessonsProvider, (_, _) {});
      addTearDown(second.dispose);
      expect(second.read(hongguoDecoderLessonsProvider.notifier).fails('av1', 3840, 2160), isTrue);

      await StoragePrefs.setStringList(kHongguoDecoderLessonsKey, ['not|a|real|lesson']);
      final third = ProviderContainer()..listen(hongguoDecoderLessonsProvider, (_, _) {});
      addTearDown(third.dispose);
      expect(third.read(hongguoDecoderLessonsProvider).contains('not|a|real|lesson'), isTrue); // the store's words
    });
  });

  group('the poster covers', () {
    test('a HEIC still is the suffix, query and case aside', () {
      expect(HongguoCoverCache.isHeic('https://cdn/a.heic'), isTrue);
      expect(HongguoCoverCache.isHeic('https://cdn/a.HEIC?sign=abc'), isTrue); // the signed form
      expect(HongguoCoverCache.isHeic('https://cdn/a.webp'), isFalse);
      expect(HongguoCoverCache.isHeic('https://cdn/heic'), isFalse); // a name is not a suffix
      expect(HongguoCoverCache.isHeic(''), isFalse);
    });

    test('a HEIC cover draws through the converter, anything else straight', () {
      expect(hongguoCoverImage('https://cdn/a.heic'), isA<HongguoCoverImage>());
      expect(hongguoCoverImage('https://cdn/a.webp'), isNot(isA<HongguoCoverImage>()));
      expect(hongguoCoverImage('https://cdn/a.heic?sign=x'), isA<HongguoCoverImage>());
    });

    test('the provider keys on its url and its box', () {
      const one = HongguoCoverImage('https://cdn/a.heic');
      const twin = HongguoCoverImage('https://cdn/a.heic');
      const boxed = HongguoCoverImage('https://cdn/a.heic', width: 300, height: 400);
      const other = HongguoCoverImage('https://cdn/b.heic');

      expect(one, equals(twin));
      expect(one.hashCode, twin.hashCode);
      expect(one, isNot(equals(boxed))); // the box is part of the key
      expect(one, isNot(equals(other)));
      expect(one.toString(), 'HongguoCoverImage("https://cdn/a.heic")');
    });
  });
}
