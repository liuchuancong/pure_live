// Module: lib/src/data/webdav_backup_service.dart
// Purpose: The backup orchestration the settings surface calls: build a
// bundle from the domain sources, push it to WebDAV, pull the newest snapshot
// back and apply it.
// Author: liuchuancong
// Created: 2026-10-10
//
// Glue over foundation/backup (engine + WebDavBackupStore) and the runtime's
// domain sources. The credential rule stays with the engine; the WebDAV
// account lives in the user's WebDAV account, never inside the document.

import 'dart:convert';

import 'package:pure_live_backup/pure_live_backup.dart';

/// One user-visible backup outcome line.
final class BackupOutcome {
  const BackupOutcome({required this.summary, this.remoteName});

  final String summary;
  final String? remoteName;
}

/// The orchestration service. [buildDocument] and [applyDocument] are the
/// host's own backup adapters (the app's file-domain wiring); the WebDAV
/// transport is injected so tests use a fake store.
final class WebDavBackupService {
  WebDavBackupService({
    required WebDavBackupStore store,
    required this.snapshotName,
    required this.buildDocument,
    required this.applyDocument,
  }) : _store = store;

  final WebDavBackupStore _store;

  /// The fixed snapshot name this service manages, for example
  /// `purelive-backup.json`.
  final String snapshotName;

  /// Builds the backup document from the host's domain sources.
  final Future<Map<String, Object?>> Function() buildDocument;

  /// Applies a restored document to the host's domains.
  final Future<List<String>> Function(Map<String, Object?> document) applyDocument;

  /// Builds and pushes the snapshot. Returns the outcome line.
  Future<BackupOutcome> push() async {
    final document = await buildDocument();
    await _store.upload(snapshotName, document);
    final domains = document['manifest'] is Map
        ? ((document['manifest']! as Map)['domains'] as List? ?? const []).length
        : 0;
    return BackupOutcome(summary: '已备份 $domains 个数据域', remoteName: snapshotName);
  }

  /// Pulls the snapshot and applies it. Returns the outcome lines.
  Future<List<String>> pull() async {
    final document = await _store.download(snapshotName);
    return applyDocument(document);
  }

  /// Lists remote snapshots by name, newest first.
  Future<List<String>> listRemote() async => <String>[for (final snapshot in await _store.list()) snapshot.name];

  /// Encodes a document for a local file export (the non-WebDAV path).
  String encodeLocal(Map<String, Object?> document) => const JsonEncoder.withIndent('  ').convert(document);

  /// Decodes a locally imported file.
  Map<String, Object?> decodeLocal(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('备份文件不是 JSON 对象');
    }
    return Map<String, Object?>.from(decoded);
  }
}
