import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/recorder/record_chat_writer.dart';
import 'package:pure_live/features/recorder/record_storage_cleaner.dart';
import 'package:pure_live/features/recorder/recorder_preferences.dart';

/// A site that answers only the danmaku capability, backed by a session the
/// test feeds.
class _FakeSite implements LiveSite {
  new(this._provider);

  final LiveDanmakuProvider? _provider;

  @override
  LiveSiteManifest get manifest => const LiveSiteManifest(id: 'fake', name: {'zh': '假平台'}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() {
    final provider = _provider;
    if (provider == null) {
      return null;
    }
    return provider is T ? provider as T : null;
  }

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}

class _FakeProvider implements LiveDanmakuProvider {
  new(this.session);

  final LiveDanmakuSession? session;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final session = this.session;
    if (session == null) {
      return const Left(LiveSiteError.notFound(siteId: 'fake', message: 'no session'));
    }
    return Right(session);
  }
}

class _FakeSession implements LiveDanmakuSession {
  final StreamController<LiveMessage> controller = StreamController<LiveMessage>.broadcast();
  bool connected = false;
  bool disposed = false;

  @override
  Stream<LiveMessage> get events => controller.stream;

  @override
  Future<void> connect() async => connected = true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  group('RecorderPreferences', () {
    test('the shipped defaults are the reference\u2019s', () {
      final p = RecorderPreferences();
      expect(p.maxTaskCount, 3);
      expect(p.autoReconnect, isTrue);
      expect(p.maxRetryCount, 5);
      expect(p.retryDelaySeconds, 30);
      expect(p.enablePolling, isFalse);
      expect(p.liveCheckInterval, 30);
      expect(p.enableBackoff, isFalse);
      expect(p.maxCheckInterval, 300);
      expect(p.autoStartOnBoot, isFalse);
      expect(p.preferBestStream, isTrue);
      expect(p.rwTimeout, 15);
      expect(p.threadQueueSize, 2048);
      expect(p.defaultQuality, '原画');
      expect(p.pinyinFolders, isFalse);
      expect(p.recordDanmaku, isFalse);
      expect(p.recordDanmakuGifts, isFalse);
      expect(p.enableCacheLimit, isFalse);
      expect(p.maxCacheMB, 1024);
    });

    test('out-of-range values are normalized on construction', () {
      final p = RecorderPreferences(
        segmentMinutes: 900,
        maxTaskCount: 0,
        maxRetryCount: 99,
        retryDelaySeconds: 1,
        liveCheckInterval: 1000,
        maxCheckInterval: 10,
        rwTimeout: 45,
        threadQueueSize: 700,
        defaultQuality: ' nonsense',
        maxCacheMB: 0,
      );
      expect(p.segmentMinutes, 60);
      expect(p.maxTaskCount, 1);
      expect(p.maxRetryCount, 20);
      expect(p.retryDelaySeconds, 5);
      expect(p.liveCheckInterval, 300);
      expect(p.maxCheckInterval, 300);
      expect(p.rwTimeout, 15);
      expect(p.threadQueueSize, 2048);
      expect(p.defaultQuality, '原画');
      expect(p.maxCacheMB, 1);
    });

    test('the document round-trips every field', () {
      final p = RecorderPreferences.fromJson(RecorderPreferences(
        outputDirectory: 'X:/rec',
        segmentMinutes: 20,
        maxTaskCount: 7,
        autoReconnect: false,
        enablePolling: true,
        enableBackoff: true,
        autoStartOnBoot: true,
        rwTimeout: 60,
        threadQueueSize: 8192,
        defaultQuality: '超清',
        pinyinFolders: true,
        recordDanmaku: true,
        recordDanmakuGifts: true,
        enableCacheLimit: true,
        maxCacheMB: 2048,
      ).toJson());
      expect(p, RecorderPreferences(
        outputDirectory: 'X:/rec',
        segmentMinutes: 20,
        maxTaskCount: 7,
        autoReconnect: false,
        enablePolling: true,
        enableBackoff: true,
        autoStartOnBoot: true,
        rwTimeout: 60,
        threadQueueSize: 8192,
        defaultQuality: '超清',
        pinyinFolders: true,
        recordDanmaku: true,
        recordDanmakuGifts: true,
        enableCacheLimit: true,
        maxCacheMB: 2048,
      ));
    });
  });

