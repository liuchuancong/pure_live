import 'dart:async' show StreamController;
import 'dart:io' show File, FileSystemException, RandomAccessFile;
import 'dart:math' show Random, min;
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart' as crypto show Digest, sha256;
import 'package:live_lan_sync/src/adapter/adapter.dart' show LanSyncFileAdapter;
import 'package:live_lan_sync/src/config/config.dart' show LanSyncTransferConfig;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/events/lan_sync_event.dart' show FileTransferUpdated, LanSyncEvent;
import 'package:live_lan_sync/src/domain/transfer/transfer.dart'
    show FileManifest, FileTransferDirection, FileTransferRecord, FileTransferStatus;
import 'package:live_lan_sync/src/logging/logging.dart';
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;
import 'package:live_lan_sync/src/sync/peer_sync_channel.dart' show SyncCancellation;
import 'package:live_lan_sync/src/transfer/peer_file_channel.dart' show PeerFileChannel;

/// The sending half of file transfer (spec §13.3).
///
/// [send] hashes the file in one streaming pass (whole file and every
/// chunk), registers the transfer, and sends only the chunks the receiver
/// reports missing — so calling it again after an interruption resumes
/// where the receiver stands. Each chunk is re-hashed as it is read and
/// checked against the manifest: a file that changes while it is being sent
/// stops the transfer instead of shipping a mix of two versions.
///
/// [send] never throws for transfer outcomes; the returned (and persisted)
/// record says how it ended. Only an unknown category — a programming
/// error — throws.
final class FileSender {
  /// A sender over [store] for the categories of [adapters].
  ///
  /// Throws a [LanSyncError] with `configuration` when two adapters claim
  /// the same category.
  new({
    required this.store,
    required Iterable<LanSyncFileAdapter> adapters,
    this.config = const LanSyncTransferConfig(),
    this.maxRetries = 3,
    LanSyncLogger? logger,
    DateTime Function()? now,
    Random? random,
    Future<void> Function(Duration delay)? sleep,
  }) : _log = logger?.area(LanSyncLogArea.transfer) ?? LanSyncLogger.silent.area(LanSyncLogArea.transfer),
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure(),
       _sleep = sleep ?? Future<void>.delayed {
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

  /// Where outgoing transfer records persist.
  final LanSyncStore store;

  /// Chunk size, caps and concurrency.
  final LanSyncTransferConfig config;

  /// How often a retryable request failure is retried, with backoff.
  final int maxRetries;

  final Map<String, LanSyncFileAdapter> _adapters = <String, LanSyncFileAdapter>{};
  final DateTime Function() _now;
  final Random _random;
  final Future<void> Function(Duration) _sleep;
  final StreamController<LanSyncEvent> _events = StreamController<LanSyncEvent>.broadcast();
  final LanSyncLog _log;

  /// Transfer progress, completion and failure as they happen.
  Stream<LanSyncEvent> get events => _events.stream;

  /// Describes [file] in one streaming pass: its size, whole-file SHA-256
  /// and one SHA-256 per [chunkSize] bytes. Memory stays at one chunk.
  ///
  /// Throws a [LanSyncError] with `fileTransfer` when the file cannot be
  /// read or changes size while it is read.
  static Future<FileManifest> describe({
    required File file,
    required String fileId,
    required String category,
    required String fileName,
    required String mimeType,
    required int chunkSize,
  }) async {
    final RandomAccessFile raf;
    try {
      raf = await file.open();
    } on FileSystemException catch (error) {
      throw _unreadable(error);
    }
    try {
      final size = await raf.length();
      final digest = _DigestSink();
      final whole = crypto.sha256.startChunkedConversion(digest);
      final chunkHashes = <String>[];
      var position = 0;
      while (position < size) {
        final bytes = await _readFully(raf, min(chunkSize, size - position));
        if (bytes.isEmpty) break;
        whole.add(bytes);
        chunkHashes.add(crypto.sha256.convert(bytes).toString());
        position += bytes.length;
      }
      whole.close();
      if (position != size) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.fileTransfer,
          code: 'source_changed',
          message: 'The file changed while it was being read.',
        );
      }
      return FileManifest(
        fileId: fileId,
        category: category,
        fileName: FileManifest.sanitizeFileName(fileName),
        mimeType: mimeType,
        size: size,
        sha256: digest.value.toString(),
        chunkSize: chunkSize,
        chunkSha256: chunkHashes,
      );
    } on FileSystemException catch (error) {
      throw _unreadable(error);
    } finally {
      await raf.close();
    }
  }

  /// Sends the file [fileId] of [category] to [channel]'s peer, resuming
  /// whatever the receiver already holds.
  ///
  /// Throws a [LanSyncError] with `configuration` for an unknown category.
  Future<FileTransferRecord> send({
    required PeerFileChannel channel,
    required String category,
    required String fileId,
    SyncCancellation? cancellation,
  }) async {
    final adapter = _adapters[category];
    if (adapter == null) {
      throw LanSyncError(
        category: LanSyncErrorCategory.configuration,
        code: 'file_category_unknown',
        message: 'No file adapter handles the category "$category".',
      );
    }
    final peer = channel.peerDeviceId;
    FileManifest? manifest;
    FileTransferRecord? record;
    try {
      final trust = await store.deviceTrust(peer);
      if (trust == null || trust.revoked) {
        throw LanSyncError(
          category: LanSyncErrorCategory.authentication,
          code: 'peer_not_paired',
          message: 'The device is not paired, or the pairing was revoked.',
          deviceId: peer,
        );
      }
      if (!trust.allowsSendFiles) {
        throw LanSyncError(
          category: LanSyncErrorCategory.permissionDenied,
          code: 'file_send_not_granted',
          message: 'This device does not send files to that device.',
          deviceId: peer,
        );
      }
      final local = await adapter.localFile(fileId);
      if (local == null) {
        throw LanSyncError(
          category: LanSyncErrorCategory.fileTransfer,
          code: 'file_unavailable',
          message: 'This device does not have the file.',
          deviceId: peer,
        );
      }
      final described = manifest = await describe(
        file: local.file,
        fileId: fileId,
        category: category,
        fileName: local.fileName,
        mimeType: local.mimeType,
        chunkSize: config.chunkBytes,
      );
      _log.info(
        'sending file',
        fields: {
          'device': peer,
          'category': category,
          'file': fileId,
          'size': described.size,
          'chunks': described.totalChunks,
        },
      );
      if (described.size > min(config.maxFileBytes, adapter.maxFileBytes)) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'file_too_large',
          message: 'The file is larger than this device sends.',
        );
      }

      final init = await _retry(() => channel.init(<String, Object?>{'manifest': described.toJson()}));
      final initStatus = _statusOf(init);
      if (initStatus == FileTransferStatus.skipped) {
        _log.debug('the other device already holds the file', fields: {'file': fileId});
        return await _save(_record(_newId(), peer, described, FileTransferStatus.skipped));
      }
      final transferId = switch (init['transferId']) {
        final String id when id.isNotEmpty && id.length <= 128 => id,
        _ => throw LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'transfer_init_invalid',
          message: 'The receiving device answered without a transfer id.',
          deviceId: peer,
        ),
      };
      var current = record = await _save(
        _record(
          transferId,
          peer,
          described,
          initStatus == FileTransferStatus.completed ? FileTransferStatus.completed : FileTransferStatus.transferring,
          received: _indices(init['receivedChunks']),
        ),
      );
      if (current.isFinished) return current;

      final raf = await local.file.open();
      try {
        for (var index = 0; index < described.totalChunks; index++) {
          if (current.receivedChunks.contains(index)) continue;
          if (cancellation?.isCancelled ?? false) {
            try {
              await channel.cancel(transferId);
            } on LanSyncError {
              // The receiver purges abandoned transfers on its own.
            }
            return record = await _save(current.withStatus(FileTransferStatus.cancelled, _now().toUtc()));
          }
          await raf.setPosition(index * described.chunkSize);
          final bytes = await _readFully(raf, described.chunkLength(index));
          if (bytes.length != described.chunkLength(index) ||
              crypto.sha256.convert(bytes).toString() != described.chunkSha256[index]) {
            _log.error('the source file changed mid-send', fields: {'file': fileId});
            throw const LanSyncError(
              category: LanSyncErrorCategory.fileTransfer,
              code: 'source_changed',
              message: 'The file changed while it was being sent; send it again.',
            );
          }
          final answer = await _retry(() => channel.putChunk(transferId, index, bytes));
          final state = _statusOf(answer);
          current = record = await _save(
            current.withChunks({
              ...current.receivedChunks,
              index,
              ..._indices(answer['receivedChunks']),
            }, _now().toUtc()),
          );
          if (state == FileTransferStatus.completed) {
            return record = await _save(current.withStatus(FileTransferStatus.completed, _now().toUtc()));
          }
          if (state == FileTransferStatus.failed || state == FileTransferStatus.cancelled) {
            return record = await _save(
              current.withStatus(FileTransferStatus.failed, _now().toUtc(), error: _errorOf(answer)),
            );
          }
        }
      } finally {
        await raf.close();
      }

      // Every chunk is there but no completion was seen — they arrived in
      // an earlier session. Ask where the receiver stands.
      final status = await _retry(() => channel.status(transferId));
      final finalState = _statusOf(status);
      return record = await _save(
        finalState == FileTransferStatus.completed
            ? current.withStatus(FileTransferStatus.completed, _now().toUtc())
            : current.withStatus(FileTransferStatus.failed, _now().toUtc(), error: _errorOf(status)),
      );
    } on LanSyncError catch (error) {
      final failed = record ?? (manifest == null ? null : _record(_newId(), peer, manifest, FileTransferStatus.failed));
      if (failed == null) {
        return await _failedBeforeStart(peer, category, fileId, error);
      }
      return record = await _save(
        failed.withStatus(FileTransferStatus.failed, _now().toUtc(), error: '${error.code}: ${error.message}'),
      );
    } on FileSystemException catch (error) {
      final failure = _unreadable(error);
      final failed = record ?? (manifest == null ? null : _record(_newId(), peer, manifest, FileTransferStatus.failed));
      if (failed == null) {
        return await _failedBeforeStart(peer, category, fileId, failure);
      }
      return record = await _save(
        failed.withStatus(FileTransferStatus.failed, _now().toUtc(), error: '${failure.code}: ${failure.message}'),
      );
    }
  }

  /// Sends [fileIds] of [category], at most `config.maxConcurrentFiles` at
  /// once. Returns one record per file, in order.
  Future<List<FileTransferRecord>> sendAll({
    required PeerFileChannel channel,
    required String category,
    required List<String> fileIds,
    SyncCancellation? cancellation,
  }) async {
    final results = List<FileTransferRecord?>.filled(fileIds.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < fileIds.length) {
        final index = next++;
        results[index] = await send(
          channel: channel,
          category: category,
          fileId: fileIds[index],
          cancellation: cancellation,
        );
      }
    }

    await Future.wait([for (var i = 0; i < min(config.maxConcurrentFiles, fileIds.length); i++) worker()]);
    return [for (final result in results) result!];
  }

  /// Abandons [transferId]: asks the receiver to discard what it holds and
  /// records the transfer as cancelled here. Returns the record, or null
  /// when this device never sent it. A receiver that cannot be reached
  /// purges abandoned transfers on its own.
  Future<FileTransferRecord?> cancel(PeerFileChannel channel, String transferId) async {
    try {
      await _retry(() => channel.cancel(transferId));
    } on LanSyncError {
      // The receiver's housekeeping covers what this call could not.
    }
    final record = await store.fileTransfer(transferId);
    if (record == null || record.direction != FileTransferDirection.outgoing) return null;
    if (record.status == FileTransferStatus.completed || record.status == FileTransferStatus.skipped) return record;
    return await _save(record.withStatus(FileTransferStatus.cancelled, _now().toUtc()));
  }

  /// Closes the event stream.
  Future<void> dispose() => _events.close();

  Future<FileTransferRecord> _failedBeforeStart(String peer, String category, String fileId, LanSyncError error) async {
    // Nothing describes the file yet: record the attempt with an empty
    // manifest so the failure still shows in the transfer history.
    final placeholder = FileManifest(
      fileId: fileId,
      category: category,
      fileName: 'file',
      mimeType: 'application/octet-stream',
      size: 0,
      sha256: crypto.sha256.convert(const <int>[]).toString(),
      chunkSize: FileManifest.minChunkSize,
      chunkSha256: const <String>[],
    );
    return await _save(
      _record(
        _newId(),
        peer,
        placeholder,
        FileTransferStatus.failed,
      ).withStatus(FileTransferStatus.failed, _now().toUtc(), error: '${error.code}: ${error.message}'),
    );
  }

  FileTransferRecord _record(
    String transferId,
    String peer,
    FileManifest manifest,
    FileTransferStatus status, {
    List<int> received = const <int>[],
  }) {
    final at = _now().toUtc();
    return FileTransferRecord(
      transferId: transferId,
      peerDeviceId: peer,
      direction: FileTransferDirection.outgoing,
      manifest: manifest,
      status: status,
      createdAt: at,
      updatedAt: at,
      receivedChunks: {...received},
    );
  }

  Future<FileTransferRecord> _save(FileTransferRecord record) async {
    await store.saveFileTransfer(record);
    if (!_events.isClosed) {
      _events.add(FileTransferUpdated(record));
    }
    return record;
  }

  Future<T> _retry<T>(Future<T> Function() call) async {
    var attempt = 0;
    while (true) {
      try {
        return await call();
      } on LanSyncError catch (error) {
        if (!error.retryable || attempt >= maxRetries) rethrow;
        await _sleep(Duration(milliseconds: min(5000, 200 * (1 << attempt))));
        attempt++;
      }
    }
  }

  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return 'out-${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static FileTransferStatus? _statusOf(Map<String, Object?> answer) => switch (answer['status']) {
    final String name => FileTransferStatus.values.where((status) => status.name == name).firstOrNull,
    _ => null,
  };

  static String _errorOf(Map<String, Object?> answer) => switch (answer['error']) {
    final String error when error.isNotEmpty => error,
    _ => 'transfer_refused: the receiving device ended the transfer (${answer['status']}).',
  };

  static List<int> _indices(Object? value) => switch (value) {
    final List<Object?> list => [
      for (final item in list)
        if (item is num) item.toInt(),
    ],
    _ => const <int>[],
  };

  /// Reads exactly [length] bytes unless the file ends first.
  static Future<List<int>> _readFully(RandomAccessFile raf, int length) async {
    final builder = BytesBuilder(copy: false);
    while (builder.length < length) {
      final piece = await raf.read(length - builder.length);
      if (piece.isEmpty) break;
      builder.add(piece);
    }
    return builder.takeBytes();
  }

  static LanSyncError _unreadable(FileSystemException error) => LanSyncError(
    category: LanSyncErrorCategory.fileTransfer,
    code: 'file_unreadable',
    message: 'The file to send could not be read.',
    debugContext: error.message,
  );
}

/// Collects the single digest a chunked SHA-256 conversion produces.
final class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}
