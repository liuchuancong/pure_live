import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show VodQualityChoice;

void main() {
  setUpAll(() async {
    // The same memory-only storage the other provider tests use.
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDownAll(() async {
    // The queue persists under vod.downloads; clear it so another suite
    // reading this store starts empty.
    await StoragePrefs.setString(kVodDownloadsKey, '');
  });

  VodDownloadItem item(String id, {VodDownloadPhase phase = VodDownloadPhase.queued, int received = 0}) {
    return VodDownloadItem(
      id: id,
      bvid: 'BV1test',
      cid: 9001,
      title: '标题',
      part: '第一P',
      index: 1,
      parts: 1,
      qn: 64,
      fileName: '标题.mp4',
      filePath: '/videos/标题.mp4',
      phase: phase,
      stamp: 0,
      received: received,
      total: 100,
    );
  }

  test('a task survives a JSON round trip', () {
    final source = item('BV1test:9001', phase: VodDownloadPhase.paused, received: 40);
    final decoded = jsonDecode(jsonEncode([source.toJson()])) as List;
    final restored = VodDownloadItem.fromJson(decoded.first as Map<String, Object?>);
    expect(restored.id, source.id);
    expect(restored.phase, VodDownloadPhase.paused);
    expect(restored.received, 40);
    expect(restored.progress, 0.4);
  });

  test('a run the previous session left behind comes back paused', () async {
    await StoragePrefs.setString(
      kVodDownloadsKey,
      jsonEncode([
        item('BV1test:9001', phase: VodDownloadPhase.running, received: 30).toJson(),
        item('BV1test:9002', phase: VodDownloadPhase.done, received: 100).toJson(),
      ]),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final tasks = container.read(vodDownloadsProvider);
    expect(tasks, hasLength(2));
    expect(tasks.first.phase, VodDownloadPhase.paused);
    expect(tasks.first.received, 30);
    expect(tasks.last.phase, VodDownloadPhase.done);
  });

  test('clearFinished keeps the unfinished rows', () async {
    await StoragePrefs.setString(
      kVodDownloadsKey,
      jsonEncode([
        item('BV1test:9001', phase: VodDownloadPhase.paused).toJson(),
        item('BV1test:9002', phase: VodDownloadPhase.done, received: 100).toJson(),
      ]),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(vodDownloadsProvider.notifier).clearFinished();

    final tasks = container.read(vodDownloadsProvider);
    expect(tasks, hasLength(1));
    expect(tasks.single.phase, VodDownloadPhase.paused);
  });

  test('a cinema episode task survives a JSON round trip and is found by its ep key', () {
    const source = VodDownloadItem(
      id: 'ep456:9001',
      epId: 456,
      cid: 9001,
      title: '季节标题',
      part: '第一话',
      index: 1,
      parts: 12,
      qn: 80,
      fileName: '季节标题 - P1 第一话.mp4',
      filePath: '/videos/季节标题 - P1 第一话.mp4',
      phase: VodDownloadPhase.queued,
      stamp: 0,
    );
    final decoded = jsonDecode(jsonEncode([source.toJson()])) as List;
    final restored = VodDownloadItem.fromJson(decoded.first as Map<String, Object?>);
    expect(restored.epId, 456);
    expect(restored.id, 'ep456:9001');
    expect(vodDownloadOf([restored], 'ep456', 9001), same(restored));
    expect(vodDownloadOf([restored], 'BV1test', 9001), isNull);
  });

  test('the lane count defaults to three and follows its setting', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(vodDownloadSettingsProvider), 3);
    container.read(vodDownloadSettingsProvider.notifier).select(5);
    expect(container.read(vodDownloadSettingsProvider), 5);
    // The choice persists through an async write; let it land before a
    // fresh container reads the store back.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // A fresh container reads the stored choice, not the default.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(vodDownloadSettingsProvider), 5);
  });

  test('the download quality defaults to 1080P and follows its setting', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(vodDownloadQualityProvider), VodQualityChoice.p1080);
    container.read(vodDownloadQualityProvider.notifier).select(VodQualityChoice.p4k);
    expect(container.read(vodDownloadQualityProvider), VodQualityChoice.p4k);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(vodDownloadQualityProvider), VodQualityChoice.p4k);
  });

  test('the danmaku sidecar toggle defaults to on and follows its setting', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(vodDownloadDanmakuProvider), isTrue);
    container.read(vodDownloadDanmakuProvider.notifier).set(value: false);
    expect(container.read(vodDownloadDanmakuProvider), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(vodDownloadDanmakuProvider), isFalse);
  });

  test('vodDownloadOf finds a part by its bvid and cid', () {
    final tasks = [item('BV1test:9001', phase: VodDownloadPhase.running)];
    expect(vodDownloadOf(tasks, 'BV1test', 9001), same(tasks.single));
    expect(vodDownloadOf(tasks, 'BV1test', 1234), isNull);
  });
}
