/// File transfer parameters.
///
/// The engine streams files in chunks with checksums on by default; a
/// corrupted file must never be committed, and an interrupted transfer must
/// be resumable without starting over.
final class LanSyncTransferConfig {
  /// The transfer defaults.
  const new({
    this.chunkBytes = 2 * 1024 * 1024,
    this.maxConcurrentFiles = 2,
    this.maxFileBytes = 2 * 1024 * 1024 * 1024,
    this.maxTotalBytes = 8 * 1024 * 1024 * 1024,
    this.resumeEnabled = true,
    this.verifyChunkHash = true,
    this.verifyFileHash = true,
    this.transferTimeout = const Duration(minutes: 5),
  });

  /// The chunk size in bytes. Small enough to retry cheaply, large enough
  /// to keep request overhead low.
  final int chunkBytes;

  /// The most files transferred at once per task.
  final int maxConcurrentFiles;

  /// The largest single file accepted; larger ones are refused up front.
  final int maxFileBytes;

  /// The total transfer space one task may consume.
  final int maxTotalBytes;

  /// Whether interrupted transfers keep their partial state for resuming.
  final bool resumeEnabled;

  /// Whether every chunk is checksummed as it lands.
  final bool verifyChunkHash;

  /// Whether the assembled file is hashed before it is committed.
  final bool verifyFileHash;

  /// How long a stalled transfer may sit before it is failed.
  final Duration transferTimeout;

  /// Returns the human-readable problems with this configuration, or an
  /// empty list when it is usable as is.
  List<String> validate() {
    const kib = 1024;
    final problems = <String>[];
    if (chunkBytes < 64 * kib || chunkBytes > 16 * kib * kib) {
      problems.add('transfer.chunkBytes must be 64 KiB..16 MiB');
    }
    if (maxConcurrentFiles < 1) {
      problems.add('transfer.maxConcurrentFiles must be at least 1');
    }
    if (maxFileBytes < chunkBytes) {
      problems.add('transfer.maxFileBytes must not be below chunkBytes');
    }
    if (maxTotalBytes < maxFileBytes) {
      problems.add('transfer.maxTotalBytes must not be below maxFileBytes');
    }
    if (!verifyFileHash) {
      problems.add('transfer.verifyFileHash must stay enabled: an unverified file must never commit');
    }
    if (transferTimeout <= Duration.zero) {
      problems.add('transfer.transferTimeout must be positive');
    }
    return problems;
  }
}
