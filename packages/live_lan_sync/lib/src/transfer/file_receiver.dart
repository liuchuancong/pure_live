import 'dart:async' show Completer, StreamController;
import 'dart:io' show Directory, File, FileSystemException, Platform;
import 'dart:math' show Random, min;

import 'package:crypto/crypto.dart' as crypto show Digest, sha256;
import 'package:live_lan_sync/src/adapter/adapter.dart' show LanSyncFileAdapter;
import 'package:live_lan_sync/src/config/config.dart' show LanSyncTransferConfig;
import 'package:live_lan_sync/src/domain/device/device.dart' show DeviceTrust;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/events/lan_sync_event.dart' show FileTransferUpdated, LanSyncEvent;
import 'package:live_lan_sync/src/domain/transfer/transfer.dart'
    show FileManifest, FileTransferDirection, FileTransferRecord, FileTransferStatus;
import 'package:live_lan_sync/src/logging/logging.dart';
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;
import 'package:live_lan_sync/src/transport/lan_sync_http_server.dart' show LanSyncHttpServer, PeerRequest;

/// The receiving half of file transfer (spec §13.3): registers transfers,
/// stores chunks, and commits a file only once every chunk and the whole
/// file have been verified and its adapter accepted the content.
///
/// Each chunk is written to its own staging file through a temporary name
/// and a rename, so a chunk file exists only when complete. Which chunks
/// are durably here is persisted after each one; an interrupted transfer —
/// or a restarted app — resumes with exactly the chunks still missing.
/// Staging lives in a directory per transfer, inside the adapter's staging
/// directory, named by the transfer id: nothing a peer sent becomes a path.
final class FileReceiver {
  /// A receiver over [store] for the categories of [adapters].
  ///
  /// Throws a [LanSyncError] with `configuration` when two adapters claim
  /// the same category.
  new({
    required this.store,
    required Iterable<LanSyncFileAdapter> adapters,
    this.config = const LanSyncTransferConfig(),
    LanSyncLogger? logger,
    DateTime Function()? now,
    Random? random,
  }) : _log = logger?.area(LanSyncLogArea.transfer) ?? LanSyncLogger.silent.area(LanSyncLogArea.transfer),
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure() {
    for (final adapter in adapters) {
      if (_adapters.containsKey(adapter.category)) {
        throw LanSyncError(
          category: LanSyncErrorCategory.configuration,
          code: 'file_category_registered_twice',
          message: 'Two file adapters claim the category "${adapter.category}".',
        );
      }
      _adapters[adapter.category] = adapter;
    }
  }

  /// Where transfer records and chunk state persist.
  final LanSyncStore store;

  /// Size caps, resume and verification policy.
  final LanSyncTransferConfig config;

  final Map<String, LanSyncFileAdapter> _adapters = <String, LanSyncFileAdapter>{};
  final LanSyncLog _log;
  final DateTime Function() _now;
  final Random _random;
  final Map<String, Future<void>> _locks = <String, Future<void>>{};
  final StreamController<LanSyncEvent> _events = StreamController<LanSyncEvent>.broadcast();
  int _maxChunkBytes = FileManifest.maxChunkSize;

  /// Transfer progress, completion and failure as they happen.
  Stream<LanSyncEvent> get events => _events.stream;

  /// Registers the file routes on [server]. Chunks larger than the
  /// server's request-body limit are refused at registration time.
  void attachTo(LanSyncHttpServer server) {
    _maxChunkBytes = min(FileManifest.maxChunkSize, server.serverConfig.maxRequestBodyBytes);
    server
      ..route('POST', 'files/init', handleInit)
      ..route('PUT', 'files/{transferId}/chunks/{index}', handleChunk, rawBody: true)
      ..route('GET', 'files/{transferId}/status', handleStatus)
      ..route('DELETE', 'files/{transferId}', handleCancel);
  }

