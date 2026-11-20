import 'dart:convert' show jsonEncode, utf8;
import 'dart:io' show Directory;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/logging/app_log.dart' show initAppLog;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvImporterProvider, iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_import_flow.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_now_playing.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_recent.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_user_agent.dart';

/// The module's small state holders and the import flow's side doors: the
/// recent history's front moves and its hundred seats, the user-agent
/// override and the header merge where the playlist line wins, the on-air
/// mark that yields only to its own channel, and the flow's kind switches,
/// refusals, file previews, guide commits and the attached guide.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  group('the recent history', () {
    test('records move to the front, dedup, and land in the store', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(iptvRecentProvider, (_, _) {});
      final controller = container.read(iptvRecentProvider.notifier);

      await controller.record('a');
      await controller.record('b');
      await controller.record('a'); // the replay pulls it back to the front
      expect(container.read(iptvRecentProvider).map((entry) => entry.channelId), ['a', 'b']);

      await pumpEventQueue();
      final stored = jsonEncode([
        for (final entry in container.read(iptvRecentProvider))
          {'id': entry.channelId, 'at': entry.watchedAt.millisecondsSinceEpoch},
      ]);
      expect(StoragePrefs.getString(kIptvRecentKey), stored); // the store mirrors the list

      await controller.remove('b');
      expect(container.read(iptvRecentProvider).map((entry) => entry.channelId), ['a']);
      await controller.clear();
      expect(container.read(iptvRecentProvider), isEmpty);
      await pumpEventQueue();
      expect(StoragePrefs.getString(kIptvRecentKey), '[]');
    });

    test('the history keeps a hundred seats, no more', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(iptvRecentProvider, (_, _) {});
      final controller = container.read(iptvRecentProvider.notifier);

      for (var i = 0; i < kIptvRecentLimit + 2; i++) {
        await controller.record('c$i');
      }
      final recent = container.read(iptvRecentProvider);
      expect(recent, hasLength(kIptvRecentLimit)); // the oldest two fell off
      expect(recent.first.channelId, 'c${kIptvRecentLimit + 1}'); // the newest rides first
      expect(recent.any((entry) => entry.channelId == 'c0'), isFalse);
    });

    test('a corrupted store reads empty, and bad rows drop on the read', () async {
      await StoragePrefs.setString(
        kIptvRecentKey,
        '[{"id":"a","at":1700000000000},{"id":"","at":1},{"at":2},{"id":"b"},"junk"]',
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(iptvRecentProvider, (_, _) {});
      expect(container.read(iptvRecentProvider).map((entry) => entry.channelId), ['a']); // only the whole row

      await StoragePrefs.setString(kIptvRecentKey, 'not json at all');
      final broken = ProviderContainer();
      addTearDown(broken.dispose);
      broken.listen(iptvRecentProvider, (_, _) {});
      expect(broken.read(iptvRecentProvider), isEmpty); // unreadable is empty, not a crash
    });
  });

  group('the user-agent override', () {
    test('set persists trimmed, whitespace clears the key, and a restart reads it back', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(iptvUserAgentProvider, (_, _) {});
      final controller = container.read(iptvUserAgentProvider.notifier);

      await controller.set('  MyAgent/1.0  ');
      expect(container.read(iptvUserAgentProvider), 'MyAgent/1.0');
      await pumpEventQueue();
      expect(StoragePrefs.getString(kIptvUserAgentKey), 'MyAgent/1.0');

      // Whitespace alone clears the override: the key goes away entirely.
      await controller.set('   ');
      expect(container.read(iptvUserAgentProvider), '');
      await pumpEventQueue();
      expect(StoragePrefs.getString(kIptvUserAgentKey), isNull);

      // A fresh start reads what the last session stored.
      await controller.set('Back/2');
      await pumpEventQueue();
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      restarted.listen(iptvUserAgentProvider, (_, _) {});
      expect(restarted.read(iptvUserAgentProvider), 'Back/2');
    });

    test('the header merge adds the override unless the line carries one', () async {
      expect(normalizedIptvUserAgent('  '), isNull); // empty is the app default
      expect(iptvHeadersWithUserAgent(const {'accept': '*/*'}, ''), const {'accept': '*/*'});
      expect(iptvHeadersWithUserAgent(const {}, 'A/1'), const {'user-agent': 'A/1'});
      // The playlist line's own header wins, however it spelt the name.
      final line = iptvHeadersWithUserAgent(const {'User-Agent': 'line/9'}, 'A/1');
      expect(line['User-Agent'], 'line/9');
      expect(line, hasLength(1));
    });
  });

  group('the on-air mark', () {
    test('clearIf yields only to its own channel, never to a newer one', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(iptvNowPlayingProvider, (_, _) {});
      final controller = container.read(iptvNowPlayingProvider.notifier);

      expect(container.read(iptvNowPlayingProvider), isNull);
      controller.set('a');
      expect(container.read(iptvNowPlayingProvider), 'a');

      // Another channel took the air; the leaving player must not clear it.
      controller
        ..set('b')
        ..clearIf('a');
      expect(container.read(iptvNowPlayingProvider), 'b');

      controller.clearIf('b');
      expect(container.read(iptvNowPlayingProvider), isNull);
      controller.clear();
      expect(container.read(iptvNowPlayingProvider), isNull);
    });
  });

  group('the import flow corners', () {
    /// The text each address answers; a missing address throws.
    final answers = <String, String>{};

    /// Every address the importer was asked for.
    final asks = <String>[];
    late ProviderContainer container;

    setUp(() async {
      answers.clear();
      asks.clear();
      // The epg pass logs its verdicts; an uninitialized log would read as a
      // failure and the attached guide would never land.
      initAppLog(directory: await Directory.systemTemp.createTemp('pure-live-flow-test'));
      container = ProviderContainer(
        overrides: [
          iptvImporterProvider.overrideWith((ref) {
            final library = ref.watch(iptvLibraryProvider).value;
            if (library == null) return null;
            return IptvImporter(
              library: library,
              fetch: (url, {headers = const {}}) async {
                asks.add('$url');
                final text = answers[url.toString()];
                if (text == null) throw StateError('no answer for $url');
                return text;
              },
              fetchBytes: (url, {headers = const {}}) async {
                asks.add('$url');
                final text = answers[url.toString()];
                if (text == null) throw StateError('no bytes answer for $url');
                return utf8.encode(text);
              },
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(iptvImportFlowProvider, (_, _) {}); // the attach rides unawaited
    });

    /// Bounded wait for the fire-and-forget attach chain.
    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 200 && !ready(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    /// A guide around now, for [channel]; the retention prune must not eat it.
    String guideXml({String channel = 'cctv1'}) {
      String stamp(DateTime utc) {
        final wall = utc.add(const Duration(hours: 8));
        String two(int value) => value.toString().padLeft(2, '0');
        return '${wall.year.toString().padLeft(4, '0')}${two(wall.month)}${two(wall.day)}'
            '${two(wall.hour)}${two(wall.minute)}${two(wall.second)} +0800';
      }

      final now = DateTime.now().toUtc();
      return '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="$channel">
    <display-name>$channel</display-name>
  </channel>
  <programme channel="$channel" start="${stamp(now.subtract(const Duration(minutes: 30)))}" stop="${stamp(now.add(const Duration(minutes: 30)))}">
    <title>节目</title>
  </programme>
</tv>
''';
    }

    const plain =
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="cctv1" group-title="G1",CCTV-1\n'
        'http://stream/1\n';

    const declared =
        '#EXTM3U x-tvg-url="http://epg.example/g.xml"\n'
        '#PLAYLIST:AttList\n'
        '#EXTINF:-1 tvg-id="cctv1" group-title="G1",CCTV-1\n'
        'http://stream/1\n';

    IptvImportFlow flow() => container.read(iptvImportFlowProvider.notifier);
    IptvImportFlowState state() => container.read(iptvImportFlowProvider);
    IptvLibrary library() => container.read(iptvLibraryProvider).value!;

    test('the kind switch resets to the source and steers the guide off text origins', () {
      flow().setOrigin(IptvImportOrigin.text);
      flow().setName('My');
      flow().setKind(IptvImportKind.guide);

      final current = state();
      expect(current.kind, IptvImportKind.guide);
      expect(current.origin, IptvImportOrigin.link); // text is not a guide origin
      expect(current.step, IptvImportStep.source);
      expect(current.name, 'My'); // the typed name survives the switch
      expect(current.playlist, isNull);

      // The file origin serves both kinds and stays.
      flow().setOrigin(IptvImportOrigin.file);
      expect(state().origin, IptvImportOrigin.file);
      flow().setKind(IptvImportKind.playlist);
      expect(state().origin, IptvImportOrigin.file);
      expect(state().name, 'My');

      // An Xtream account is a playlist-only origin too.
      flow().setOrigin(IptvImportOrigin.xtream);
      flow().setKind(IptvImportKind.guide);
      expect(state().origin, IptvImportOrigin.link);
    });

    test('a link preview refuses anything but http(s) addresses, and a good one answers', () async {
      answers['http://tv/list.m3u'] = plain;

      await flow().previewLink('ftp://x/y');
      expect(state().step, IptvImportStep.source); // the scheme is refused before any ask
      await flow().previewLink('http://');
      expect(state().step, IptvImportStep.source);
      await flow().previewLink('not a url');
      expect(state().step, IptvImportStep.source);
      expect(asks, isEmpty); // nothing was asked

      await flow().previewLink('http://tv/list.m3u');
      final current = state();
      expect(current.step, IptvImportStep.preview);
      expect(current.playlist, isNotNull);
      expect(current.name, 'tv'); // no self-name in the text, so the host speaks
    });

    test('a file preview names itself after the file, and the guide file lands readable', () async {
      await flow().previewFile(utf8.encode(plain), fileName: 'my list.m3u', path: '/tmp/my list.m3u');
      var current = state();
      expect(current.step, IptvImportStep.preview);
      expect(current.name, 'my list'); // no self-name in the text, so the file speaks
      expect(current.playlist, isNotNull);

      flow().setKind(IptvImportKind.guide);
      flow().setName('');
      await flow().previewFile(utf8.encode(guideXml()), fileName: 'guide.xml', path: '/g/guide.xml');
      current = state();
      expect(current.step, IptvImportStep.preview);
      expect(current.guide, isNotNull);
      expect(current.guide?.isReadable, isTrue);
      expect(current.name, 'guide');
    });

    test('a guide commit replaces its own source, but parks on a stranger name', () async {
      flow().setKind(IptvImportKind.guide);

      await flow().previewFile(utf8.encode(guideXml()), fileName: 'guide.xml', path: '/g/a.xml');
      await flow().commit();
      expect(state().step, IptvImportStep.done);
      expect(library().guideSources, hasLength(1));

      // The same name from another file is not a sync: the write is refused
      // and the flow parks on the preview until the viewer decides.
      await flow().previewFile(
        utf8.encode(guideXml(channel: 'cctv2')),
        fileName: 'other.xml',
        path: '/g/b.xml',
      );
      expect(state().name, 'guide'); // the name rides from the last preview
      await flow().commit();
      expect(state().step, IptvImportStep.preview);
      expect(state().result?.isImported, isFalse);
      expect(library().guideSources, hasLength(1)); // nothing was written
    });

    test('committing a playlist that declares its guide attaches the guide', () async {
      answers['http://tv/att.m3u'] = declared;
      answers['http://epg.example/g.xml'] = guideXml();

      await flow().previewLink('http://tv/att.m3u');
      final current = state();
      expect(current.attachGuide, isTrue); // the header declared a guide and none is stored
      expect(current.guideCandidate, 'http://epg.example/g.xml');
      expect(current.name, 'AttList'); // the playlist's own name

      flow().setName('Att');
      await flow().commit();
      expect(state().step, IptvImportStep.done);
      expect(state().result?.isImported, isTrue);

      await until(() => state().guideResult != null);
      expect(state().guideResult?.isImported, isTrue); // the declared guide landed with it
      expect(library().guideSources, hasLength(1));
      expect(library().guideSources.single.name, contains('Att')); // named after the playlist as stored
    });
  });
}
