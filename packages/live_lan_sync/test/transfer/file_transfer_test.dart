import 'dart:io' show Directory;

import 'package:crypto/crypto.dart' as crypto show sha256;
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/file_doubles.dart';
import '../support/memory_stores.dart';

void main() {
  late Directory root;
  late DirectoryFileAdapter adapter;
  late FileReceiver receiver;
  late FileSender sender;
  late MemoryLanSyncStore storeA;
  late MemoryLanSyncStore storeB;

  setUp(() {
    root = Directory.systemTemp.createTempSync('live_lan_sync_test');
    addTearDown(() => root.deleteSync(recursive: true));
    storeA = MemoryLanSyncStore();
    storeB = MemoryLanSyncStore();
    adapter = DirectoryFileAdapter(root);
    receiver = FileReceiver(store: storeA, adapters: [adapter]);
    sender = FileSender(
      store: storeB,
      adapters: [adapter],
      config: const LanSyncTransferConfig(chunkBytes: 64 * 1024),
      sleep: (_) async {},
    );
  });

  void pair() {
    for (final (holder, peer) in [(storeA, 'device-b'), (storeB, 'device-a')]) {
      holder
          .putDeviceTrust(
            DeviceTrust(
              deviceId: peer,
              keyFingerprint: 'sha256:${'ab' * 32}',
              displayName: peer,
              pairedAt: DateTime.utc(2026, 11, 3),
              filePermissions: const {DeviceFilePermission.send, DeviceFilePermission.receive},
            ),
          )
          .ignore();
    }
  }

  test('a file moves chunk by chunk and lands intact', () async {
    pair();
    final bytes = testBytes(250 * 1024);
    final original = adapter.offer('font-1', bytes);
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');

    final record = await sender.send(channel: channel, category: 'font', fileId: 'font-1');

    expect(record.status, FileTransferStatus.completed, reason: record.error);
    expect(record.receivedChunks.length, record.manifest.totalChunks);
    final landed = adapter.received('font-1');
    expect(landed.existsSync(), isTrue);
    expect(crypto.sha256.convert(landed.readAsBytesSync()).toString(), crypto.sha256.convert(bytes).toString());
    expect(adapter.committedFiles, hasLength(1));
    expect(original.existsSync(), isTrue);
    expect(
      adapter.staging.existsSync() && adapter.staging.listSync().isNotEmpty,
      isFalse,
      reason: 'staging is cleaned up',
    );
    expect(record.manifest.fileName, 'font-1.ttf');
  });

  test('an interrupted transfer resumes with only the missing chunks', () async {
    pair();
    adapter.offer('font-1', testBytes(6 * 64 * 1024));
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a')
      ..beforeCall = (route, number) {
        if (route == 'chunk' && number == 3) {
          throw const LanSyncError(category: LanSyncErrorCategory.timeout, code: 'timeout', message: 'Slow network.');
        }
      };

    final interrupted = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(interrupted.status, FileTransferStatus.failed);
    expect(interrupted.receivedChunks, {0, 1}, reason: 'two chunks landed before the drop');
    expect(channel.calls['chunk'], 3);

    channel.beforeCall = null;
    final resumed = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(resumed.status, FileTransferStatus.completed, reason: resumed.error);
    expect(channel.calls['chunk'], 7, reason: 'exactly the four missing chunks were sent');
    expect(adapter.received('font-1').lengthSync(), 6 * 64 * 1024);
  });

  test('a receiver restart loses nothing that is on disk', () async {
    pair();
    adapter.offer('font-1', testBytes(4 * 64 * 1024));
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a')
      ..beforeCall = (route, number) {
        if (route == 'chunk' && number == 2) {
          throw const LanSyncError(
            category: LanSyncErrorCategory.timeout,
            code: 'timeout',
            message: 'Connection reset.',
          );
        }
      };
    await sender.send(channel: channel, category: 'font', fileId: 'font-1');

    // The app restarts: a fresh receiver over the same store and staging.
    final revived = FileReceiver(store: storeA, adapters: [adapter]);
    addTearDown(revived.dispose);
    final revivedChannel = LoopbackFileChannel(receiver: revived, callerId: 'device-b', peerDeviceId: 'device-a');

    final record = await sender.send(channel: revivedChannel, category: 'font', fileId: 'font-1');
    expect(record.status, FileTransferStatus.completed, reason: record.error);
    expect(revivedChannel.calls['chunk'], 3, reason: 'only the missing chunks were sent');
    expect(
      crypto.sha256.convert(adapter.received('font-1').readAsBytesSync()).toString(),
      crypto.sha256.convert(testBytes(4 * 64 * 1024)).toString(),
    );
  });

  test('a corrupted chunk is refused and resent, not committed', () async {
    pair();
    adapter.offer('font-1', testBytes(3 * 64 * 1024));
    var damaged = false;
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a')
      ..tamper = (index, bytes) {
        if (index != 1 || damaged) return bytes;
        damaged = true;
        return [...bytes.take(10), bytes[10] ^ 0xFF, ...bytes.skip(11)];
      };

    final record = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(record.status, FileTransferStatus.completed, reason: record.error);
    expect(
      crypto.sha256.convert(adapter.received('font-1').readAsBytesSync()).toString(),
      crypto.sha256.convert(testBytes(3 * 64 * 1024)).toString(),
      reason: 'the damaged chunk was refused and the good version committed',
    );
    expect(channel.calls['chunk'], 4, reason: 'three chunks, the damaged one sent twice');
  });

  test('an adapter that rejects the content ends the transfer without committing', () async {
    pair();
    adapter
      ..offer('font-1', testBytes(64 * 1024))
      ..rejectReason = 'not a real font';
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');

    final record = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(record.status, FileTransferStatus.failed);
    expect(record.error, contains('file_rejected'));
    expect(record.error, contains('not a real font'));
    expect(adapter.received('font-1').existsSync(), isFalse);
    expect(adapter.committedFiles, isEmpty);
  });

  test('content the receiver already holds is skipped entirely', () async {
    pair();
    final bytes = testBytes(64 * 1024);
    adapter.offer('font-1', bytes);
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');

    final first = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(first.status, FileTransferStatus.completed);
    final afterFirst = channel.calls['chunk'];

    // The receiver keeps the file; the sender's copy is the same content.
    final second = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(second.status, FileTransferStatus.skipped);
    expect(channel.calls['chunk'], afterFirst, reason: 'no chunk moved the second time');
  });

  test('a new version of a file replaces the old one in place', () async {
    pair();
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');
    adapter.offer('font-1', testBytes(2 * 64 * 1024));
    final first = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(first.status, FileTransferStatus.completed);

    final updated = testBytes(3 * 64 * 1024 + 5, seed: 42);
    adapter.offer('font-1', updated);
    final second = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(second.status, FileTransferStatus.completed, reason: second.error);
    expect(
      crypto.sha256.convert(adapter.received('font-1').readAsBytesSync()).toString(),
      crypto.sha256.convert(updated).toString(),
      reason: 'the committed file is the new version, replaced atomically',
    );
    expect(adapter.committedFiles, hasLength(2));
  });

  test('cancelling mid-transfer discards the partial state', () async {
    pair();
    adapter.offer('font-1', testBytes(4 * 64 * 1024));
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a')
      ..beforeCall = (route, number) {
        if (route == 'chunk' && number == 2) {
          throw const LanSyncError(
            category: LanSyncErrorCategory.timeout,
            code: 'timeout',
            message: 'Connection reset.',
          );
        }
      };
    final interrupted = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(interrupted.status, FileTransferStatus.failed);
    final transferId = interrupted.transferId;

    await sender.cancel(channel, transferId);
    final record = await storeB.fileTransfer(transferId);
    expect(record!.status, FileTransferStatus.cancelled);
    expect(adapter.received('font-1').existsSync(), isFalse);
  });

  test('an ungranted or unpaired sender gets nothing', () async {
    await storeB.putDeviceTrust(
      DeviceTrust(
        deviceId: 'device-a',
        keyFingerprint: 'sha256:${'ab' * 32}',
        displayName: 'Desktop',
        pairedAt: DateTime.utc(2026, 11, 3),
        filePermissions: const {DeviceFilePermission.send},
      ),
    );
    storeA
        .putDeviceTrust(
          DeviceTrust(
            deviceId: 'device-b',
            keyFingerprint: 'sha256:${'ab' * 32}',
            displayName: 'Phone',
            pairedAt: DateTime.utc(2026, 11, 3),
            filePermissions: const {DeviceFilePermission.send},
          ),
        )
        .ignore();
    adapter.offer('font-1', testBytes(64 * 1024));
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');

    final record = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(record.status, FileTransferStatus.failed);
    expect(record.error, contains('file_receive_not_granted'));
    expect(adapter.received('font-1').existsSync(), isFalse);
  });

  test('an unknown category is a configuration error', () {
    expect(
      () => FileSender(store: MemoryLanSyncStore(), adapters: [adapter]).send(
        channel: LoopbackFileChannel(receiver: receiver, callerId: 'b', peerDeviceId: 'a'),
        category: 'wallpaper',
        fileId: 'w1',
      ),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'file_category_unknown')),
    );
  });

  test('a file whose whole hash does not match is never committed', () async {
    pair();
    final file = adapter.offer('font-1', testBytes(2 * 64 * 1024));
    final honest = await FileSender.describe(
      file: file,
      fileId: 'font-1',
      category: 'font',
      fileName: 'font-1.ttf',
      mimeType: 'font/ttf',
      chunkSize: 64 * 1024,
    );
    // Every chunk hash is right; the whole-file hash is not.
    final forged = FileManifest(
      fileId: honest.fileId,
      category: honest.category,
      fileName: honest.fileName,
      mimeType: honest.mimeType,
      size: honest.size,
      sha256: 'f' * 64,
      chunkSize: honest.chunkSize,
      chunkSha256: honest.chunkSha256,
    );
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');
    final init = await channel.init({'manifest': forged.toJson()});
    final transferId = init['transferId']! as String;
    final bytes = file.readAsBytesSync();
    await channel.putChunk(transferId, 0, bytes.sublist(0, 64 * 1024));
    final last = await channel.putChunk(transferId, 1, bytes.sublist(64 * 1024));

    expect(last['status'], 'failed');
    expect(last['error'], contains('file_hash_mismatch'));
    expect(adapter.received('font-1').existsSync(), isFalse);
    expect(adapter.committedFiles, isEmpty);
    expect(Directory('${adapter.staging.path}/$transferId').existsSync(), isFalse, reason: 'bad data is discarded');
  });

  test('a file that changes while it is sent is stopped, not mixed', () async {
    pair();
    final file = adapter.offer('font-1', testBytes(4 * 64 * 1024));
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a')
      ..beforeCall = (route, number) {
        if (route == 'chunk' && number == 2) {
          // Someone saves a new version of the font mid-transfer.
          file.writeAsBytesSync(testBytes(4 * 64 * 1024, seed: 99));
        }
      };

    final record = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(record.status, FileTransferStatus.failed);
    expect(record.error, contains('source_changed'));
    expect(adapter.received('font-1').existsSync(), isFalse);
  });

  test('an empty file commits at once', () async {
    pair();
    adapter.offer('empty', const <int>[]);
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');

    final record = await sender.send(channel: channel, category: 'font', fileId: 'empty');
    expect(record.status, FileTransferStatus.completed, reason: record.error);
    expect(adapter.received('empty').lengthSync(), 0);
    expect(channel.calls['chunk'], isNull);
  });

  test('a file larger than the receiver accepts is refused before any chunk moves', () async {
    pair();
    adapter.offer('font-1', testBytes(3 * 64 * 1024));
    final strict = FileReceiver(
      store: storeA,
      adapters: [DirectoryFileAdapter(root, maxFileBytes: 64 * 1024)],
    );
    addTearDown(strict.dispose);
    final channel = LoopbackFileChannel(receiver: strict, callerId: 'device-b', peerDeviceId: 'device-a');

    final record = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(record.status, FileTransferStatus.failed);
    expect(record.error, contains('file_too_large'));
    expect(channel.calls['chunk'], isNull);
  });

  test('abandoned partial transfers are purged with their staging', () async {
    pair();
    var clock = DateTime.utc(2026, 11, 3, 12);
    final timed = FileReceiver(store: storeA, adapters: [adapter], now: () => clock);
    addTearDown(timed.dispose);
    adapter.offer('font-1', testBytes(3 * 64 * 1024));
    final channel = LoopbackFileChannel(receiver: timed, callerId: 'device-b', peerDeviceId: 'device-a')
      ..beforeCall = (route, number) {
        if (route == 'chunk' && number == 2) {
          throw const LanSyncError(category: LanSyncErrorCategory.timeout, code: 'timeout', message: 'Gone.');
        }
      };
    final partial = await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    expect(partial.status, FileTransferStatus.failed);
    expect(Directory('${adapter.staging.path}/${partial.transferId}').existsSync(), isTrue);

    expect(await timed.purgeAbandoned(olderThan: const Duration(days: 1)), 0, reason: 'still fresh');
    clock = clock.add(const Duration(days: 2));
    expect(await timed.purgeAbandoned(olderThan: const Duration(days: 1)), 1);
    expect(Directory('${adapter.staging.path}/${partial.transferId}').existsSync(), isFalse);
    expect((await storeA.fileTransfer(partial.transferId))!.status, FileTransferStatus.failed);
  });

  test('progress is published as chunks land', () async {
    pair();
    adapter.offer('font-1', testBytes(3 * 64 * 1024));
    final updates = <FileTransferRecord>[];
    final subscription = receiver.events.listen((event) {
      if (event is FileTransferUpdated) updates.add(event.transfer);
    });
    addTearDown(subscription.cancel);
    final channel = LoopbackFileChannel(receiver: receiver, callerId: 'device-b', peerDeviceId: 'device-a');

    await sender.send(channel: channel, category: 'font', fileId: 'font-1');
    await Future<void>.delayed(Duration.zero);
    expect(updates.map((record) => record.status), contains(FileTransferStatus.transferring));
    expect(updates.last.status, FileTransferStatus.completed);
    expect(updates.last.progress, 1);
  });

  group('manifests', () {
    test('compute over one streaming pass', () async {
      final file = adapter.offer('big', testBytes(5 * 64 * 1024 + 11));
      final manifest = await FileSender.describe(
        file: file,
        fileId: 'big',
        category: 'font',
        fileName: 'Big Font.ttf',
        mimeType: 'font/ttf',
        chunkSize: 64 * 1024,
      );
      expect(manifest.size, 5 * 64 * 1024 + 11);
      expect(manifest.totalChunks, 6);
      expect(manifest.chunkSha256, hasLength(6));
      expect(manifest.chunkLength(5), 11);
      expect(manifest.sha256, crypto.sha256.convert(file.readAsBytesSync()).toString());
    });

    test('sanitize names on the way in', () {
      expect(FileManifest.sanitizeFileName(r'..\..\windows\system32\evil.dll'), 'evil.dll');
      expect(FileManifest.sanitizeFileName('a:b*c?.ttf'), 'a_b_c_.ttf');
      expect(FileManifest.sanitizeFileName('...hidden'), 'hidden');
      expect(FileManifest.sanitizeFileName('CON'), '_CON');
      expect(FileManifest.sanitizeFileName('com1.txt'), '_com1.txt');
      expect(FileManifest.sanitizeFileName(''), 'file');
      expect(FileManifest.sanitizeFileName('${'x' * 200}.ttf').length, lessThanOrEqualTo(120));
    });

    test('fromJson refuses inconsistencies', () {
      Map<String, Object?> valid() => FileManifest(
        fileId: 'f1',
        category: 'font',
        fileName: 'f.ttf',
        mimeType: 'font/ttf',
        size: 3 * 64 * 1024,
        sha256: 'a' * 64,
        chunkSize: 64 * 1024,
        chunkSha256: ['b' * 64, 'c' * 64, 'd' * 64],
      ).toJson();

      expect(FileManifest.fromJson(valid()).totalChunks, 3);

      final badHash = valid()..['sha256'] = 'nope';
      expect(() => FileManifest.fromJson(badHash), throwsA(isA<LanSyncError>()));

      final tinyChunks = valid()..['chunkSize'] = 1024;
      expect(() => FileManifest.fromJson(tinyChunks), throwsA(isA<LanSyncError>()));

      final shortCoverage = valid()..['chunkSha256'] = ['b' * 64];
      expect(() => FileManifest.fromJson(shortCoverage), throwsA(isA<LanSyncError>()));

      final wrongCount = valid()..['totalChunks'] = 9;
      expect(() => FileManifest.fromJson(wrongCount), throwsA(isA<LanSyncError>()));
    });
  });
}
