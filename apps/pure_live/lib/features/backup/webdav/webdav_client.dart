import 'dart:convert' show base64Encode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, TransportFailure;
import 'package:pure_live/features/backup/document/backup_document.dart' show BackupDocument;

/// Why a WebDAV request failed.
enum WebDavProblem {
  /// The server refused the credentials (401, 403).
  auth,

  /// The folder or the backup file is not there (404, 409).
  notFound,

  /// The server answered with something else.
  server,

  /// No answer (network, timeout, TLS, a closed transport).
  network,
}

/// A failed WebDAV request; the pane translates the problem into one
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

/// One entry of a WebDAV collection: a folder (its [name] ends in `/` and
/// its [uri] in `/`) or a file, with the size and time the server gave.
final class WebDavEntry {
  /// Creates the entry.
  const WebDavEntry({required this.name, required this.uri, required this.isDirectory, this.size, this.modified});

  /// The display name; a folder's ends in `/`.
  final String name;

  /// The address to list (folder) or fetch/delete (file).
  final Uri uri;

  /// Whether this is a collection.
  final bool isDirectory;

  /// The file size, when the server gave one.
  final int? size;

  /// The last modification time, when the server gave one.
  final DateTime? modified;
}

/// The three WebDAV verbs the backup pane needs — `PROPFIND` (test the
/// server), `PUT` (upload the backup) and `GET` (download it) — over the
/// app's shared [LiveHttp], so the proxy settings apply like to every
/// other module's remote reads.
///
/// Authentication is a Basic header built from the stored credentials,
/// what Jianguoyun, Nextcloud and Alist ask for.
final class WebDavBackupClient {
  /// The client for the server at [baseUrl] (the collection the backup
  /// file lives in), signed with [username] and [password].
  WebDavBackupClient(this._http, {required this.baseUrl, required this.username, required this.password});

  final LiveHttp _http;

  /// The server's collection address.
  final String baseUrl;

  /// The account's name, empty on anonymous servers.
  final String username;

  /// The account's password, from the secret vault.
  final String password;

  /// The configured collection as a directory [Uri]: a trailing slash is
  /// added when missing, so a child name resolves below it.
  Uri get directory => _base;

  /// The base as a directory [Uri]: a trailing slash is added when
  /// missing, so the file name resolves below the collection and never
  /// replaces its last segment.
  Uri get _base {
    final parsed = Uri.parse(baseUrl.trim());
    final path = parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/';
    return parsed.replace(path: path);
  }

  /// The backup file's address below the collection.
  Uri get _fileUrl => _base.resolve(BackupDocument.backupFileName);

  /// The Basic authorization header's value.
  String get _authorization => 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  /// Checks the server: a `PROPFIND` on the collection itself (depth 0)
  /// answers reachability and the credentials in one round trip; the
  /// backup file may still not exist.
  Future<void> test() => _send('PROPFIND', _base, headers: _propfindHeaders, body: _propfindBody);

