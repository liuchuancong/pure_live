// Module: lib/src/data/webdav_backup_service.dart
// Purpose: The backup the settings surface drives: push today's state, list what is remote, restore one archive.
// Author: liuchuancong
// Created: 2026-10-10
//
// Glue over foundation/backup - the engines own the domain list and the credential refusal, the transport
// owns WebDAV - so this file's own job is only the parts neither of them can know: which snapshot this app
// considers *the* snapshot, what a listing means to a person, and how a failed transfer is reported.
//
// The snapshot name is treated as untrusted input. It becomes a path component on someone's WebDAV server,
// and a name like `../../other-app/state.json` would silently move a backup out of its directory - the
// engine's credential rules protect the contents, and nothing protected the location until now.

import 'package:pure_live_backup/pure_live_backup.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import '../domain/backup_reports.dart';
import '../domain/snapshot_remote.dart';
import 'backup_document.dart';

/// The operations the account and settings surfaces call.
abstract interface class BackupService {
  /// Builds an archive from the host's domains and writes it to [WebDavBackupService.snapshotName],
  /// overwriting that snapshot - "save again" means what it always meant.
  Future<ArchiveContents> push();

  /// What the archive about to be pushed would contain, without uploading it.
  Future<ArchiveContents> preview();

  /// Remote snapshots, newest first.
  Future<List<RemoteSnapshot>> listRemote();

  /// Reads one remote archive without applying it.
  Future<ArchiveContents> inspect(String snapshotName);

  /// Applies one remote archive.
  Future<BackupRestoreReport> restore(String snapshotName);

  /// Applies the newest remote archive.
  Future<BackupRestoreReport> restoreNewest();

  /// Retries only the domains [previous] reported as failed.
  Future<BackupRestoreReport> retry(BackupBundle bundle, BackupRestoreReport previous);
}

/// A [BackupService] over a [SnapshotRemote], [BackupEngine] and [RestoreEngine].
final class WebDavBackupService implements BackupService {
  WebDavBackupService({
    required SnapshotRemote remote,
    required BackupEngine engine,
    required RestoreEngine restoreEngine,
    required String snapshotName,
    this.supportedSchemaVersions = const <int>{1},
  }) : _remote = remote,
       _engine = engine,
       _restore = restoreEngine,
       snapshotName = _validateSnapshotName(snapshotName);

  final SnapshotRemote _remote;
  final BackupEngine _engine;
  final RestoreEngine _restore;

  /// The single snapshot this service treats as the app's own, e.g. `purelive-backup.json`.
  final String snapshotName;

  /// Schema versions this build will read. Widening it belongs with a migration, not with a failed read.
  final Set<int> supportedSchemaVersions;

  @override
  Future<ArchiveContents> preview() async => ArchiveContents.of(snapshotName, await _engine.build());

  @override
  Future<ArchiveContents> push() async {
    // The summary comes from the typed bundle *before* the upload, so reporting can never depend on
    // re-parsing a document shape the transport happened to accept.
    final bundle = await _engine.build();
    final contents = ArchiveContents.of(snapshotName, bundle);
    try {
      await _remote.upload(snapshotName, encodeBackupBundle(bundle));
    } on Object catch (error) {
      throw BackupServiceFailure('the archive for "$snapshotName" did not reach the server', cause: error);
    }
    return contents;
  }

  @override
  Future<List<RemoteSnapshot>> listRemote() async {
    final listed = <RemoteSnapshot>[
      for (final snapshot in await _remote.list())
        RemoteSnapshot(name: snapshot.name, size: ByteSize(snapshot.sizeBytes), modifiedAt: snapshot.modifiedAt),
    ];
    // The transport returns whatever order the server produced. "Newest first" is a promise made here, so it
    // is sorted here rather than hoped for.
    listed.sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return List<RemoteSnapshot>.unmodifiable(listed);
  }

  @override
  Future<ArchiveContents> inspect(String snapshotName) async =>
      ArchiveContents.of(snapshotName, await _download(snapshotName));

  @override
  Future<BackupRestoreReport> restore(String snapshotName) async => _apply(await _download(snapshotName));

  @override
  Future<BackupRestoreReport> restoreNewest() async {
    final remote = await listRemote();
    if (remote.isEmpty) {
      throw BackupServiceFailure('the server has no snapshot to restore yet');
    }
    return restore(remote.first.name);
  }

  @override
  Future<BackupRestoreReport> retry(BackupBundle bundle, BackupRestoreReport previous) async {
    if (previous.retrySet.isEmpty) {
      // Retrying a complete restore would touch every domain again; the report is returned untouched so a
      // caller that meant a full re-apply has to say so by calling restore().
      return previous;
    }
    return _apply(bundle, onlyDomains: previous.retrySet);
  }

  Future<BackupBundle> _download(String name) async {
    final Map<String, Object?> document;
    try {
      document = await _remote.download(name);
    } on Object catch (error) {
      throw BackupServiceFailure('the archive "$name" could not be read from the server', cause: error);
    }
    return decodeBackupDocument(document, supportedSchemaVersions: supportedSchemaVersions);
  }

  Future<BackupRestoreReport> _apply(BackupBundle bundle, {Set<String>? onlyDomains}) async {
    final RestoreReport report;
    try {
      report = await _restore.apply(bundle, onlyDomains: onlyDomains);
    } on FormatException catch (error) {
      // The engine re-validates at apply time; it surfaces as this package's failure type so a caller does
      // not have to know which layer of the stack refused.
      throw BackupFormatFailure('the archive was refused at apply time', cause: error);
    }
    return BackupRestoreReport.from(report);
  }

  static String _validateSnapshotName(String raw) {
    final name = requireNonBlank(raw, name: 'snapshotName');
    if (name.contains('/') || name.contains(r'\') || name.contains('..') || name.codeUnits.any((unit) => unit < 0x20)) {
      throw BackupServiceFailure('"$raw" cannot be a snapshot name: it would leave the backup directory');
    }
    return name;
  }
}
