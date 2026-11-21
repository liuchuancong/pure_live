import 'dart:io' show Directory, File;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart' show DanmakuColor, DanmakuPlacement;
import 'package:pure_live/shared/danmaku/danmaku_entry.dart';
import 'package:pure_live/shared/danmaku/danmaku_files.dart';
import 'package:pure_live/shared/danmaku/danmaku_format.dart';
import 'package:pure_live/shared/danmaku/danmaku_save_formats.dart';

/// The danmaku files themselves: the sidecar naming rule (the video's own
/// name, one extension per format), the writer that sorts once and writes
/// many, the delete that takes every sidecar a video's name owns, and the
/// saved-formats choice that always leaves something on.
void main() {
  DanmakuEntry entry(double seconds, String text) => DanmakuEntry(
    time: Duration(milliseconds: (seconds * 1000).round()),
    text: text,
    color: const DanmakuColor(255, 0, 0),
    placement: DanmakuPlacement.top,
  );

  group('the sidecar files', () {
    late Directory root;
    late File video;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('danmaku-files-test');
      video = File('${root.path}/episode 1.mp4')..writeAsStringSync('video');
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    test('a sidecar is the video\'s own name with the format\'s extension', () {
      expect(danmakuFileFor(video, DanmakuFormat.xml).path, '${root.path}/episode 1.xml');
      expect(danmakuFileFor(video, DanmakuFormat.ass).path, '${root.path}/episode 1.ass');
      expect(danmakuFileFor(video, DanmakuFormat.json).path, '${root.path}/episode 1.json');
    });

    test('the writer sorts once, drops the blank lines and writes each format', () async {
      final written = await writeDanmakuFiles(
        video,
        [entry(30, '后一条'), entry(0, ''), entry(1.5, '先一条'), entry(2, '   ')],
        [DanmakuFormat.xml, DanmakuFormat.txt],
      );

      expect(written.map((file) => file.path), ['${root.path}/episode 1.xml', '${root.path}/episode 1.txt']);
      final text = File('${root.path}/episode 1.txt').readAsStringSync();
      expect(text.indexOf('先一条'), lessThan(text.indexOf('后一条'))); // timeline order, not ask order
      expect(text.contains('后一条'), isTrue);
      expect(video.readAsStringSync(), 'video'); // the video itself untouched
    });

    test('the delete takes every sidecar the video\'s name owns, and stays quiet when none are there', () async {
      await writeDanmakuFiles(video, [entry(1, '一条')], DanmakuFormat.values);
      File('${root.path}/episode 1.stray').writeAsStringSync('not a sidecar');

      await deleteDanmakuSidecars(video);

      expect(File('${root.path}/episode 1.xml').existsSync(), isFalse);
      expect(File('${root.path}/episode 1.ass').existsSync(), isFalse);
      expect(File('${root.path}/episode 1.txt').existsSync(), isFalse);
      expect(video.existsSync(), isTrue); // the video stays
      expect(File('${root.path}/episode 1.stray').existsSync(), isTrue); // a stranger's file stays

      await deleteDanmakuSidecars(video); // nothing left to take: no throw
    });
  });

  group('the saved formats', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    test('the format table answers its own names', () {
      expect(DanmakuFormat.byId('xml'), DanmakuFormat.xml);
      expect(DanmakuFormat.byId('bogus'), isNull);
      expect(DanmakuFormat.xml.readable, isTrue);
      expect(DanmakuFormat.ass.readable, isFalse); // for players, not for this app to parse
      expect(DanmakuFormat.srt.decode('1\n00:00:01,000 --> 00:00:05,000\n一条'), isEmpty);
    });

    test('the choice starts at xml, toggles freely and never empties', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(danmakuSaveFormatsProvider.notifier);
      container.listen(danmakuSaveFormatsProvider, (_, _) {});

      expect(container.read(danmakuSaveFormatsProvider), {DanmakuFormat.xml});

      await notifier.toggle(DanmakuFormat.ass);
      expect(container.read(danmakuSaveFormatsProvider), {DanmakuFormat.xml, DanmakuFormat.ass});

      await notifier.toggle(DanmakuFormat.xml); // xml can leave while ass stays
      expect(container.read(danmakuSaveFormatsProvider), {DanmakuFormat.ass});

      await notifier.toggle(DanmakuFormat.ass); // the last one off: xml returns
      expect(container.read(danmakuSaveFormatsProvider), {DanmakuFormat.xml});
    });

    test('a whole choice lands, survives a re-read and refuses to be empty', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      final notifier = first.read(danmakuSaveFormatsProvider.notifier);
      first.listen(danmakuSaveFormatsProvider, (_, _) {});

      await notifier.setAll({DanmakuFormat.ass, DanmakuFormat.srt});
      expect(first.read(danmakuSaveFormatsProvider), {DanmakuFormat.ass, DanmakuFormat.srt});
      await pumpEventQueue(); // the write is fire-and-forget; let it land

      await notifier.setAll({});
      expect(first.read(danmakuSaveFormatsProvider), {DanmakuFormat.xml}); // an empty ask is the default

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(danmakuSaveFormatsProvider), {DanmakuFormat.ass, DanmakuFormat.srt}); // the store's answer
    });

    test('a stored list the format table cannot read falls back, name by name', () async {
      await StoragePrefs.setString(kDanmakuSaveFormatsKey, 'ass,bogus');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(danmakuSaveFormatsProvider), {DanmakuFormat.ass}); // the unknown id skipped

      await StoragePrefs.setString(kDanmakuSaveFormatsKey, 'not-a-format');
      final fallback = ProviderContainer();
      addTearDown(fallback.dispose);
      expect(fallback.read(danmakuSaveFormatsProvider), {DanmakuFormat.xml}); // nothing readable: the default
    });
  });
}
