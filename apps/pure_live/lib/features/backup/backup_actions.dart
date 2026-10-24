import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttp;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/features/backup/backup_document.dart';
import 'package:pure_live/features/backup/backup_repository.dart';
import 'package:pure_live/features/backup/webdav_client.dart';
import 'package:pure_live/features/backup/webdav_settings.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

// The backup pane's actions, one function per row: capture and export the
// document, apply a pasted or downloaded one, and the three WebDAV verbs
// against the configured server.
//
// Failures surface as exceptions (`WebDavFailure` from the verbs, the
// rest as anything the capture or the store threw); the pane translates
// them into one toast each. A `null` document answer means "the payload
// was not a backup", distinct from a transport failure.

/// The backup document built from the boxes and settings as they are now.
Future<BackupDocument> captureBackupDocument(WidgetRef ref) async {
  final repository = await ref.read(backupRepositoryProvider.future);
  return repository.capture();
}

/// Exports the current data through the system share panel as one JSON
/// file. Answers false when there is nothing to back up; rethrows what
/// the share sheet throws.
Future<bool> exportBackup(WidgetRef ref) async {
  final document = await captureBackupDocument(ref);
  if (document.isEmpty) return false;
  final bytes = Uint8List.fromList(utf8.encode(document.encode()));
  final name = BackupDocument.exportFileName(DateTime.now());
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'application/json')],
      // `XFile.fromData`'s own name is ignored off the web; the override
      // is what names the file on every platform.
      fileNameOverrides: [name],
    ),
  );
  return true;
}

/// Applies [document]: the boxes restore section by section and the
/// settings keys are written back. Parsing happens first
/// (`BackupDocument.tryDecode`), so the pane can confirm on the decoded
/// counts before anything is touched.
Future<void> applyBackup(WidgetRef ref, BackupDocument document) async {
  final repository = await ref.read(backupRepositoryProvider.future);
  await repository.apply(document);
}

/// The configured WebDAV connection, or null when no server URL is
/// stored. The password comes from the secret vault; a vault that never
/// opened leaves it empty (the server then answers 401 and the pane says
/// so).
Future<({String url, String username, String password})?> webdavCredentials(WidgetRef ref) async {
  final url = _stored(kWebDavUrlPref).trim();
  if (url.isEmpty) return null;
  var password = '';
  try {
    final store = await ref.read(webdavSecretStoreProvider.future);
    password = store.value(SecretRefs.webdav(kWebDavVault)) ?? '';
  } on Object {
    // The vault failed to open; the empty password fails auth loudly.
  }
  return (url: url, username: _stored(kWebDavUserPref), password: password);
}

/// Asks the configured server whether it answers and the credentials
/// hold. Throws [WebDavFailure] with the reason when it does not, and a
/// [StateError] when no server is configured.
Future<void> testWebDav(WidgetRef ref) async {
  final client = await _client(ref);
  await client.test();
}

/// Captures the current data and uploads it as the server's backup file,
/// replacing what is there. Throws a [StateError] when there is nothing
/// to upload.
Future<void> uploadBackupToWebDav(WidgetRef ref) async {
  final document = await captureBackupDocument(ref);
  if (document.isEmpty) throw StateError('nothing to back up');
  final client = await _client(ref);
  await client.upload(utf8.encode(document.encode()));
}

/// Downloads the server's backup file and parses it. Answers the
/// document, or null when the payload is not a backup.
Future<BackupDocument?> downloadBackupFromWebDav(WidgetRef ref) async {
  final client = await _client(ref);
  final bytes = await client.download();
  return BackupDocument.tryDecode(utf8.decode(bytes, allowMalformed: true));
}

/// The WebDAV client over the app's shared transport — the same
/// per-profile client every module's remote reads go through, so the
/// proxy settings apply. The factory caches it per profile; nobody closes
/// it here.
Future<WebDavBackupClient> _client(WidgetRef ref) async {
  final credentials = await webdavCredentials(ref);
  if (credentials == null) throw StateError('no WebDAV server configured');
  return WebDavBackupClient(
    _sharedHttp(ref),
    baseUrl: credentials.url,
    username: credentials.username,
    password: credentials.password,
  );
}

/// The shared `ClientProfile.api` client the app routes its remote reads
/// through (see `networkFactoryProvider`).
LiveHttp _sharedHttp(WidgetRef ref) => ref.read(networkFactoryProvider).create(profile: ClientProfile.api);

String _stored(String key) {
  try {
    return StoragePrefs.getString(key) ?? '';
  } on Object {
    return '';
  }
}
