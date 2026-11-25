import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileLock, FileMode, FileSystemException, HttpException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:path/path.dart' as p;
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
    final restored = HongguoDownloadItem.fromJson(item('7100001:1').toJson()..['phase'] = 'something-new');
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

  test('a failed file delete keeps the task record', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-hongguo-delete-');
    final file = File('${folder.path}/locked.mp4');
    await file.writeAsString('keep');
    final lock = await file.open(mode: FileMode.write);
    // The explicit mode documents the Windows delete fixture.
    // ignore: avoid_redundant_argument_values
    await lock.lock(FileLock.exclusive);
    addTearDown(() async {
      await lock.close();
      await folder.delete(recursive: true);
    });
    final blocked = item('7100001:1', phase: HongguoDownloadPhase.done, received: 100);
    await StoragePrefs.setString(kHongguoDownloadsKey, jsonEncode([blocked.toJson()..['filePath'] = file.path]));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(hongguoDownloadsProvider.notifier).remove(blocked.id, deleteFile: true),
      throwsA(isA<FileSystemException>()),
    );

    expect(container.read(hongguoDownloadsProvider).single.id, blocked.id);
  });

  test('a concurrent remove and clear cannot race the locked delete', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-hongguo-remove-race-');
    final file = File(p.join(folder.path, 'locked.mp4'));
    await file.writeAsString('keep');
    final lock = await file.open(mode: FileMode.write);
    // Windows needs an explicit mode for this locked-delete fixture.
    // ignore: avoid_redundant_argument_values
    await lock.lock(FileLock.exclusive);
    addTearDown(() async {
      await lock.close();
      await folder.delete(recursive: true);
    });
    final blocked = item('7100001:1', phase: HongguoDownloadPhase.done, received: 100);
    await StoragePrefs.setString(kHongguoDownloadsKey, jsonEncode([blocked.toJson()..['filePath'] = file.path]));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(hongguoDownloadsProvider.notifier);

    final first = controller.remove(blocked.id, deleteFile: true);
    final second = controller.remove(blocked.id, deleteFile: true);
    await controller.clearFinished();

    await expectLater(first, throwsA(isA<FileSystemException>()));
    await second;
    expect(container.read(hongguoDownloadsProvider).single.id, blocked.id);
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
    expect(hongguoDownloadFileName(title: '剧名', part: '第一话', parts: 12), '剧名 - EP1 第一话.mp4');
    expect(hongguoDownloadFileName(title: '单集', part: '正片'), '单集.mp4');
    // Windows' reserved characters never reach the file system.
    expect(hongguoDownloadFileName(title: '剧:名/上', part: '第一话', index: 2, parts: 12), '剧 名 上 - EP2 第一话.mp4');
  });

  test('a resume appends only when the response starts at the bytes already written', () {
    final resumed = hongguoDownloadTransfer(
      written: 40,
      statusCode: 206,
      contentRange: 'bytes 40-99/100',
      contentLength: 60,
    );
    expect(resumed, (offset: 40, total: 100, append: true));

    final restarted = hongguoDownloadTransfer(written: 40, statusCode: 200, contentRange: '', contentLength: 100);
    expect(restarted, (offset: 0, total: 100, append: false));
    expect(
      () => hongguoDownloadTransfer(written: 40, statusCode: 206, contentRange: 'bytes 0-99/100', contentLength: 100),
      throwsA(isA<HttpException>()),
    );
    expect(
      () => hongguoDownloadTransfer(written: 40, statusCode: 206, contentRange: '', contentLength: 60),
      throwsA(isA<HttpException>()),
    );
  });

  test('a paused part reserves its finished file name', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-hongguo-name-');
    addTearDown(() => folder.delete(recursive: true));
    await File(p.join(folder.path, '剧名 - EP1 第一话.mp4.part')).writeAsString('partial');

    final target = hongguoFreeDownloadFile(folder, '剧名 - EP1 第一话.mp4');

    expect(target.path, p.join(folder.path, '剧名 - EP1 第一话_2.mp4'));
  });

  test('the retry count defaults to off, follows its setting and rejects the extremes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hongguoDownloadRetryProvider), 0); // off, until asked
    container.read(hongguoDownloadRetryProvider.notifier).select(3);
    expect(container.read(hongguoDownloadRetryProvider), 3);
    container.read(hongguoDownloadRetryProvider.notifier).select(-1);
    expect(container.read(hongguoDownloadRetryProvider), 0); // clamped back to the floor
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(hongguoDownloadRetryProvider), 0); // the last honest choice is what was stored

    await StoragePrefs.setInt('hongguo.download.retryAttempts', 2);
    final third = ProviderContainer();
    addTearDown(third.dispose);
    expect(third.read(hongguoDownloadRetryProvider), 2);

    await StoragePrefs.setInt('hongguo.download.retryAttempts', 9);
    final fourth = ProviderContainer();
    addTearDown(fourth.dispose);
    expect(fourth.read(hongguoDownloadRetryProvider), 0); // a stranger to the choices is off
  });

  test('the retry wait picks from its list, refuses strangers and keeps its pick', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hongguoDownloadRetryDelayProvider), 10); // ten seconds, until asked
    container.read(hongguoDownloadRetryDelayProvider.notifier).select(60);
    expect(container.read(hongguoDownloadRetryDelayProvider), 60);
    container.read(hongguoDownloadRetryDelayProvider.notifier).select(7);
    expect(container.read(hongguoDownloadRetryDelayProvider), 60); // a stranger to the list changes nothing
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(hongguoDownloadRetryDelayProvider), 60);

    await StoragePrefs.setInt('hongguo.download.retryDelaySeconds', 30);
    final third = ProviderContainer();
    addTearDown(third.dispose);
    expect(third.read(hongguoDownloadRetryDelayProvider), 30);

    await StoragePrefs.setInt('hongguo.download.retryDelaySeconds', 45); // not one of the list's own
    final fourth = ProviderContainer();
    addTearDown(fourth.dispose);
    expect(fourth.read(hongguoDownloadRetryDelayProvider), 10);
  });

  test("a task's progress reads its share, or nothing when the size is unknown", () {
    expect(item('7100001:1', received: 40).progress, 0.4);
    expect(item('7100001:1', received: 200).progress, 1.0); // no more than the whole
    const unknown = HongguoDownloadItem(
      id: '7100001:9',
      seriesId: '7100001',
      title: '剧名',
      part: '第一话',
      index: 9,
      parts: 12,
      maxHeight: 1080,
      fileName: 'f.mp4',
      filePath: '/videos/f.mp4',
      phase: HongguoDownloadPhase.queued,
      stamp: 0,
    );
    expect(unknown.progress, isNull); // no size to read a share of
  });
}
