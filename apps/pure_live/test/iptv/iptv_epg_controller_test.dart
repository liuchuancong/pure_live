// The guide-source manager's offline half: a guide lands from bytes the
// test hands over (no wire), commits into the library, becomes the active
// guide on its own, and the delete answers when the source it was shown is
// already gone — the optimistic lock that keeps two windows honest.

import 'dart:convert' show utf8;
import 'dart:io' show Directory;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart' show InMemoryIptvStore, IptvImporter, IptvLibrary;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/logging/app_log.dart' show initAppLog;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvImporterProvider, iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart' show iptvEpgProvider;

const _playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1" tvg-name="CCTV-1",CCTV-1 高清
http://a/1.m3u8
''';

String _guideXml() {
  // Wall-clock times in the guide's own zone, anchored around now so the
  // importer's retention prune cannot eat the fixture.
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
  <channel id="cctv1">
    <display-name>CCTV-1</display-name>
  </channel>
  <programme channel="cctv1" start="${stamp(now.subtract(const Duration(minutes: 30)))}" stop="${stamp(now.add(const Duration(minutes: 30)))}">
    <title>新闻联播</title>
  </programme>
</tv>
''';
}

Future<(ProviderContainer, IptvLibrary)> _container() async {
  await StoragePrefs.initSeeded({});
  // The manager logs its post-import pass; an uninitialized log would make
  // that pass look failed and the active choice would never be stored.
  initAppLog(directory: await Directory.systemTemp.createTemp('pure-live-epg-test'));
  final library = IptvLibrary(InMemoryIptvStore());
  await library.load();
  await library.importFromText(_playlist, name: 'lists');
  final container = ProviderContainer(
    overrides: [
      iptvLibraryProvider.overrideWith((ref) => Future<IptvLibrary>.value(library)),
      iptvImporterProvider.overrideWith(
        (ref) => IptvImporter(
          library: library,
          fetch: (url, {headers = const {}}) => throw StateError('no network in this test: $url'),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  // The controller watches the library as an AsyncValue; the first read is
  // otherwise its loading frame, and the tests would assert against that.
  await container.read(iptvLibraryProvider.future);
  return (container, library);
}

void main() {
  test('a manager over a library without guides starts empty and unset', () async {
    final (container, _) = await _container();
    final state = container.read(iptvEpgProvider);
    expect(state.ready, isTrue);
    expect(state.sources, isEmpty);
    expect(state.activeId, isNull);
  });

  test('a guide handed over as bytes reads with its channel', () async {
    final (container, _) = await _container();
    final preview = await container
        .read(iptvEpgProvider.notifier)
        .previewBytes(utf8.encode(_guideXml()), source: 'guide.xml');
    expect(preview.isReadable, isTrue, reason: 'verdict: ${preview.failure}');
    expect(preview.channels, 1);
    expect(preview.matchable, greaterThan(0));
  });

  test('committing the preview names the source and makes it active', () async {
    final (container, _) = await _container();
    final notifier = container.read(iptvEpgProvider.notifier);
    final preview = await notifier.previewBytes(utf8.encode(_guideXml()), source: 'guide.xml');
    final result = await notifier.commitPreview(preview, name: '中央');
    expect(result.isImported, isTrue, reason: 'verdict: ${result.status.name}');

    final state = container.read(iptvEpgProvider);
    expect(state.sources.single.name, '中央');
    expect(state.channelCounts[state.sources.single.id], 1);
    // The mirror names the only source active right away; the stored choice
    // only exists once the viewer (or the delete fallback) chooses — a
    // restart re-derives the same first source.
    expect(state.activeId, state.sources.single.id);
  });

  test('committing under a taken name without replace is refused', () async {
    final (container, _) = await _container();
    final notifier = container.read(iptvEpgProvider.notifier);
    final preview = await notifier.previewBytes(utf8.encode(_guideXml()), source: 'guide.xml');
    await notifier.commitPreview(preview, name: '中央');
    final again = await notifier.commitPreview(preview, name: '中央');
    expect(again.isImported, isFalse);
    expect(container.read(iptvEpgProvider).sources.length, 1);
  });

  test('deleting the active guide falls back to the remaining source', () async {
    final (container, _) = await _container();
    final notifier = container.read(iptvEpgProvider.notifier);
    final first = await notifier.previewBytes(utf8.encode(_guideXml()), source: 'guide.xml');
    await notifier.commitPreview(first, name: '中央');
    final second = await notifier.previewBytes(utf8.encode(_guideXml()), source: 'other.xml');
    await notifier.commitPreview(second, name: '地方', replace: true);
    final state = container.read(iptvEpgProvider);
    expect(state.sources.length, 2);

    final active = state.sources.firstWhere((source) => source.id == state.activeId);
    expect(await notifier.deleteSource(active), isTrue);
    final after = container.read(iptvEpgProvider);
    expect(after.sources.length, 1);
    expect(after.activeId, after.sources.single.id);
  });

  test('deleting a source that is already gone refuses the second ask', () async {
    final (container, _) = await _container();
    final notifier = container.read(iptvEpgProvider.notifier);
    final preview = await notifier.previewBytes(utf8.encode(_guideXml()), source: 'guide.xml');
    await notifier.commitPreview(preview, name: '中央');
    final source = container.read(iptvEpgProvider).sources.single;
    expect(await notifier.deleteSource(source), isTrue);
    expect(await notifier.deleteSource(source), isFalse);
  });

  test('a chosen guide rides back out of the store', () async {
    final (container, _) = await _container();
    final notifier = container.read(iptvEpgProvider.notifier);
    final preview = await notifier.previewBytes(utf8.encode(_guideXml()), source: 'guide.xml');
    await notifier.commitPreview(preview, name: '中央');
    // The library's change event reaches the manager's mirror as a
    // microtask; let it land before asking the choice to stand down.
    await pumpEventQueue();
    final source = container.read(iptvEpgProvider).sources.single;
    await notifier.selectGuide(null);
    await pumpEventQueue();
    expect(container.read(iptvEpgProvider).activeId, isNull);
    // A cleared choice is stored as the empty string, read back as none.
    expect(StoragePrefs.getString('iptv.guide.active'), '');
    await notifier.selectGuide(source);
    expect(container.read(iptvEpgProvider).activeId, source.id);
    expect(StoragePrefs.getString('iptv.guide.active'), source.id);
  });
}