  /// `POST /files/init`: validates the manifest, skips content already
  /// held, resumes an open transfer of the same file, or opens a new one.
  Future<Map<String, Object?>> handleInit(PeerRequest request) async {
    final sender = request.senderDeviceId;
    final trust = await _trustOf(sender);
    if (!trust.allowsReceiveFiles) {
      throw LanSyncError(
        category: LanSyncErrorCategory.permissionDenied,
        code: 'file_receive_not_granted',
        message: 'This device does not accept files from the sender.',
        deviceId: sender,
      );
    }
    final manifest = FileManifest.fromJson(switch (request.body['manifest']) {
      final Map<Object?, Object?> map => map.cast<String, Object?>(),
      _ => const <String, Object?>{},
    });
    final adapter = _adapterFor(manifest.category);
    if (manifest.size > min(config.maxFileBytes, adapter.maxFileBytes)) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'file_too_large',
        message: 'The file is larger than this device accepts.',
      );
    }
    if (manifest.chunkSize > _maxChunkBytes) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'chunk_too_large',
        message: 'The chunks are larger than this device accepts in one request.',
      );
    }
    if (config.verifyChunkHash && manifest.totalChunks > 0 && manifest.chunkSha256.isEmpty) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'chunk_hashes_required',
        message: 'This device verifies every chunk; the manifest must list their hashes.',
      );
    }
    if (await adapter.hasContent(fileId: manifest.fileId, sha256: manifest.sha256)) {
      _log.debug('file already held', fields: {'category': manifest.category, 'file': manifest.fileId});
      return <String, Object?>{'status': FileTransferStatus.skipped.name};
    }
    return await _exclusive('init/$sender/${manifest.category}/${manifest.fileId}', () async {
      final open = await _openTransferOf(sender, manifest);
      if (open != null) {
        final resumable =
            config.resumeEnabled &&
            open.manifest.sha256 == manifest.sha256 &&
            open.manifest.chunkSize == manifest.chunkSize &&
            open.manifest.size == manifest.size;
        if (resumable) {
          return await _exclusive(open.transferId, () async {
            var record = open.withChunks(await _verifiedChunks(open, adapter), _now().toUtc());
            await _save(record);
            if (record.receivedChunks.length == manifest.totalChunks) {
              record = await _complete(record, adapter);
            }
            return _answer(record);
          });
        }
        await _discard(open, adapter, FileTransferStatus.cancelled, 'Superseded by a newer version of the file.');
      }
      final reserved = await _reservedBytes();
      if (reserved + manifest.size > config.maxTotalBytes) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.insufficientStorage,
          code: 'transfer_quota_exceeded',
          message: 'Too much incoming data is in flight; try again when earlier transfers finish.',
          retryable: true,
        );
      }
      final at = _now().toUtc();
      var record = FileTransferRecord(
        transferId: _newId(),
        peerDeviceId: sender,
        direction: FileTransferDirection.incoming,
        manifest: manifest,
        status: FileTransferStatus.pending,
        createdAt: at,
        updatedAt: at,
      );
      _log.info(
        'file transfer opened',
        fields: {
          'device': sender,
          'category': manifest.category,
          'file': manifest.fileId,
          'size': manifest.size,
          'chunks': manifest.totalChunks,
        },
      );
      await (await _stagingOf(record, adapter)).create(recursive: true);
      await _save(record);
      if (manifest.totalChunks == 0) {
        record = await _complete(record, adapter);
      }
      return _answer(record);
    });
  }

  /// `PUT /files/{transferId}/chunks/{index}`: verifies and stores one
  /// chunk; the last one triggers verification and commit.
  Future<Map<String, Object?>> handleChunk(PeerRequest request) async {
    final transferId = request.pathParameters['transferId'] ?? '';
    final index = int.tryParse(request.pathParameters['index'] ?? '') ?? -1;
    return await _exclusive(transferId, () async {
      final record = await _incoming(transferId, request.senderDeviceId);
      if (record.isFinished) {
        return _answer(record);
      }
      final manifest = record.manifest;
      if (index < 0 || index >= manifest.totalChunks) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'chunk_index_invalid',
          message: 'The chunk index is outside the file.',
        );
      }
      if (record.receivedChunks.contains(index)) {
        return _answer(record);
      }
      final bytes = request.bytes;
      if (bytes.length != manifest.chunkLength(index)) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'chunk_size_mismatch',
          message: 'The chunk has the wrong length.',
        );
      }
      if (config.verifyChunkHash &&
          manifest.chunkSha256.isNotEmpty &&
          crypto.sha256.convert(bytes).toString() != manifest.chunkSha256[index]) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.integrityCheck,
          code: 'chunk_hash_mismatch',
          message: 'The chunk does not match the file it claims to belong to.',
          retryable: true,
        );
      }
      final adapter = _adapterFor(manifest.category);
      final staging = await _stagingOf(record, adapter);
      try {
        await staging.create(recursive: true);
        final partial = File('${staging.path}${Platform.pathSeparator}$index.chunk.tmp');
        await partial.writeAsBytes(bytes, flush: true);
        await partial.rename(_chunkFile(staging, index).path);
      } on FileSystemException catch (error) {
        throw _storageFailure(error);
      }
      var updated = record.withChunk(index, _now().toUtc());
      _log.debug('chunk received', fields: {'transfer': record.transferId, 'index': index, 'of': manifest.totalChunks});
      await _save(updated);
      if (updated.receivedChunks.length == manifest.totalChunks) {
        updated = await _complete(updated, adapter);
      }
      return _answer(updated);
    });
  }

  /// `GET /files/{transferId}/status`: where the transfer stands, with the
  /// chunks that are durably here.
  Future<Map<String, Object?>> handleStatus(PeerRequest request) async {
    final transferId = request.pathParameters['transferId'] ?? '';
    return await _exclusive(transferId, () async {
      final record = await _incoming(transferId, request.senderDeviceId);
      if (record.isFinished) return _answer(record);
      final staging = await _stagingOf(record, _adapterFor(record.manifest.category));
      final present = {
        for (final index in record.receivedChunks)
          if (_chunkFile(staging, index).existsSync()) index,
      };
      return _answer(present.length == record.receivedChunks.length ? record : record.withChunks(present, _now()));
    });
  }

  /// `DELETE /files/{transferId}`: discards the transfer and its staging.
  Future<Map<String, Object?>> handleCancel(PeerRequest request) async {
    final transferId = request.pathParameters['transferId'] ?? '';
    return await _exclusive(transferId, () async {
      final record = await _incoming(transferId, request.senderDeviceId);
      if (record.isFinished) return _answer(record);
      return _answer(
        await _discard(record, _adapterFor(record.manifest.category), FileTransferStatus.cancelled, 'Cancelled.'),
      );
    });
  }

  /// Discards incoming transfers idle since before `now - olderThan` — the
  /// partial state a resumable transfer would otherwise keep forever.
  /// Returns how many were discarded.
  Future<int> purgeAbandoned({required Duration olderThan}) async {
    final cutoff = _now().toUtc().subtract(olderThan);
    var discarded = 0;
    for (final record in await store.fileTransfers(direction: FileTransferDirection.incoming)) {
      if (record.isFinished || !record.updatedAt.isBefore(cutoff)) continue;
      final adapter = _adapters[record.manifest.category];
      if (adapter == null) continue;
      await _exclusive(record.transferId, () => _discard(record, adapter, FileTransferStatus.failed, 'Abandoned.'));
      discarded++;
    }
    return discarded;
  }

  /// Closes the event stream.
  Future<void> dispose() => _events.close();

  /// Assembles the chunks, verifies the whole file, lets the adapter check
  /// the content, then moves the file into place atomically.
  Future<FileTransferRecord> _complete(FileTransferRecord record, LanSyncFileAdapter adapter) async {
    final manifest = record.manifest;
    final current = record.withStatus(FileTransferStatus.verifying, _now().toUtc());
    await _save(current);
    final staging = await _stagingOf(current, adapter);
    final assembled = File('${staging.path}${Platform.pathSeparator}assembled.part');
    try {
      final digest = _DigestSink();
      final hasher = crypto.sha256.startChunkedConversion(digest);
      final sink = assembled.openWrite();
      try {
        for (var index = 0; index < manifest.totalChunks; index++) {
          final bytes = await _chunkFile(staging, index).readAsBytes();
          hasher.add(bytes);
          sink.add(bytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      hasher.close();
      if (digest.value.toString() != manifest.sha256) {
        _log.error('the assembled file does not match its hash', fields: {'file': manifest.fileId});
        return await _discard(
          current,
          adapter,
          FileTransferStatus.failed,
          'file_hash_mismatch: the assembled file does not match its hash.',
        );
      }
      final problem = await adapter.validate(manifest, assembled);
      if (problem != null) {
        return await _discard(current, adapter, FileTransferStatus.failed, 'file_rejected: $problem');
      }
      final target = await adapter.targetFor(manifest);
      await target.parent.create(recursive: true);
      final File committed;
      try {
        committed = await assembled.rename(target.path);
      } on FileSystemException {
        // A platform that refuses to rename over an existing file: clear
        // the older version, then move the verified one in.
        if (target.existsSync()) await target.delete();
        return await _finishCommit(current, adapter, manifest, await assembled.rename(target.path), staging);
      }
      return await _finishCommit(current, adapter, manifest, committed, staging);
    } on LanSyncError {
      rethrow;
    } on FileSystemException catch (error) {
      return await _discard(current, adapter, FileTransferStatus.failed, 'storage: ${_storageFailure(error).code}');
    }
  }

  Future<FileTransferRecord> _finishCommit(
    FileTransferRecord record,
    LanSyncFileAdapter adapter,
    FileManifest manifest,
    File committed,
    Directory staging,
  ) async {
    await adapter.committed(manifest, committed);
    if (staging.existsSync()) await staging.delete(recursive: true);
    final done = record.withStatus(FileTransferStatus.completed, _now().toUtc());
    await _save(done);
    return done;
  }

  /// Ends [record] in [status], deleting its staging.
  Future<FileTransferRecord> _discard(
    FileTransferRecord record,
    LanSyncFileAdapter adapter,
    FileTransferStatus status,
    String reason,
  ) async {
    final staging = await _stagingOf(record, adapter);
    try {
      if (staging.existsSync()) await staging.delete(recursive: true);
    } on FileSystemException {
      // Staging the OS will not let go of yet; purgeAbandoned retries it.
    }
    final ended = record.withStatus(
      status,
      _now().toUtc(),
      error: status == FileTransferStatus.cancelled ? null : reason,
    );
    await _save(ended);
    return ended;
  }

  /// The chunks of [record] that are really on disk, intact.
  Future<Set<int>> _verifiedChunks(FileTransferRecord record, LanSyncFileAdapter adapter) async {
    final staging = await _stagingOf(record, adapter);
    final manifest = record.manifest;
    final verified = <int>{};
    for (final index in record.receivedChunks) {
      final file = _chunkFile(staging, index);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      if (bytes.length != manifest.chunkLength(index)) continue;
      if (manifest.chunkSha256.isNotEmpty && crypto.sha256.convert(bytes).toString() != manifest.chunkSha256[index]) {
        continue;
      }
      verified.add(index);
    }
    return verified;
  }

  Future<FileTransferRecord?> _openTransferOf(String sender, FileManifest manifest) async {
    for (final record in await store.fileTransfers(direction: FileTransferDirection.incoming)) {
      if (!record.isFinished &&
          record.peerDeviceId == sender &&
          record.manifest.category == manifest.category &&
          record.manifest.fileId == manifest.fileId) {
        return record;
      }
    }
    return null;
  }

  Future<int> _reservedBytes() async => [
    for (final record in await store.fileTransfers(direction: FileTransferDirection.incoming))
      if (!record.isFinished) record.manifest.size,
  ].fold<int>(0, (sum, size) => sum + size);

  Future<FileTransferRecord> _incoming(String transferId, String sender) async {
    final record = await store.fileTransfer(transferId);
    if (record == null || record.direction != FileTransferDirection.incoming || record.peerDeviceId != sender) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.fileTransfer,
        code: 'transfer_unknown',
        message: 'The transfer is unknown on this device.',
      );
    }
    return record;
  }

  Future<DeviceTrust> _trustOf(String deviceId) async {
    final trust = await store.deviceTrust(deviceId);
    if (trust == null || trust.revoked) {
      throw LanSyncError(
        category: LanSyncErrorCategory.authentication,
        code: 'peer_not_paired',
        message: 'The device is not paired, or the pairing was revoked.',
        deviceId: deviceId,
      );
    }
    return trust;
  }

  LanSyncFileAdapter _adapterFor(String category) =>
      _adapters[category] ??
      (throw LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'file_category_unknown',
        message: 'This device does not accept files of the category "$category".',
      ));

  Future<Directory> _stagingOf(FileTransferRecord record, LanSyncFileAdapter adapter) async =>
      Directory('${(await adapter.stagingDirectory()).path}${Platform.pathSeparator}${record.transferId}');

  static File _chunkFile(Directory staging, int index) => File('${staging.path}${Platform.pathSeparator}$index.chunk');

  Future<void> _save(FileTransferRecord record) async {
    await store.saveFileTransfer(record);
    if (!_events.isClosed) {
      _events.add(FileTransferUpdated(record));
    }
  }

  Map<String, Object?> _answer(FileTransferRecord record) => <String, Object?>{
    'transferId': record.transferId,
    'status': record.status.name,
    'receivedChunks': record.receivedChunks.toList()..sort(),
    'totalChunks': record.manifest.totalChunks,
    'error': ?record.error,
  };

  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<T> _exclusive<T>(String key, Future<T> Function() action) {
    final previous = _locks[key] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[key] = done.future;
    return previous.then((_) => action()).whenComplete(() {
      done.complete();
      if (identical(_locks[key], done.future)) _locks.remove(key)?.ignore();
    });
  }

  static LanSyncError _storageFailure(FileSystemException error) {
    final code = error.osError?.errorCode;
    // ENOSPC on Linux and macOS; ERROR_HANDLE_DISK_FULL and ERROR_DISK_FULL
    // on Windows.
    final full = code == 28 || code == 39 || code == 112;
    return LanSyncError(
      category: full ? LanSyncErrorCategory.insufficientStorage : LanSyncErrorCategory.storage,
      code: full ? 'disk_full' : 'staging_write_failed',
      message: full ? 'This device is out of storage space.' : 'The file could not be stored on this device.',
      retryable: !full,
      debugContext: error.message,
    );
  }
}

/// Collects the single digest a chunked SHA-256 conversion produces.
final class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}
