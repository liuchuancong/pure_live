// Module: lib/src/domain/snapshot_remote.dart
// Purpose: The narrow remote the backup service actually needs, so a transfer can be tested without a server.
// Author: liuchuancong
// Created: 2026-10-10
//
// `WebDavBackupStore` is a final class in foundation/backup, so nothing outside that library can substitute
// it - which is why the previous version of this service, whose own comment promised "the transport is
// injected so tests use a fake store", could not in fact be tested against any transport at all. A one-line
// port restores the property the comment claimed: the adapter wraps the real store, and a test hands in a
// fake without touching WebDAV.

/// An archive stored on a remote.
abstract interface class SnapshotRemote {
  /// Writes [document] under [name], replacing what was there.
  Future<void> upload(String name, Map<String, Object?> document);

  /// Reads [name]. A missing snapshot is a failure, not an empty document.
  Future<Map<String, Object?>> download(String name);

  /// Everything stored in the backup directory, in whatever order the server produced it.
  Future<List<SnapshotListing>> list();
}

/// One remote archive as the server described it.
final class SnapshotListing {
  const SnapshotListing({required this.name, required this.sizeBytes, required this.modifiedAt});

  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
}
