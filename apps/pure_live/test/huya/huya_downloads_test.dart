// The huya download queue's offline half: what a session's restart does to
// rows left mid-flight, and the queue verbs that answer without the wire —
// the network half needs a live station and stays out of these.

import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, FileLock, FileMode, FileSystemException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:path/path.dart' as p;
import 'package:pure_live/modules/huya/controller/huya_downloads.dart';

HuyaDownloadItem _item(String id, HuyaDownloadPhase phase) => HuyaDownloadItem(
  videoId: id,
  title: '直播回放 $id',
  qualityId: 'source',
  fileName: '$id.mp4',
  filePath: 'C:\nowhere\$id.mp4',
  phase: phase,
  stamp: 1000,
);

Future<ProviderContainer> _container(List<HuyaDownloadItem> seed) async {
  await StoragePrefs.initSeeded({
    kHuyaDownloadsKey: jsonEncode([for (final item in seed) item.toJson()]),
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a session restart reads the stored rows and parks the running one', () async {
    final container = await _container([
      _item('done', HuyaDownloadPhase.done),
      _item('fly', HuyaDownloadPhase.running),
    ]);
    final items = container.read(huyaDownloadsProvider);
    expect(items.map((item) => item.videoId), ['done', 'fly']);
    // The bytes a previous session was writing stay on the disk; the row
    // waits for the viewer's own resume, mid-flight is never pretended.
    expect(items[1].phase, HuyaDownloadPhase.paused);
  });

  test('taskOf answers the row it keeps', () async {
    final container = await _container([_item('only', HuyaDownloadPhase.paused)]);
    final controller = container.read(huyaDownloadsProvider.notifier);
    expect(controller.taskOf('only')?.videoId, 'only');
    expect(controller.taskOf('absent'), isNull);
  });

  test('clearFinished drops the done rows and keeps the rest', () async {
    final container = await _container([
      _item('kept', HuyaDownloadPhase.paused),
      _item('spent', HuyaDownloadPhase.done),
    ]);
    await container.read(huyaDownloadsProvider.notifier).clearFinished();
    expect(container.read(huyaDownloadsProvider).map((item) => item.videoId), ['kept']);
    final stored = jsonDecode(StoragePrefs.getString(kHuyaDownloadsKey)!) as List<Object?>;
    expect((stored.single! as Map<String, Object?>)['videoId'], 'kept');
  });

  test('remove drops a parked row and its record', () async {
    final container = await _container([_item('gone', HuyaDownloadPhase.paused)]);
    await container.read(huyaDownloadsProvider.notifier).remove('gone');
    expect(container.read(huyaDownloadsProvider), isEmpty);
    expect(StoragePrefs.getString(kHuyaDownloadsKey), jsonEncode(<Object?>[]));
  });

  test('a failed file delete keeps the task record', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-huya-delete-');
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
    final blocked = _item('gone', HuyaDownloadPhase.done).toJson()..['filePath'] = file.path;
    final container = await _container([HuyaDownloadItem.fromJson(blocked)]);

    await expectLater(
      container.read(huyaDownloadsProvider.notifier).remove('gone', deleteFile: true),
      throwsA(isA<FileSystemException>()),
    );

    expect(container.read(huyaDownloadsProvider).single.videoId, 'gone');
  });

  test('a concurrent remove and clear cannot race the locked delete', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-huya-remove-race-');
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
    final blocked = _item('gone', HuyaDownloadPhase.done).toJson()..['filePath'] = file.path;
    final container = await _container([HuyaDownloadItem.fromJson(blocked)]);
    final controller = container.read(huyaDownloadsProvider.notifier);

    final first = controller.remove('gone', deleteFile: true);
    final second = controller.remove('gone', deleteFile: true);
    await controller.clearFinished();

    await expectLater(first, throwsA(isA<FileSystemException>()));
    await second;
    expect(container.read(huyaDownloadsProvider).single.videoId, 'gone');
  });

  test('pauseAll also parks tasks waiting for a lane', () async {
    final container = await _container([
      _item('queued', HuyaDownloadPhase.queued),
      _item('parked', HuyaDownloadPhase.paused),
    ]);
    await container.read(huyaDownloadsProvider.notifier).pauseAll();
    expect(container.read(huyaDownloadsProvider).map((item) => item.phase), everyElement(HuyaDownloadPhase.paused));
  });

  test('a store the reader cannot parse starts the queue empty', () async {
    await StoragePrefs.initSeeded({kHuyaDownloadsKey: 'not json at all'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(huyaDownloadsProvider), isEmpty);
  });
}