  group('RecordStorage', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('record_storage');
    });
    tearDown(() => root.delete(recursive: true));

    Future<void> makeFile(String name, int bytes, {required DateTime modified}) async {
      final file = File('${root.path}/$name');
      await file.create(recursive: true);
      await file.writeAsBytes(List<int>.filled(bytes, 0));
      await file.setLastModified(modified);
    }

    test('usedBytes adds every regular file', () async {
      await makeFile('a.mp4', 1024, modified: DateTime(2026, 10));
      await makeFile('b/c.mp4', 2048, modified: DateTime(2026, 10, 2));
      expect(await RecordStorage.usedBytes(root.path), 3072);
    });

    test('the cap deletes the oldest files first and stops at the limit', () async {
      final base = DateTime.now().subtract(const Duration(days: 10));
      const twoMB = 2 * 1024 * 1024;
      await makeFile('old.mp4', twoMB, modified: base);
      await makeFile('mid.mp4', twoMB, modified: base.add(const Duration(days: 1)));
      await makeFile('new.mp4', twoMB, modified: base.add(const Duration(days: 2)));
      final freed = await RecordStorage.pruneToLimit(root: root.path, maxMB: 4);
      expect(freed, twoMB);
      expect(File('${root.path}/old.mp4').existsSync(), isFalse);
      expect(File('${root.path}/mid.mp4').existsSync(), isTrue);
      expect(File('${root.path}/new.mp4').existsSync(), isTrue);
    });

    test('a file written within the hour is never pruned', () async {
      await makeFile('fresh.mp4', 3000, modified: DateTime.now());
      final freed = await RecordStorage.pruneToLimit(root: root.path, maxMB: 1);
      expect(freed, 0);
      expect(File('${root.path}/fresh.mp4').existsSync(), isTrue);
    });

    test('clearAll removes the old and keeps today\u2019s session', () async {
      await makeFile('old.mp4', 3000, modified: DateTime.now().subtract(const Duration(days: 3)));
      await makeFile('live.ts', 3000, modified: DateTime.now());
      final freed = await RecordStorage.clearAll(root: root.path);
      expect(freed, 3000);
      expect(File('${root.path}/live.ts').existsSync(), isTrue);
    });
  });

  group('RecordChatWriter', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('record_chat');
    });
    tearDown(() => root.delete(recursive: true));

    test('a chat stream lands in the XML and the close finishes it', () async {
      final session = _FakeSession();
      final writer = await RecordChatWriter.attach(
        site: _FakeSite(_FakeProvider(session)),
        roomId: '42',
        sessionDirectory: root.path,
        taskId: 'rec_test',
        includeGifts: false,
      );
      expect(writer, isNotNull);
      expect(session.connected, isTrue);
      session.controller.add(
        const LiveMessage(type: LiveMessageType.chat, text: '你好 <世界>', sender: MessageSender(userName: 'a&b')),
      );
      session.controller.add(
        const LiveMessage(type: LiveMessageType.gift, text: '比心', sender: MessageSender(userName: 'g')),
      );
      await Future<void>.delayed(Duration.zero);
      await writer!.close();

      final content = await File('${root.path}/rec_test.chat.xml').readAsString();
      expect(content, startsWith('<root>'));
      expect(content, contains('<d p='));
      expect(content, contains('a&amp;b'));
      expect(content, contains('&lt;世界&gt;'));
      expect(content, isNot(contains('<gift')));
      expect(content.trimRight(), endsWith('</root>'));
      expect(session.disposed, isTrue);
    });

    test('gifts ride along only when included', () async {
      final session = _FakeSession();
      final writer = await RecordChatWriter.attach(
        site: _FakeSite(_FakeProvider(session)),
        roomId: '42',
        sessionDirectory: root.path,
        taskId: 'rec_gifts',
        includeGifts: true,
      );
      expect(writer, isNotNull);
      session.controller.add(
        const LiveMessage(type: LiveMessageType.gift, text: '比心 x1', sender: MessageSender(userName: 'g')),
      );
      await Future<void>.delayed(Duration.zero);
      await writer!.close();

      final content = await File('${root.path}/rec_gifts.chat.xml').readAsString();
      expect(content, contains('<gift ts='));
      expect(content, contains('name="比心 x1"'));
    });

    test('a site without danmaku attaches nothing', () async {
      final writer = await RecordChatWriter.attach(
        site: _FakeSite(null),
        roomId: '42',
        sessionDirectory: root.path,
        taskId: 'rec_none',
        includeGifts: false,
      );
      expect(writer, isNull);
    });
  });
}
