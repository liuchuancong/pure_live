// Module: lib/app/user_backup.dart
// Purpose: The user-data backup wiring: file-domain sources over the runtime's
// stores, built into a bundle and written to (or read from) a user-chosen file.
// Author: liuchuancong
// Created: 2026-10-10
//
// The backup engine (foundation/backup) is port-based and same-layer blind;
// this file is the composition root's adapter: it names the domains, reads and
// writes their files, and refuses credential-looking keys on both ends. After
// a restore the stores must be re-read, so the caller tells the user to
// restart instead of pretending the services hot-reloaded.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pure_live_backup/pure_live_backup.dart';

import 'runtime.dart';

/// The user-data domains a backup covers: one file per domain, the unit the
/// migrator and the backup both address (runtime.dart's store layout).
const List<({String name, String file})> backupDomains = <({String name, String file})>[
  (name: 'favorites', file: 'favorites.json'),
  (name: 'history', file: 'history.json'),
  (name: 'playlists', file: 'playlists.json'),
  (name: 'appearance', file: 'ui.json'),
];

/// True for keys that must never enter an archive. The file domains carry no
/// credentials by construction, but a hand-edited store could; the predicate
/// runs on both ends regardless.
bool _looksLikeCredential(String key) {
  final lowered = key.toLowerCase();
  return lowered.contains('cookie') ||
      lowered.contains('token') ||
      lowered.contains('secret') ||
      lowered.contains('password');
}

/// Builds the backup document over the runtime's stores.
Future<Map<String, Object?>> buildUserBackup(PureLiveRuntime runtime) async {
  final sources = <DomainSource>[
    for (final domain in backupDomains)
      _FileDomainSource(name: domain.name, file: File(p.join(runtime.dataDirectory.path, domain.file))),
  ];
  final bundle = await BackupEngine(
    sources: sources,
    isCredentialKey: _looksLikeCredential,
    appVersion: '4.0.0',
  ).build();
  return <String, Object?>{'manifest': bundle.manifest.toJson(), 'payload': bundle.payload};
}

/// Applies a backup document domain by domain. Returns the per-domain
/// outcome lines for the dialog, plus the credential keys the engine refused.
Future<(List<String>, int)> restoreUserBackup(PureLiveRuntime runtime, Map<String, Object?> document) async {
  final targets = <DomainTarget>[
    for (final domain in backupDomains)
      _FileDomainTarget(name: domain.name, file: File(p.join(runtime.dataDirectory.path, domain.file))),
  ];
  final bundle = BackupBundle(
    manifest: BackupManifest.fromJson(Map<String, Object?>.from(document['manifest']! as Map)),
    payload: Map<String, Map<String, Object?>>.fromEntries(
      (document['payload']! as Map).entries.map(
        (entry) => MapEntry('${entry.key}', Map<String, Object?>.from(entry.value as Map)),
      ),
    ),
  );
  final report = await RestoreEngine(targets: targets, isCredentialKey: _looksLikeCredential).apply(bundle);
  final outcomeNames = <DomainOutcome, String>{
    DomainOutcome.applied: '已恢复',
    DomainOutcome.skipped: '跳过(壳未覆盖此域)',
    DomainOutcome.failed: '失败',
  };
  return (
    <String>[
      for (final entry in report.results.entries) '${entry.key}: ${outcomeNames[entry.value] ?? entry.value.name}',
      if (report.skippedCredentials > 0) '已拒绝 ${report.skippedCredentials} 个疑似凭据键',
    ],
    report.skippedCredentials,
  );
}

/// Decodes a backup file's text into the document the restore expects, or
/// throws with the reason.
Map<String, Object?> decodeBackupDocument(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw const FormatException('备份文件不是 JSON 对象');
  }
  if (decoded['payload'] is! Map || decoded['manifest'] is! Map) {
    throw const FormatException('备份文件缺少 manifest 或 payload');
  }
  return Map<String, Object?>.from(decoded);
}

/// One domain's file, snapshotted as its raw JSON text. A missing file
/// snapshots as empty rather than failing the whole archive: a fresh install
/// has domains that simply have no data yet.
final class _FileDomainSource implements DomainSource {
  const _FileDomainSource({required this.name, required this.file});

  @override
  final String name;
  final File file;

  @override
  Future<Map<String, Object?>> snapshot() async {
    if (!await file.exists()) {
      return const <String, Object?>{};
    }
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    return decoded is Map ? Map<String, Object?>.from(decoded) : <String, Object?>{'raw': text};
  }
}

final class _FileDomainTarget implements DomainTarget {
  const _FileDomainTarget({required this.name, required this.file});

  @override
  final String name;
  final File file;

  @override
  Future<void> restore(Map<String, Object?> values) async {
    final payload = values['raw'] is String ? values['raw']! as String : jsonEncode(values);
    await file.parent.create(recursive: true);
    await file.writeAsString(payload, flush: true);
  }
}
