// Module: test/plugin_store_paths_test.dart
// Purpose: Prove an id cannot address outside the plugin directory, and that a stored file is read with a limit.
// Author: liuchuancong
// Created: 2026-10-10
//
// The store's id sanitiser rejected slashes and spaces but allowed dots, so the id `..` survived to become
// `plugins/../` - and `uninstall` deletes recursively. These tests pin that by checking the parent directory
// survives, rather than by reading the sanitiser.

import 'dart:io';

import 'package:pure_live_plugin_host/pure_live_plugin_host.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory pluginsRoot;
  late PluginStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plugin_store_paths');
    pluginsRoot = Directory('${root.path}/plugins')..createSync(recursive: true);
    store = PluginStore(root: root);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  group('test_pluginStore_paths', () {
    test('test_pluginStore_uninstallWithParentId_doesNotTouchTheParentDirectory', () async {
      // The parent of plugins/ is the app's own data directory. Before the fix, this is what got deleted.
      File('${root.path}/keep-me.txt').writeAsStringSync('still here');
      Directory('${root.path}/other').createSync();

      await store.uninstall('..');

      expect(File('${root.path}/keep-me.txt').existsSync(), isTrue);
      expect(Directory('${root.path}/other').existsSync(), isTrue);
      expect(pluginsRoot.existsSync(), isTrue);
    });

    test('test_pluginStore_uninstallWithDotAndNestedIds_staysInsideTheRoot', () async {
      File('${root.path}/keep-me.txt').writeAsStringSync('still here');

      for (final id in <String>['.', '..', 'a/../../b', r'..\..\x', '....', 'normal.id']) {
        await store.uninstall(id);
      }

      expect(File('${root.path}/keep-me.txt').existsSync(), isTrue);
      expect(pluginsRoot.existsSync(), isTrue);
    });

    test('test_pluginStore_readSourceOnAMissingPlugin_isNamed', () async {
      // A missing file used to surface as FileNotFoundError, which a caller could only match by string.
      await expectLater(store.readSource('never-installed'), throwsA(isA<PluginInstallException>()));
    });

    test('test_pluginStore_readSource_honoursTheByteLimit', () async {
      final directory = Directory('${pluginsRoot.path}/big.plugin')..createSync(recursive: true);
      File('${directory.path}/plugin.js').writeAsStringSync('x' * 4096);

      expect(await store.readSource('big.plugin', maxBytes: 8192), hasLength(4096));

      await expectLater(
        store.readSource('big.plugin', maxBytes: 128),
        throwsA(
          isA<PluginTooLargeException>()
              .having((error) => error.id, 'id', 'big.plugin')
              .having((error) => error.actualBytes, 'actualBytes', 4096)
              .having((error) => error.limitBytes, 'limitBytes', 128),
        ),
      );
    });

    test('test_pluginStore_readContent_honoursTheByteLimit', () async {
      final directory = Directory('${pluginsRoot.path}/data.plugin')..createSync(recursive: true);
      File('${directory.path}/content.txt').writeAsStringSync('{"a":1}');

      expect(await store.readContent('data.plugin'), '{"a":1}');
      await expectLater(store.readContent('data.plugin', maxBytes: 3), throwsA(isA<PluginTooLargeException>()));
    });
  });
}
