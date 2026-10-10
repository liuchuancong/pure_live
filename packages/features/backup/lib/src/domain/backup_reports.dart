// Module: lib/src/domain/backup_reports.dart
// Purpose: What a backup or a restore reports back, as data rather than as a sentence.
// Author: liuchuancong
// Created: 2026-10-10
//
// The version this replaces returned `summary: '已备份 3 个数据域'` from a data-layer method. Three problems
// followed from that: the string could not be translated, a screen could not show the domain count without
// parsing its own text back out, and the sentence was built by casting `document['manifest']['domains']`
// *after* a successful upload - so a manifest shape change made a backup that had already landed report as
// a failure, which is the one outcome a user must never be lied about in either direction.
//
// Everything here is numbers and names. The UI decides the sentence.

import 'package:pure_live_backup/pure_live_backup.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// What one archive holds, named by the snapshot it came from.
final class ArchiveContents {
  const ArchiveContents({
    required this.snapshotName,
    required this.domains,
    required this.keyCount,
    required this.totalBytes,
    required this.createdAt,
  });

  /// The snapshot this was read from or written to.
  final String snapshotName;

  /// The domain names in the archive, in manifest order.
  final List<String> domains;

  /// Keys across all domains, credential keys excluded by the engine.
  final int keyCount;

  /// The manifest's own size estimate; see `BackupManifest.totalBytes`.
  final int totalBytes;

  final DateTime createdAt;

  factory ArchiveContents.of(String snapshotName, BackupBundle bundle) => ArchiveContents(
    snapshotName: snapshotName,
    domains: bundle.manifest.domainNames,
    keyCount: bundle.manifest.domains.fold(0, (sum, domain) => sum + domain.keyCount),
    totalBytes: bundle.manifest.totalBytes,
    createdAt: bundle.manifest.createdAt,
  );

  @override
  String toString() => 'ArchiveContents($snapshotName, ${domains.length} domains, $totalBytes bytes)';
}

/// What a restore touched, per domain.
final class BackupRestoreReport {
  const BackupRestoreReport({
    required this.applied,
    required this.skipped,
    required this.failed,
    required this.refusedCredentialKeys,
  });

  final List<String> applied;
  final List<String> skipped;
  final List<String> failed;

  /// Keys the archive carried that belong to the credential store, and were therefore not applied.
  final int refusedCredentialKeys;

  bool get isComplete => failed.isEmpty;

  factory BackupRestoreReport.from(RestoreReport report) => BackupRestoreReport(
    applied: report.appliedDomains,
    skipped: report.results.entries
        .where((entry) => entry.value == DomainOutcome.skipped)
        .map((entry) => entry.key)
        .toList(),
    failed: report.failedDomains,
    refusedCredentialKeys: report.skippedCredentials,
  );

  /// The domains a retry should try again, empty when nothing failed.
  Set<String> get retrySet => Set<String>.unmodifiable(failed);

  @override
  String toString() =>
      'BackupRestoreReport(applied=${applied.length}, skipped=${skipped.length}, failed=${failed.length})';
}

/// A remote snapshot as the list screen shows it.
final class RemoteSnapshot {
  const RemoteSnapshot({required this.name, required this.size, required this.modifiedAt});

  final String name;
  final ByteSize size;
  final DateTime modifiedAt;
}

/// A backup or restore could not be carried out.
final class BackupServiceFailure extends DomainFailure {
  const BackupServiceFailure(super.reason, {super.cause});
}

/// The document handed over was not a backup this build understands.
final class BackupFormatFailure extends DomainFailure {
  const BackupFormatFailure(super.reason, {super.cause});
}
