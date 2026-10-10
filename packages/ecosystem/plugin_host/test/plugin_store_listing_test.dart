// Module: test/plugin_store_listing_test.dart
// Purpose: Prove the store lists only what it can name, and never installs one plugin over another's directory.
// Author: liuchuancong
// Created: 2026-10-10
//
// Two failure modes this pins. A crash between the last staging write and the rename leaves a *complete*
// `.staging` directory: reading it lists the same plugin twice, the second time under an id no manifest ever
// claimed, which then enables, stores state and uninstalls as that phantom. And because ids are sanitised
// before they become paths, two different ids can name the same directory - without a guard the later install
// silently replaces the earlier plugin while the manifest on disk still carries the other id.

import 'dart:convert';
import 'dart:io';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_host/pure_live_plugin_host.dart';
import 'package:test/test.dart';

PluginManifest _manifest(String id, {String version = '1.0.0'}) => PluginManifest.fromJson(<String, Object?>{
  'id': id,
  'name': 'Listing test',
  'version': version,
  'apiVersion': 1,
  'runtime': 'native',
  'capabilities': <Object>['live'],
  'permissions': <Object>['network'],
});

PluginBundle _bundle(String id, {String version = '1.0.0'}) => PluginBundle(
  manifest: _manifest(id, version: version),
  source: '// plugin body',
);

void main() {
  late Directory root;
  late Directory pluginsRoot;
  late PluginStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plugin_store_listing');
    pluginsRoot = Directory('${root.path}/plugins')..createSync(recursive: true);
    store = PluginStore(root: root);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  group('test_pluginStore_listing', () {
    test('test_list_ignoresAStagingRemnantFromACrashedInstall', () async {
      await store.install(_bundle('com.purelive.listing'));

      // The remnant is complete on purpose: manifest, script and state are all written before the rename, so
      // a directory that looks exactly like an installed plugin is what a crash leaves behind.
      final remnant = Directory('${pluginsRoot.path}/com.purelive.listing.staging')..createSync(recursive: true);
      File('${remnant.path}/manifest.json').writeAsStringSync(jsonEncode(_manifest('com.purelive.listing').toJson()));
      File('${remnant.path}/plugin.js').writeAsStringSync('// orphan body');
      File('${remnant.path}/state.json').writeAsStringSync(jsonEncode(<String, Object?>{'enabled': true}));

      final installed = await store.list();

      expect(installed.map((plugin) => plugin.id), <String>['com.purelive.listing']);
    });

    test('test_list_nextInstallOfTheSameIdClearsTheRemnantItLeft', () async {
      await store.install(_bundle('com.purelive.listing', version: '1.0.0'));
      final remnant = Directory('${pluginsRoot.path}/com.purelive.listing.staging')..createSync(recursive: true);
      File('${remnant.path}/manifest.json').writeAsStringSync(jsonEncode(_manifest('com.purelive.listing').toJson()));

      await store.install(_bundle('com.purelive.listing', version: '1.1.0'));

      expect(await remnant.exists(), isFalse, reason: 'the staging directory is recreated, not merged into');
      final installed = await store.list();
      expect(installed.single.manifest.version, '1.1.0');
    });

    test('test_install_twoIdsCollidingAfterSanitising_refusesTheSecond', () async {
      // Both ids pass the reverse-domain shape rule, and both sanitise to `com.purelive.a_b`: `$` is not in the
      // allowed path set, so it becomes `_`, which the second id already is.
      await store.install(_bundle('com.purelive.a\$b'));

      await expectLater(
        store.install(_bundle('com.purelive.a_b')),
        throwsA(
          isA<PluginInstallException>().having(
            (error) => error.message,
            'message',
            allOf(contains('com.purelive.a_b'), contains(r'com.purelive.a$b')),
          ),
        ),
      );

      // The refused install must not have touched what was already there.
      final installed = await store.list();
      expect(installed.map((plugin) => plugin.id), <String>[r'com.purelive.a$b']);
      expect(await store.readSource(r'com.purelive.a$b'), '// plugin body');
    });

    test('test_install_aDoubleDotIdCollidingWithAnUnderscoreId_isRefused', () async {
      // The other way the two rewrites bite: `com.a..b` collapses to `com.a_b`, the same directory an
      // underscore id gets.
      await store.install(_bundle('com.purelive.a..b'));

      await expectLater(store.install(_bundle('com.purelive.a_b')), throwsA(isA<PluginInstallException>()));
      expect((await store.list()).map((plugin) => plugin.id), <String>['com.purelive.a..b']);
    });

    test('test_install_sameIdAgain_isAnUpgradeAndKeepsTheEnableFlag', () async {
      await store.install(_bundle('com.purelive.listing', version: '1.0.0'));
      await store.setEnabled('com.purelive.listing', true);

      await store.install(_bundle('com.purelive.listing', version: '1.1.0'));

      final installed = await store.list();
      expect(installed.single.manifest.version, '1.1.0');
      expect(installed.single.enabled, isTrue, reason: 'an update must not silently turn a source off');
    });

    test('test_list_aDirectoryWithoutStateIsNotInstalled', () async {
      final directory = Directory('${pluginsRoot.path}/orphan.plugin')..createSync(recursive: true);
      File('${directory.path}/manifest.json').writeAsStringSync(jsonEncode(_manifest('orphan.plugin').toJson()));

      expect(await store.list(), isEmpty);
    });
  });
}
