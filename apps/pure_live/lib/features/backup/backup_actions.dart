import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, FileSystemException;

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile, LiveHttp;
import 'package:live_storage/live_storage.dart';
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory, getApplicationSupportDirectory;
import 'package:pure_live/app/providers/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/features/backup/backup_document.dart';
import 'package:pure_live/features/backup/backup_repository.dart';
import 'package:pure_live/features/backup/webdav_client.dart';
import 'package:pure_live/features/backup/webdav_settings.dart';

// The backup pane's actions, one function per row: capture the document,
// read and write it as a local file, apply a file or a downloaded one, and
// the three WebDAV verbs against the configured server.
//
// Failures surface as exceptions (`WebDavFailure` from the verbs, the
// rest as anything the file system or the store threw); the pane
// translates them into one toast each. A `null` document answer means
// "the payload was not a backup", distinct from a transport failure.

/// The pref key of the folder local backups live in; empty means the
/// default folder.
const String kBackupFolderPref = 'backup.dir';

/// The backup document built from the boxes and settings as they are now.
Future<BackupDocument> captureBackupDocument(WidgetRef ref, {BackupScope scope = BackupScope.all}) async {
  final repository = await ref.read(backupRepositoryProvider.future);
  return repository.capture(scope: scope);
}

/// Applies [document]: the boxes restore section by section and the
/// settings keys are written back. Parsing happens first
/// (`BackupDocument.tryDecode`), so the pane can confirm on the decoded
/// counts before anything is touched.
Future<void> applyBackup(WidgetRef ref, BackupDocument document) async {
  final repository = await ref.read(backupRepositoryProvider.future);
  await repository.apply(document);
}

// -- Local backup files ---------------------------------------------------

/// The folder the user picked, or '' when the default folder is in use.
String storedBackupFolder() => _stored(kBackupFolderPref).trim();

/// Stores [path] as the backup folder; '' resets it to the default.
Future<void> storeBackupFolder(String path) async {
  await StoragePrefs.setString(kBackupFolderPref, path);
}

/// The folder backups go to when the user picked none: `Documents/PureLive`,
/// then the app-support `backup` folder, then the temporary directory.
Future<Directory> defaultBackupFolder() async {
  final candidates = <Directory>[];
  if (await _tryDirectory(getApplicationDocumentsDirectory) case final documents?) {
    candidates.add(Directory(p.join(documents.path, 'PureLive')));
  }
  if (await _tryDirectory(getApplicationSupportDirectory) case final support?) {
    candidates.add(Directory(p.join(support.path, 'backup')));
  }
  for (final candidate in candidates) {
    if (await ensureWritableFolder(candidate)) return candidate;
  }
  return candidates.isNotEmpty ? candidates.last : Directory(p.join(Directory.systemTemp.path, 'PureLive'));
}

/// Whether files can be written in [folder] (made when missing).
Future<bool> ensureWritableFolder(Directory folder) async {
  try {
    await folder.create(recursive: true);
    final probe = File(p.join(folder.path, '.pure_live_probe'));
    await probe.writeAsString('');
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Opens the system directory picker; answers the chosen path, or null
/// when the user cancelled.
Future<String?> pickBackupDirectory({required String dialogTitle, String? initialDirectory}) =>
    FilePicker.getDirectoryPath(dialogTitle: dialogTitle, initialDirectory: initialDirectory);

/// A backup found in the backup folder.
final class LocalBackupFile {
  /// Creates the entry.
  const LocalBackupFile({required this.file, required this.modified, required this.size});

  /// The file.
  final File file;

  /// Last change.
  final DateTime modified;

  /// Size in bytes.
  final int size;

  /// The file name.
  String get name => p.basename(file.path);

  /// Whether the name says it is a follows-only backup.
  bool get followsOnly => name.toLowerCase().startsWith('pure_live_follows');
}

/// The backups in [folder] (`pure_live*.json`), newest first. Throws
/// [FileSystemException] when the folder cannot be read.
Future<List<LocalBackupFile>> listBackupFiles(Directory folder) async {
  if (!folder.existsSync()) return const [];
  final found = <LocalBackupFile>[];
  await for (final entity in folder.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path).toLowerCase();
    if (!name.startsWith('pure_live') || !name.endsWith('.json')) continue;
    try {
      final stat = entity.statSync();
      found.add(LocalBackupFile(file: entity, modified: stat.modified, size: stat.size));
    } on FileSystemException {
      continue;
    }
  }
  found.sort((a, b) => b.modified.compareTo(a.modified));
  return found;
}

/// Writes [document] into [folder] under its stamped file name, adding
/// `_2`, `_3` … when that name is taken. Answers the file written.
Future<File> writeBackupDocument(Directory folder, BackupDocument document) async {
  await folder.create(recursive: true);
  final name = BackupDocument.exportFileName(DateTime.now(), scope: document.scope);
  final file = freeBackupFile(folder, name);
  await file.writeAsString(document.encode(), flush: true);
  return file;
}

/// A file named [name] in [folder] that does not exist yet.
File freeBackupFile(Directory folder, String name) {
  final base = p.basenameWithoutExtension(name);
  final extension = p.extension(name);
  var file = File(p.join(folder.path, name));
  for (var i = 2; file.existsSync(); i++) {
    file = File(p.join(folder.path, '${base}_$i$extension'));
  }
  return file;
}

/// Reads [file] as a backup document; answers null when it is not one.
Future<BackupDocument?> readBackupDocument(File file) async {
  final bytes = await file.readAsBytes();
  return BackupDocument.tryDecode(utf8.decode(bytes, allowMalformed: true));
}

/// Deletes [file].
Future<void> deleteBackupFile(File file) => file.delete();

/// Reveals [folder] in the system file manager. Throws when the system
/// could not open it.
Future<void> openBackupFolder(Directory folder) async {
  final result = await OpenFile.open(folder.path);
  if (result.type != ResultType.done) throw StateError(result.message);
}

/// `yyyy-MM-dd HH:mm` in local time.
String formatBackupTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// Human-readable size: B, KB, MB.
String formatBackupSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

Future<Directory?> _tryDirectory(Future<Directory?> Function() find) async {
  try {
    return await find();
  } on Object {
    return null;
  }
}

// -- WebDAV sync ----------------------------------------------------------

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
  final client = await webDavClient(ref);
  await client.test();
}

/// Captures the current data and uploads it as the server's backup file,
/// replacing what is there. Throws a [StateError] when there is nothing
/// to upload.
Future<void> uploadBackupToWebDav(WidgetRef ref) async {
  final document = await captureBackupDocument(ref);
  if (document.isEmpty) throw StateError('nothing to back up');
  final client = await webDavClient(ref);
  await client.upload(utf8.encode(document.encode()));
}

/// Downloads the server's backup file and parses it. Answers the
/// document, or null when the payload is not a backup.
Future<BackupDocument?> downloadBackupFromWebDav(WidgetRef ref) async {
  final client = await webDavClient(ref);
  final bytes = await client.download();
  return BackupDocument.tryDecode(utf8.decode(bytes, allowMalformed: true));
}

/// The WebDAV client over the app's shared transport — the same
/// per-profile client every module's remote reads go through, so the
/// proxy settings apply. The factory caches it per profile; nobody closes
/// it here. Throws a [StateError] when no server is configured.
Future<WebDavBackupClient> webDavClient(WidgetRef ref) async {
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
