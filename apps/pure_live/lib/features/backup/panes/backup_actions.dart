import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, FileSystemException;

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory, getApplicationSupportDirectory;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart';
import 'package:pure_live/features/backup/webdav/webdav_client.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show webDavVault;

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

/// The backup document built from the stores and settings as they are now.
Future<BackupDocument> captureBackupDocument(WidgetRef ref, {BackupScope scope = BackupScope.all}) async {
  final repository = await ref.read(backupRepositoryProvider.future);
  return repository.capture(scope: scope);
}

/// Applies [document]: the stores restore section by section and the
/// settings keys are written back. Parsing happens first
/// (`BackupDocument.tryDecode`), so the pane can confirm on the decoded
/// counts before anything is touched.
Future<void> applyBackup(WidgetRef ref, BackupDocument document) async {
  final repository = await ref.read(backupRepositoryProvider.future);
  await repository.apply(document);
  // The restore writes prefs directly rather than through the settings
  // controllers, so this window must re-read them too; the other windows
  // hear the same writes over the store's change stream.
  if (document.scope != BackupScope.follows && document.hasSettings) {
    refreshSettingsFromWidget(ref);
  }
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

/// The client for one saved account, its password read from the vault.
///
/// A vault that never opened leaves the password empty; the server then
/// answers 401 and the page says so, which is the reference's behaviour.
Future<WebDavBackupClient> webDavClientFor(WidgetRef ref, WebDavAccount account) async {
  return WebDavBackupClient(
    url: account.url,
    username: account.user,
    password: await readAccountPassword(await webDavVault(ref), account.id),
  );
}

/// The client for the account the pages have selected.
///
/// Throws a [StateError] when no account is saved, which is what the pages'
/// one "先填写服务器地址" message already keys on.
Future<WebDavBackupClient> webDavClient(WidgetRef ref) async {
  final account = ref.read(webdavAccountsProvider.notifier).current;
  if (account == null) throw StateError('no WebDAV server configured');
  return await webDavClientFor(ref, account);
}

/// Asks the selected server whether it answers and the credentials hold.
/// Throws [WebDavFailure] with the reason when it does not, and a
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

String _stored(String key) {
  try {
    return StoragePrefs.getString(key) ?? '';
  } on Object {
    return '';
  }
}