  /// Lists [directory] (the configured collection when null): folders and
  /// files, folders first, names in the server's own order within each
  /// group. A `PROPFIND` with depth 1.
  Future<List<WebDavEntry>> list({Uri? directory}) async {
    final url = _directoryUrl(directory ?? _base);
    final response = await _send('PROPFIND', url, headers: _listHeaders, body: _listBody);
    final entries = <WebDavEntry>[];
    for (final block in _responseBlocks(response.text)) {
      final href = _hrefOf(block);
      if (href == null) continue;
      final uri = _resolveHref(url, href);
      // The collection itself answers too: its href ends in the same path.
      if (uri.path == url.path || '${uri.path}/' == url.path) continue;
      final name = Uri.decodeComponent(uri.pathSegments.isEmpty ? '' : uri.pathSegments.last).trim();
      if (name.isEmpty) continue;
      final isDirectory =
          block.contains(':collection') || RegExp(r'<[^>]*collection\b', caseSensitive: false).hasMatch(block);
      final size = RegExp(
        r'<[^>]*getcontentlength[^>]*>\s*(\d+)\s*<',
        caseSensitive: false,
      ).firstMatch(block)?.group(1);
      final modified = RegExp(
        r'<[^>]*getlastmodified[^>]*>\s*([^<]+)\s*<',
        caseSensitive: false,
      ).firstMatch(block)?.group(1)?.trim();
      entries.add(
        WebDavEntry(
          name: isDirectory ? '$name/' : name,
          uri: isDirectory ? _directoryUrl(uri) : uri,
          isDirectory: isDirectory,
          size: int.tryParse(size ?? ''),
          modified: modified == null ? null : DateTime.tryParse(modified),
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Reads [url]'s bytes (a `GET` on a listed file).
  Future<List<int>> downloadFile(Uri url) async => (await _send('GET', url)).bodyBytes;

  /// Writes [bytes] at [url] (a `PUT`, replacing what is there).
  Future<void> uploadFile(Uri url, List<int> bytes) =>
      _send('PUT', url, headers: {'content-type': 'application/json; charset=utf-8'}, body: bytes);

  /// Deletes [url] (a `DELETE`).
  Future<void> deleteFile(Uri url) => _send('DELETE', url);

  /// Reads the backup file's bytes (a `GET`).
  Future<List<int>> download() => downloadFile(_fileUrl);

  /// Writes [bytes] as the backup file (a `PUT`, replacing what is there).
  Future<void> upload(List<int> bytes) => uploadFile(_fileUrl, bytes);

  /// [url] as a directory address: a trailing slash is part of the
  /// identity of a WebDAV collection.
  static Uri _directoryUrl(Uri url) {
    final path = url.path.endsWith('/') ? url.path : '${url.path}/';
    return url.replace(path: path);
  }

  /// The `<response>` blocks of a multistatus body, namespace prefixes
  /// ignored (the body may be `d:response`, `D:response` or unprefixed).
  static Iterable<String> _responseBlocks(String xml) => RegExp(
    r'<[^>]*response\b[^>]*>([\s\S]*?)</[^>]*response>',
    caseSensitive: false,
  ).allMatches(xml).map((match) => match.group(1) ?? '');

  static String? _hrefOf(String block) {
    final match = RegExp(r'<[^>]*href[^>]*>\s*([^<]+?)\s*</[^>]*href>', caseSensitive: false).firstMatch(block);
    return match == null ? null : _unescapeXml(match.group(1) ?? '').trim();
  }

  /// Resolves a server href (absolute or relative) against [directory].
  static Uri _resolveHref(Uri directory, String href) {
    final decoded = Uri.tryParse(href);
    if (decoded == null) return directory;
    if (decoded.hasScheme) return decoded;
    if (href.startsWith('/')) return directory.replace(path: decoded.path, query: decoded.query);
    return directory.resolveUri(decoded);
  }

  static String _unescapeXml(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'");

  static const Map<String, String> _propfindHeaders = {'depth': '0', 'content-type': 'application/xml; charset=utf-8'};

  static final Uint8List _propfindBody = Uint8List.fromList(
    utf8.encode(
      '<?xml version="1.0" encoding="utf-8"?> '
      '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
    ),
  );

  static const Map<String, String> _listHeaders = {'depth': '1', 'content-type': 'application/xml; charset=utf-8'};

  /// The list's properties: resource type, size and modification time.
  static final Uint8List _listBody = Uint8List.fromList(
    utf8.encode(
      '<?xml version="1.0" encoding="utf-8"?> '
      '<d:propfind xmlns:d="DAV:"><d:prop> '
      '<d:resourcetype/><d:getcontentlength/><d:getlastmodified/>'
      '</d:prop></d:propfind>',
    ),
  );

  /// Sends one request with the Basic header; a non-2xx answer and a
  /// transport breakdown both surface as [WebDavFailure].
  Future<LiveResponse> _send(String method, Uri url, {Map<String, String> headers = const {}, List<int>? body}) async {
    final LiveResponse response;
    try {
      response = await _http.send(
        LiveRequest.custom(
          method: method,
          url: url,
          headers: {'authorization': _authorization, ...headers},
          bodyBytes: body == null ? null : Uint8List.fromList(body),
          timeout: const Duration(seconds: 30),
        ),
      );
    } on TransportFailure {
      throw const WebDavFailure(WebDavProblem.network);
    }
    if (response.isOk) return response;
    throw WebDavFailure(switch (response.statusCode) {
      401 || 403 => WebDavProblem.auth,
      404 || 409 => WebDavProblem.notFound,
      _ => WebDavProblem.server,
    }, status: response.statusCode);
  }
}
