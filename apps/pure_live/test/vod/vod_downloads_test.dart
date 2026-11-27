import 'dart:async' show Completer;
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show Directory, File, FileLock, FileMode, FileSystemException;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:path/path.dart' as p;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_download.dart' show freeDownloadFile;
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

  test('a failed file delete keeps the task record', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-vod-delete-');
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
    final blocked = item('BV1test:9001', phase: VodDownloadPhase.done, received: 100);
    await StoragePrefs.setString(kVodDownloadsKey, jsonEncode([blocked.toJson()..['filePath'] = file.path]));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(vodDownloadsProvider.notifier).remove(blocked.id, deleteFile: true),
      throwsA(isA<FileSystemException>()),
    );

    expect(container.read(vodDownloadsProvider).single.id, blocked.id);
  });

  test('a concurrent remove and clear cannot race the locked delete', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-vod-remove-race-');
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
    final blocked = item('BV1test:9001', phase: VodDownloadPhase.done, received: 100);
    await StoragePrefs.setString(kVodDownloadsKey, jsonEncode([blocked.toJson()..['filePath'] = file.path]));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(vodDownloadsProvider.notifier);

    final first = controller.remove(blocked.id, deleteFile: true);
    final second = controller.remove(blocked.id, deleteFile: true);
    await controller.clearFinished();

    await expectLater(first, throwsA(isA<FileSystemException>()));
    await second;
    expect(container.read(vodDownloadsProvider).single.id, blocked.id);
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

  test('pausing a running task persists the pause before its worker exits', () async {
    final queued = item('BV1test:9001');
    await StoragePrefs.setString(kVodDownloadsKey, jsonEncode([queued.toJson()]));
    final gate = Completer<String>();
    final answer = jsonEncode({
      'code': 0,
      'data': {
        'quality': 64,
        'durl': [
          {'url': 'https://cdn/video.mp4'},
        ],
      },
    });
    final stub = _DownloadHttp()
      ..handlers['/x/player/playurl'] = ((_) => answer)
      ..hold('/x/player/playurl', gate);
    final container = ProviderContainer(overrides: [vodClientProvider.overrideWithValue(BilibiliVodClient(stub))]);
    addTearDown(container.dispose);
    final controller = container.read(vodDownloadsProvider.notifier);
    await pumpEventQueue();
    expect(container.read(vodDownloadsProvider).single.phase, VodDownloadPhase.running);

    await controller.pause(queued.id);

    expect(container.read(vodDownloadsProvider).single.phase, VodDownloadPhase.paused);
    final stored = (jsonDecode(StoragePrefs.getString(kVodDownloadsKey)!) as List).single as Map<String, Object?>;
    expect(stored['phase'], 'paused');
    gate.complete(answer);
    await pumpEventQueue();
  });

  test('pause all cancels a failed task waiting to retry', () async {
    final failed = item('BV1test:9001', phase: VodDownloadPhase.failed);
    await StoragePrefs.setString(kVodDownloadsKey, jsonEncode([failed.toJson()]));
    final stub = _DownloadHttp()..handlers['/x/player/playurl'] = (_) => throw StateError('offline');
    final container = ProviderContainer(overrides: [vodClientProvider.overrideWithValue(BilibiliVodClient(stub))]);
    addTearDown(container.dispose);
    container.read(vodDownloadRetryProvider.notifier).select(1);
    final controller = container.read(vodDownloadsProvider.notifier);
    await controller.resume(failed.id);
    await pumpEventQueue();
    expect(controller.hasPendingRetry(failed.id), isTrue);

    await controller.pauseAll();

    expect(controller.hasPendingRetry(failed.id), isFalse);
    expect(container.read(vodDownloadsProvider).single.phase, VodDownloadPhase.failed);
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

  test('a paused part reserves its finished file name', () async {
    final folder = await Directory.systemTemp.createTemp('pure-live-vod-name-');
    addTearDown(() => folder.delete(recursive: true));
    await File(p.join(folder.path, '标题.mp4.part')).writeAsString('partial');

    final target = freeDownloadFile(folder, '标题.mp4');

    expect(target.path, p.join(folder.path, '标题_2.mp4'));
  });
}

final class _DownloadHttp implements LiveHttp {
  final Map<String, String Function(LiveRequest)> handlers = {};
  final List<LiveRequest> seen = [];
  final Map<String, Completer<String>> _gates = {};

  void hold(String path, Completer<String> gate) => _gates[path] = gate;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    seen.add(request);
    final answer = handlers[request.url.path]?.call(request);
    if (answer == null) throw StateError('no answer for ${request.url.path}');
    final body = answer;
    final gate = _gates[request.url.path];
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(gate == null ? body : await gate.future)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}
