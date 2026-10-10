// Module: lib/src/data/webdav_snapshot_remote.dart
// Purpose: The SnapshotRemote adapter over the foundation package's WebDAV store.
// Author: liuchuancong
// Created: 2026-10-10
//
// Deliberately thin: it maps types and nothing else. Path construction, credentials and the WebDAV protocol
// stay inside `WebDavBackupStore`, because docs/security/credential-storage.md keeps the WebDAV password in
// the credential store and out of anything this layer builds.

import 'package:pure_live_backup/pure_live_backup.dart';

import '../domain/snapshot_remote.dart';

/// Wraps a bound [WebDavBackupStore].
final class WebDavSnapshotRemote implements SnapshotRemote {
  const WebDavSnapshotRemote({required WebDavBackupStore store}) : _store = store;

  final WebDavBackupStore _store;

  @override
  Future<void> upload(String name, Map<String, Object?> document) => _store.upload(name, document);

  @override
  Future<Map<String, Object?>> download(String name) => _store.download(name);

  @override
  Future<List<SnapshotListing>> list() async => <SnapshotListing>[
    for (final snapshot in await _store.list())
      SnapshotListing(name: snapshot.name, sizeBytes: snapshot.sizeBytes, modifiedAt: snapshot.modifiedAt),
  ];
}
