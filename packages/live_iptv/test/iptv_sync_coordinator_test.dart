import 'dart:async';
import 'dart:convert';

import 'package:live_iptv/src/import/iptv_importer.dart';
import 'package:live_iptv/src/library/library.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/sync/sync.dart';
import 'package:test/test.dart';

const playlistUrl = 'http://list.example/tv.m3u8';
const guideUrl = 'http://guide.example/epg.xml';

/// The M3U the fake server hands out.
const String tvList = '''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1",CCTV-1
http://a/1.m3u8
''';

/// One XMLTV document covering the moment [at] is inside.
String guideFor(DateTime at) {
  final start = at.subtract(const Duration(minutes: 20));
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="cctv1"><display-name>CCTV 1 综合</display-name></channel>
  <programme channel="cctv1" start="${_xmltv(start)}" stop="${_xmltv(start.add(const Duration(hours: 3)))}">
    <title>此刻的节目</title>
  </programme>
</tv>
''';
}

String _xmltv(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}${two(utc.hour)}${two(utc.minute)}${two(utc.second)} +0000';
}

/// A scripted pair of fetchers: playlists as text, guides as bytes, each
/// counting how often it was asked.
final class _FakeSource {
  new({required this.guide});

  final String guide;
  int playlistCalls = 0;
  int guideCalls = 0;
  Completer<void>? hold;

  IptvFetcher get fetch => (url, {headers = const {}}) async {
    playlistCalls++;
    await hold?.future;
    return tvList;
  };

  IptvBytesFetcher get fetchBytes => (url, {headers = const {}}) async {
    guideCalls++;
    return utf8.encode(guide);
  };
}

void main() {
  late IptvLibrary library;
  late IptvImporter importer;
  late IptvSyncCoordinator coordinator;
  late _FakeSource source;

  /// The instant the seeded records were imported at.
  late DateTime then;

  /// A library holding one remote playlist and one remote guide, both
  /// imported at [then] — the dates are written into the store before the
  /// library reads it, so "stale" is decided by the `now` the round is given
  /// rather than by waiting for anything.
  Future<void> seed(DateTime at) async {
    then = at;
    final store = InMemoryIptvStore();
    await store.saveChannels([
      IptvChannel.of(
        id: 'c1',
        entry: IptvEntry.of(name: 'CCTV-1', url: 'http://a/1.m3u8', tvgId: 'cctv1'),
      ),
    ]);
    await store.savePlaylists([
      IptvPlaylist.of(id: 'p1', name: '电视家', importedAt: then, url: playlistUrl, channelCount: 1),
    ]);
    await store.saveGuideSources([
      EpgSource.of(id: 'epg-1', name: '中央台', source: guideUrl, lastRefresh: then, createdAt: then),
    ]);
    library = IptvLibrary(store);
    await library.load();
    source = _FakeSource(guide: guideFor(at));
    importer = IptvImporter(library: library, fetch: source.fetch, fetchBytes: source.fetchBytes);
    coordinator = IptvSyncCoordinator(importer: importer);
  }

  tearDown(() => library.dispose());

  group('due lists', () {
    test('a playlist inside its interval is not due', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(hours: 2)));
      const policy = IptvSyncPolicy(playlistInterval: Duration(hours: 24), guideInterval: Duration(hours: 6));

      expect(coordinator.duePlaylists(policy, now: now), isEmpty);
    });

    test('a stale playlist is due, and a guide inside its own longer interval is not', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 2)));
      const policy = IptvSyncPolicy(playlistInterval: Duration(hours: 24), guideInterval: Duration(days: 3));

      expect(coordinator.duePlaylists(policy, now: now).map((playlist) => playlist.name), ['电视家']);
      expect(coordinator.dueGuides(policy, now: now), isEmpty);
    });

    test('a switched-off kind reports nothing due without looking at dates', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 9)));
      const policy = IptvSyncPolicy(
        playlistInterval: Duration(hours: 1),
        guideInterval: Duration(hours: 1),
        playlists: false,
      );

      expect(coordinator.duePlaylists(policy, now: now), isEmpty);
      expect(coordinator.dueGuides(policy, now: now).length, 1);
    });

    test('a guide whose automatic refresh is off is never due', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 9)));
      await library.updateGuideSource(library.guideSources.single.rebuild((b) => b..autoUpdate = false));
      const policy = IptvSyncPolicy(playlistInterval: Duration(hours: 1), guideInterval: Duration(hours: 1));

      expect(coordinator.dueGuides(policy, now: now), isEmpty);
    });

    test('a playlist imported from a file is never due', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 9)));
      final stored = library.playlists.single;
      await library.importFromText(tvList, name: '本地');

      // The remote one is still due; the local import added a playlist with no
      // address to re-read, and offering to sync that can only fail.
      expect(
        coordinator.duePlaylists(
          const IptvSyncPolicy(playlistInterval: Duration(hours: 1), guideInterval: Duration(hours: 1)),
          now: now,
        ),
        [stored],
      );
    });
  });

  group('syncDue', () {
    const policy = IptvSyncPolicy(playlistInterval: Duration(hours: 24), guideInterval: Duration(hours: 6));

    test('refreshes what is stale and says so', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 2)));

      final report = await coordinator.syncDue(policy, now: now);

      expect(report.refreshed, 2);
      expect(report.failures, 0);
      expect(report.didAnything, isTrue);
      expect(source.playlistCalls, 1);
      expect(source.guideCalls, 1);
    });

    test('a guide that landed re-runs the matcher, so channels get programmes', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 2)));
      final channel = library.channels.single;
      expect(library.mappingFor(channel.id), isNull);

      final report = await coordinator.syncDue(policy, now: now);

      expect(report.mappingsWritten, greaterThan(0));
      expect(library.guideKeyFor(channel), isNotNull);
      // The guide the fake server served covers `then`, so that is the instant
      // the slot is read at; the round's own clock is not the fixture's.
      expect(library.programmeSlot(channel, now: then.add(const Duration(minutes: 30))).current?.title, '此刻的节目');
    });

    test('a round in flight is joined, not duplicated', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 2)));
      source.hold = Completer<void>();

      final first = coordinator.syncDue(policy, now: now);
      final second = coordinator.syncDue(policy, now: now);
      source.hold!.complete();
      await first;

      expect(second, same(first));
      // Two triggers, one download: the second call must not have asked again.
      expect(source.playlistCalls, 1);
      expect(coordinator.isRunning, isFalse);
    });

    test('nothing is due means nothing is downloaded', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(minutes: 5)));

      final report = await coordinator.syncDue(policy, now: now);

      expect(source.playlistCalls, 0);
      expect(report.didAnything, isFalse);
      expect(report.playlists, isEmpty);
    });

    test('an idle policy does not reach the network at all', () async {
      final now = DateTime.utc(2026, 10, 12, 12);
      await seed(now.subtract(const Duration(days: 30)));

      final report = await coordinator.syncDue(const IptvSyncPolicy.manual(), now: now);

      expect(source.playlistCalls, 0);
      expect(report.didAnything, isFalse);
      expect(report.elapsed, Duration.zero);
    });
  });
}
