import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_downloads.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show HongguoQualityChoice;

void main() {
  setUpAll(() async {
    // The same memory-only storage the other provider tests use.
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDownAll(() async {
    // The queue persists under hongguo.downloads; clear it so another suite
    // reading this store starts empty.
    await StoragePrefs.setString(kHongguoDownloadsKey, '');
  });

  HongguoDownloadItem item(String id, {HongguoDownloadPhase phase = HongguoDownloadPhase.queued, int received = 0}) {
    return HongguoDownloadItem(
      id: id,
      seriesId: '7100001',
      title: '剧名',
      part: '第一话',
      index: 1,
      parts: 12,
      maxHeight: 1080,
      fileName: '剧名 - EP1 第一话.mp4',
      filePath: '/videos/剧名 - EP1 第一话.mp4',
      phase: phase,
      stamp: 0,
      received: received,
      total: 100,
    );
  }

  test('a task survives a JSON round trip', () {
    final source = item('7100001:1', phase: HongguoDownloadPhase.paused, received: 40);
    final decoded = jsonDecode(jsonEncode([source.toJson()])) as List;
    final restored = HongguoDownloadItem.fromJson(decoded.first as Map<String, Object?>);
    expect(restored.id, source.id);
    expect(restored.phase, HongguoDownloadPhase.paused);
    expect(restored.received, 40);
    expect(restored.total, 100);
    expect(restored.progress, 0.4);
    expect(restored.error, isNull);
  });

  test('a phase name the app does not know reads as paused', () {
    final restored = HongguoDownloadItem.fromJson(
      item('7100001:1').toJson()
        ..['phase'] = 'something-new',
    );
    expect(restored.phase, HongguoDownloadPhase.paused);
  });

  test('a run the previous session left behind comes back paused', () async {
    await StoragePrefs.setString(
      kHongguoDownloadsKey,
      jsonEncode([
        item('7100001:1', phase: HongguoDownloadPhase.running, received: 30).toJson(),
        item('7100001:2', phase: HongguoDownloadPhase.done, received: 100).toJson(),
      ]),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final tasks = container.read(hongguoDownloadsProvider);
    expect(tasks, hasLength(2));
    expect(tasks.first.phase, HongguoDownloadPhase.paused);
    expect(tasks.first.received, 30);
    expect(tasks.last.phase, HongguoDownloadPhase.done);
  });

  test('clearFinished keeps the unfinished rows', () async {
    await StoragePrefs.setString(
      kHongguoDownloadsKey,
      jsonEncode([
        item('7100001:1', phase: HongguoDownloadPhase.paused).toJson(),
        item('7100001:2', phase: HongguoDownloadPhase.done, received: 100).toJson(),
      ]),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(hongguoDownloadsProvider.notifier).clearFinished();

    final tasks = container.read(hongguoDownloadsProvider);
    expect(tasks, hasLength(1));
    expect(tasks.single.phase, HongguoDownloadPhase.paused);
  });

  test('hongguoDownloadOf finds an episode by its vid', () {
    final tasks = [item('7100001:1', phase: HongguoDownloadPhase.running)];
    expect(hongguoDownloadOf(tasks, '7100001:1'), same(tasks.single));
    expect(hongguoDownloadOf(tasks, '7100001:2'), isNull);
  });

  test('the lane count defaults to three and follows its setting', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hongguoDownloadSettingsProvider), 3);
    container.read(hongguoDownloadSettingsProvider.notifier).select(5);
    expect(container.read(hongguoDownloadSettingsProvider), 5);
    // The choice persists through an async write; let it land before a
    // fresh container reads the store back.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // A fresh container reads the stored choice, not the default.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(hongguoDownloadSettingsProvider), 5);
  });

  test('the download quality defaults to best and follows its setting', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hongguoDownloadQualityProvider), HongguoQualityChoice.best);
    container.read(hongguoDownloadQualityProvider.notifier).select(HongguoQualityChoice.p720);
    expect(container.read(hongguoDownloadQualityProvider), HongguoQualityChoice.p720);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(hongguoDownloadQualityProvider), HongguoQualityChoice.p720);
  });

  test('the file name names the episode in a series and sanitizes itself', () {
    expect(
      hongguoDownloadFileName(title: '剧名', part: '第一话', parts: 12),
      '剧名 - EP1 第一话.mp4',
    );
    expect(hongguoDownloadFileName(title: '单集', part: '正片'), '单集.mp4');
    // Windows' reserved characters never reach the file system.
    expect(
      hongguoDownloadFileName(title: '剧:名/上', part: '第一话', index: 2, parts: 12),
      '剧 名 上 - EP2 第一话.mp4',
    );
  });
}
