// Module: test/plugin_store_state_test.dart
// Purpose: Prove an update keeps what the user set, and that a damaged file reads as absent, never as a crash.
// Author: liuchuancong
// Created: 2026-10-11
//
// state.json is the user's data (the enable flag, the import origin) and it sits next to files the installer
// writes. Two things were wrong before this round: an update rewrote state.json from scratch - so a data
// plugin lost its enabled flag and any plugin without a fresh originUrl lost the base its relative spider
// paths resolve against - and a state file that failed to parse dropped the plugin out of `list()` while its
// directory stayed on disk, unreachable from the page that would have removed it.

import 'dart:convert';
import 'dart:io';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_host/pure_live_plugin_host.dart';
import 'package:test/test.dart';

PluginManifest _manifest(String id, {String runtime = 'native', String version = '1.0.0'}) =>
    PluginManifest.fromJson(<String, Object?>{
      'id': id,
      'name': 'State test',
      'version': version,
      'apiVersion': 1,
      'runtime': runtime,
      'capabilities': <Object>['live'],
      'permissions': <Object>['network'],
    });

PluginBundle _bundle(String id, {String version = '1.0.0'}) => PluginBundle(
  manifest: _manifest(id, version: version),
  source: '// body of $id $version',
);

void main() {
  late Directory root;
  late PluginStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plugin_store_state');
    store = PluginStore(root: root, clock: () => DateTime.utc(2026, 10, 11, 4, 5));
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  String _statePath(String id) => '${root.path}/plugins/$id/state.json';

  group('test_pluginStore_state', () {
    test('test_install_anUpdateWithoutAnOriginKeepsTheOneAlreadyStored', () async {
      await store.install(_bundle('com.keep.origin'), originUrl: Uri.parse('https://host.example.com/list.m3u'));
      await store.setEnabled('com.keep.origin', true);
      await store.install(_bundle('com.keep.origin', version: '1.0.1'));

      final plugin = await store.find('com.keep.origin');
      expect(
        plugin?.originUrl?.toString(),
        'https://host.example.com/list.m3u',
        reason: 'relative paths inside the config resolve against it',
      );
      expect(plugin?.enabled, isTrue, reason: 'and the flag survives too');
      expect(plugin?.manifest.version, '1.0.1');
    });

    test('test_install_anExplicitOriginReplacesTheStoredOne', () async {
      await store.install(_bundle('com.swap'), originUrl: Uri.parse('https://old.example/a'));
      final updated = await store.install(_bundle('com.swap'), originUrl: Uri.parse('https://new.example/b'));

      expect(updated.originUrl.toString(), 'https://new.example/b');
      expect((await store.find('com.swap'))?.originUrl.toString(), 'https://new.example/b');
    });

    test('test_installData_anUpdateKeepsTheEnableFlagLikeCodePluginsDo', () async {
      await store.installData(
        manifest: _manifest('com.data.iptv', runtime: 'data'),
        content: '#EXTM3U\n',
      );
      await store.setEnabled('com.data.iptv', true);
      await store.installData(
        manifest: _manifest('com.data.iptv', runtime: 'data', version: '2.0.0'),
        content: '#EXTM3U\nx',
      );

      expect((await store.find('com.data.iptv'))?.enabled, isTrue);
      expect(await store.readContent('com.data.iptv'), '#EXTM3U\nx');
    });

    test('test_install_theInjectedClockStampsInstalledAt', () async {
      final installed = await store.install(_bundle('com.stamped'));

      expect(installed.installedAt, DateTime.utc(2026, 10, 11, 4, 5));
      expect((await store.find('com.stamped'))?.installedAt, DateTime.utc(2026, 10, 11, 4, 5));
    });

    test('test_setEnabled_leavesNoTemporaryFileAndRoundTripsTheFlag', () async {
      await store.install(_bundle('com.toggle'));
      await store.setEnabled('com.toggle', true);

      expect(File('${_statePath('com.toggle')}.tmp').existsSync(), isFalse);
      expect(jsonDecode(File(_statePath('com.toggle')).readAsStringSync()), containsPair('enabled', true));
      await store.setEnabled('com.toggle', false);
      expect((await store.find('com.toggle'))?.enabled, isFalse);
    });

    test('test_setEnabled_anUnknownIdIsRefused', () async {
      await expectLater(store.setEnabled('com.never.installed', true), throwsA(isA<PluginInstallException>()));
    });

    test('test_find_aCorruptStateFileReadsAsNotInstalledInsteadOfThrowing', () async {
      await store.install(_bundle('com.rotten'));
      File(_statePath('com.rotten')).writeAsStringSync('{"enabled": tru');

      expect(await store.find('com.rotten'), isNull);
      expect(await store.list(), isEmpty, reason: 'one damaged plugin must not take the list down');
      // Still removable: the directory is what the user asked to delete, damaged state or not.
      await store.uninstall('com.rotten');
      expect(Directory('${root.path}/plugins/com.rotten').existsSync(), isFalse);
    });

    test('test_find_aManifestOfTheWrongShapeIsNotInstalledEither', () async {
      await store.install(_bundle('com.wrong'));
      File('${root.path}/plugins/com.wrong/manifest.json')
          .writeAsStringSync(jsonEncode(<String, Object?>{'name': 'no id'}));

      expect(await store.find('com.wrong'), isNull);
      expect(await store.list(), isEmpty);
    });

    test('test_uninstall_takesTheStagingSiblingWithIt', () async {
      await store.install(_bundle('com.staged'));
      Directory('${root.path}/plugins/com.staged$kPluginStagingSuffix').createSync();

      await store.uninstall('com.staged');
      expect(
        Directory('${root.path}/plugins/com.staged$kPluginStagingSuffix').existsSync(),
        isFalse,
        reason: 'a copy of the code the user just deleted must not survive under another name',
      );
    });

    test('test_pruneStagingRemnants_deletesThemAndCountsThem', () async {
      await store.install(_bundle('com.one'));
      await store.install(_bundle('com.two'));
      Directory('${root.path}/plugins/com.one$kPluginStagingSuffix').createSync();
      Directory('${root.path}/plugins/com.two$kPluginStagingSuffix').createSync(recursive: true);

      expect(await store.pruneStagingRemnants(), 2);
      expect(await store.list(), hasLength(2), reason: 'the live plugins are untouched');
      expect(await store.pruneStagingRemnants(), 0);
    });

    test('test_find_aStateWithoutAnOriginOrFlagStillReads', () async {
      await store.install(_bundle('com.sparse'));
      File(_statePath('com.sparse'))
          .writeAsStringSync(jsonEncode(<String, Object?>{'installedAt': '2026-10-11T04:05:00Z'}));

      final plugin = await store.find('com.sparse');
      expect(plugin?.enabled, isFalse);
      expect(plugin?.originUrl, isNull);
      expect(plugin?.installedAt, DateTime.utc(2026, 10, 11, 4, 5));
    });

    test('test_find_aGarbageOriginIsAbsentNotAParsedGuess', () async {
      await store.install(_bundle('com.junk.origin'));
      File(_statePath('com.junk.origin')).writeAsStringSync(
        jsonEncode(<String, Object?>{'enabled': true, 'installedAt': '2026-10-11T04:05:00Z', 'originUrl': 'not a url'}),
      );

      expect((await store.find('com.junk.origin'))?.originUrl, isNull);
    });
  });
}
