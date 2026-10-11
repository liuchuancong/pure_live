import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory userRoot;
  late StorageManager storage;
  late PlatformFileStore store;

  setUp(() async {
    userRoot = await Directory.systemTemp.createTemp('live_storage_test_');
    addTearDown(() => userRoot.deleteSync(recursive: true));
    storage = DefaultStorageManager(
      policy: DefaultStoragePolicy(userRoot: userRoot),
      runtime: PlatformRuntimeInfo(
        kind: PlatformKind.unknown,
        formFactor: FormFactor.desktop,
        distribution: DesktopDistribution.unknown,
        isPackaged: false,
        executableRoot: userRoot,
      ),
    );
    store = PlatformFileStore(storage);
  });

  group('PlatformFileStore', () {
    test('write, read, exists, delete inside the area directory', () async {
      await store.writeText(StorageArea.config, 'sources.json', '{"feeds": 3}');
      expect(await store.exists(StorageArea.config, 'sources.json'), isTrue);
      expect(await store.readText(StorageArea.config, 'sources.json'), '{"feeds": 3}');

      final directory = await store.directoryFor(StorageArea.config);
      expect(
        File('${directory.path}/sources.json').readAsStringSync(),
        '{"feeds": 3}',
        reason: 'the file really landed in the area directory',
      );

      await store.delete(StorageArea.config, 'sources.json');
      expect(await store.exists(StorageArea.config, 'sources.json'), isFalse);
      expect(await store.readText(StorageArea.config, 'sources.json'), isNull);
    });

    test('binary round trip survives byte-for-byte', () async {
      final bytes = [0, 1, 2, 255, 254, 0x7F, 0x80];
      await store.writeBytes(StorageArea.extensions, 'blob.bin', bytes);

      expect(await store.readBytes(StorageArea.extensions, 'blob.bin'), bytes);
    });

    test('non-ASCII content round trips as UTF-8', () async {
      await store.writeText(StorageArea.config, '中文.txt', '内容：中文与 emoji 📺');
      expect(await store.readText(StorageArea.config, '中文.txt'), '内容：中文与 emoji 📺');
    });

    test('reading a missing file returns null instead of throwing', () async {
      expect(await store.readText(StorageArea.config, 'missing.txt'), isNull);
      expect(await store.readBytes(StorageArea.config, 'missing.txt'), isNull);
      expect(await store.exists(StorageArea.config, 'missing.txt'), isFalse);
    });

    test('delete of a missing file is a no-op', () async {
      await store.delete(StorageArea.config, 'never-existed.txt');
      expect(await store.exists(StorageArea.config, 'never-existed.txt'), isFalse);
    });

    test('traversal attempts are refused before touching the disk', () async {
      for (final name in ['..', '../escape.txt', r'sub\file.txt', 'sub/file.txt']) {
        await expectLater(store.writeText(StorageArea.config, name, 'x'), throwsA(isA<StorageValidationException>()));
        await expectLater(store.exists(StorageArea.config, name), throwsA(isA<StorageValidationException>()));
        await expectLater(store.delete(StorageArea.config, name), throwsA(isA<StorageValidationException>()));
      }
    });

    test('empty names are rejected', () async {
      await expectLater(store.writeText(StorageArea.config, '', 'x'), throwsA(isA<StorageValidationException>()));
    });
  });
}
