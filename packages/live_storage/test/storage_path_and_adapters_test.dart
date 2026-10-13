import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// The two guards in front of `Hive.init`: a path that is not empty, and a
/// registrar set that is registered exactly once, in a known order.
void main() {
  group('StoragePathProvider', () {
    test('trims the resolved directory before handing it on', () async {
      final provider = StoragePathProvider(resolver: () async => '  D:/data/hive  ');

      expect(await provider.getStoragePath(), 'D:/data/hive');
    });

    test('refuses an empty path rather than letting Hive write to the working directory', () async {
      final provider = StoragePathProvider(resolver: () async => '   ');

      // The failure is deliberately loud: an empty string would make Hive create
      // its boxes beside whatever directory the process happened to start in, and
      // the user's library would appear to be lost rather than misplaced.
      await expectLater(provider.getStoragePath(), throwsStateError);
    });
  });

  group('StorageAdapterRegistry', () {
    test('runs registrars in insertion order', () {
      final order = <String>[];
      StorageAdapterRegistry()
        ..add('library', () => order.add('library'))
        ..add('playback', () => order.add('playback'))
        ..add('danmaku', () => order.add('danmaku'))
        ..registerAll();

      expect(order, ['library', 'playback', 'danmaku']);
    });

    test('registers each registrar once however often initialize is called', () {
      var calls = 0;
      final registry = StorageAdapterRegistry()..add('iptv', () => calls++);

      for (var attempt = 0; attempt < 3; attempt++) {
        registry.registerAll();
      }

      expect(calls, 1, reason: 'Hive rejects a second adapter for the same type id');
      expect(registry.isRegistered, isTrue);
    });

    test('rejects a second registrar for the same feature', () {
      final registry = StorageAdapterRegistry()..add('library', () {});

      expect(() => registry.add('library', () {}), throwsStateError);
    });

    test('rejects a blank feature name', () {
      final registry = StorageAdapterRegistry();

      expect(() => registry.add('   ', () {}), throwsArgumentError);
    });

    test('refuses to add a registrar after registration has happened', () {
      final registry = StorageAdapterRegistry()
        ..add('library', () {})
        ..registerAll();

      expect(() => registry.add('danmaku', () {}), throwsStateError);
    });

    test('a failing registrar leaves the registry unregistered and the error visible', () {
      var laterRan = false;
      final registry = StorageAdapterRegistry()
        ..add('broken', () => throw StateError('adapter missing'))
        ..add('fine', () => laterRan = true);

      expect(registry.registerAll, throwsStateError);
      expect(registry.isRegistered, isFalse);
      // Documented behaviour: the earlier registrar already ran and is not rolled
      // back, and anything after it never got the chance.
      expect(laterRan, isFalse);
    });

    test('a retried registration after a failure completes the remaining registrars', () {
      var fineRan = 0;
      var brokenFails = true;
      final registry = StorageAdapterRegistry()
        ..add('broken', () {
          if (brokenFails) {
            throw StateError('adapter missing');
          }
        })
        ..add('fine', () => fineRan++);

      expect(registry.registerAll, throwsStateError);
      brokenFails = false;
      registry.registerAll();

      expect(registry.isRegistered, isTrue);
      expect(fineRan, 1, reason: 'the first attempt never reached it, the second must');
    });
  });
}
