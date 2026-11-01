import 'package:live_lan_sync/src/domain/transfer/file_manifest.dart';

/// Which way a transfer moves relative to this device.
enum FileTransferDirection {
  /// A peer sends a file here.
  incoming,

  /// This device sends a file to a peer.
  outgoing,
}

/// Where a transfer stands.
enum FileTransferStatus {
  /// Registered; no chunk has moved yet.
  pending,

  /// Chunks are moving.
  transferring,

  /// Every chunk is here; the whole file is being checked.
  verifying,

  /// The file was verified and committed where its adapter decided.
  completed,

  /// The receiver already held the same content; nothing moved.
  skipped,

  /// The transfer failed; [FileTransferRecord.error] says why.
  failed,

  /// The transfer was cancelled; partial data is gone.
  cancelled,
}

/// The persisted state of one file transfer (spec §15.2): which chunks are
/// durably here, so an interrupted transfer — or a restarted app — resumes
/// with exactly the chunks still missing.
final class FileTransferRecord {
  /// One transfer's state.
  const new({
    required this.transferId,
    required this.peerDeviceId,
    required this.direction,
    required this.manifest,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.receivedChunks = const <int>{},
    this.error,
  });

  /// Restores a record persisted through [toJson].
  factory fromJson(Map<String, Object?> json) => FileTransferRecord(
    transferId: json['transferId']! as String,
    peerDeviceId: json['peerDeviceId']! as String,
    direction: FileTransferDirection.values.byName(json['direction']! as String),
    manifest: FileManifest.fromJson((json['manifest']! as Map<Object?, Object?>).cast<String, Object?>()),
    status: FileTransferStatus.values.byName(json['status']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    receivedChunks: {for (final index in json['receivedChunks']! as List<Object?>) (index! as num).toInt()},
    error: switch (json['error']) {
      final String value => value,
      _ => null,
    },
  );

  /// The transfer's id, assigned by the receiver.
  final String transferId;

  /// The device on the other end.
  final String peerDeviceId;

  /// Which way the file moves.
  final FileTransferDirection direction;

  /// The file being moved.
  final FileManifest manifest;

  /// Where the transfer stands.
  final FileTransferStatus status;

  /// When the transfer was registered.
  final DateTime createdAt;

  /// When anything about it last changed.
  final DateTime updatedAt;

  /// The chunk indices durably received (incoming) or acknowledged
  /// (outgoing).
  final Set<int> receivedChunks;

  /// What went wrong, when [status] is failed. Never carries paths or
  /// secrets.
  final String? error;

  /// Whether the transfer reached an end state.
  bool get isFinished => switch (status) {
    FileTransferStatus.completed ||
    FileTransferStatus.skipped ||
    FileTransferStatus.failed ||
    FileTransferStatus.cancelled => true,
    _ => false,
  };

  /// Bytes durably moved so far.
  int get transferredBytes => receivedChunks.fold(0, (sum, index) => sum + manifest.chunkLength(index));

  /// Progress in 0.0..1.0; an empty file is done when it is done.
  double get progress =>
      manifest.size == 0 ? (isFinished ? 1 : 0) : (transferredBytes / manifest.size).clamp(0, 1).toDouble();

  /// A copy with [index] recorded as received.
  FileTransferRecord withChunk(int index, DateTime at) =>
      _copy(status: FileTransferStatus.transferring, updatedAt: at, receivedChunks: {...receivedChunks, index});

  /// A copy in [status], with [error] when it failed.
  FileTransferRecord withStatus(FileTransferStatus status, DateTime at, {String? error}) =>
      _copy(status: status, updatedAt: at, error: error);

  /// A copy whose received chunks are exactly [chunks].
  FileTransferRecord withChunks(Set<int> chunks, DateTime at) => _copy(updatedAt: at, receivedChunks: chunks);

  /// The JSON form persisted in the host's store.
  Map<String, Object?> toJson() => <String, Object?>{
    'transferId': transferId,
    'peerDeviceId': peerDeviceId,
    'direction': direction.name,
    'manifest': manifest.toJson(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'receivedChunks': (receivedChunks.toList()..sort()),
    'error': error,
  };

  FileTransferRecord _copy({
    required DateTime updatedAt,
    FileTransferStatus? status,
    Set<int>? receivedChunks,
    String? error,
  }) => FileTransferRecord(
    transferId: transferId,
    peerDeviceId: peerDeviceId,
    direction: direction,
    manifest: manifest,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    receivedChunks: receivedChunks ?? this.receivedChunks,
    error: error ?? this.error,
  );

  @override
  String toString() =>
      'FileTransferRecord($transferId, ${direction.name}, ${status.name}, '
      '${receivedChunks.length}/${manifest.totalChunks})';
}
