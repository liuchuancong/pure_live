import 'dart:typed_data' show Uint8List;

import 'package:pure_live/features/backup/document/backup_document.dart' show BackupDocument;
import 'package:webdav_client_plus/webdav_client_plus.dart';

/// Why a WebDAV request failed.
enum WebDavProblem {
  /// The server refused the credentials (401, 403).
  auth,

  /// The folder or the backup file is not there (404, 409, 412).
  notFound,

  /// The server answered with something else.
  server,

  /// No answer (network, timeout, TLS, a closed transport).
  network,
}

/// A failed WebDAV request; the surface translates the problem into one
/// message.
final class WebDavFailure implements Exception {
  /// The failure with what went wrong and the status, when there was an
  /// answer.
  const WebDavFailure(this.problem, {this.status});

  /// What went wrong.
  final WebDavProblem problem;

  /// The HTTP status, when the server answered.
  final int? status;

  @override
  String toString() => 'WebDavFailure(${problem.name}, $status)';
}

/// One entry of a WebDAV collection: a folder or a file, with the size and
/// time the server gave.
///
/// [path] is the account-root-relative path the client takes back for every
/// other call, which is what lets the browser page build a breadcrumb out of
/// the list it just read.
final class WebDavEntry {
  /// Creates the entry.
  const WebDavEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
  });

  /// The display name, as the server spells it.
  final String name;

  /// The path below the account's root, without a trailing slash.
  final String path;

  /// Whether this is a collection.
  final bool isDirectory;

  /// The file size, when the server gave one.
  final int? size;

  /// The last modification time, when the server gave one.
  final DateTime? modified;
}

/// One WebDAV account's server, rooted at the collection the viewer named.
///
/// The protocol work belongs to `webdav_client_plus`; what is kept here is the
/// app's own vocabulary — the four failure kinds the pages have a message for,
/// folders-before-files ordering, and the root-relative paths the browser's
/// breadcrumb is built from.
///
/// The proxy is not this client's business: it builds a `dart:io` HTTP client,
/// and the app-wide `HttpOverrides` installed at start-up is what points that
/// client at the proxy the viewer configured.
final class WebDavBackupClient {
  /// The client for [url] (the collection the backup lives in), signed with
  /// [username] and [password]. An empty [username] means an anonymous server.
  WebDavBackupClient({required String url, required String username, required String password})
    : _client = username.isEmpty
          ? WebdavClient.noAuth(url: url.trim(), options: _options)
          : WebdavClient.basicAuth(url: url.trim(), user: username, pwd: password, options: _options);

  static const WebdavOptions _options = WebdavOptions(
    connectTimeout: Duration(seconds: 15),
    sendTimeout: Duration(seconds: 60),
    receiveTimeout: Duration(seconds: 60),
  );

  final WebdavClient _client;

  /// The account's root, as the client sees it: `/`.
  static const String root = '/';

  /// The backup file's path below the root.
  static String get backupPath => '/${BackupDocument.backupFileName}';

  /// Checks the server: listing the root answers reachability and the
  /// credentials in one round trip.
  Future<void> test() => _guard(() => _client.readDir(root, depth: PropsDepth.zero));

  /// Lists [path] (the root when null): folders first, then files, each group
  /// in the server's own order.
  Future<List<WebDavEntry>> list({String path = root}) async {
    final files = await _guard(() => _client.readDir(path));
    final entries = [
      for (final file in files)
        if (file.name.trim().isNotEmpty)
          WebDavEntry(
            name: file.name,
            path: _rooted(file.path, file.name, isDirectory: file.isDir),
            isDirectory: file.isDir,
            size: file.size,
            modified: file.modified,
          ),
    ]..sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Reads one file's bytes.
  Future<Uint8List> readFile(String path) => _guard(() => _client.read(path));

  /// Writes [bytes] at [path], replacing what is there.
  Future<void> writeFile(String path, List<int> bytes) =>
      _guard(() => _client.write(path, bytes is Uint8List ? bytes : Uint8List.fromList(bytes)));

  /// Creates a folder; the parent must already exist, which is what the
  /// browser's own error message is for.
  Future<void> createFolder(String path) => _guard(() => _client.mkdir(path));

  /// Deletes one entry. A collection's path keeps its trailing slash, which
  /// several servers insist on.
  Future<void> delete(WebDavEntry entry) =>
      _guard(() => _client.remove(entry.isDirectory ? '${entry.path}/' : entry.path));

  /// Reads the backup file.
  Future<Uint8List> download() => readFile(backupPath);

  /// Writes the backup file.
  Future<void> upload(List<int> bytes) => writeFile(backupPath, bytes);

  /// The path a listing answers with, made root-relative.
  ///
  /// The client reports either a base-relative path or a full href depending on
  /// what the server put in its PROPFIND body, and a name is always available;
  /// the parent the caller asked for is the one thing both forms agree on.
  static String _rooted(String reported, String name, {required bool isDirectory}) {
    final trimmed = reported.trim();
    final asPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    if (trimmed.isNotEmpty && !trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return isDirectory && asPath.endsWith('/') ? asPath.substring(0, asPath.length - 1) : asPath;
    }
    final suffix = isDirectory ? '/' : '';
    return '/${name.trim()}$suffix';
  }

  /// Runs one call and turns whatever it throws into the app's own failure.
  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on WebdavException catch (error) {
      throw WebDavFailure(_problemOf(error.statusCode), status: error.statusCode);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw WebDavFailure(status == null ? WebDavProblem.network : _problemOf(status), status: status);
    } on WebDavFailure {
      rethrow;
    } on Object {
      throw const WebDavFailure(WebDavProblem.network);
    }
  }

  static WebDavProblem _problemOf(int? status) => switch (status) {
    401 || 403 => WebDavProblem.auth,
    404 || 409 || 412 => WebDavProblem.notFound,
    null => WebDavProblem.network,
    _ => WebDavProblem.server,
  };
}
