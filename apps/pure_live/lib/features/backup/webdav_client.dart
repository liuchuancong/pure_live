import 'dart:convert' show base64Encode, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, TransportFailure;
import 'package:pure_live/features/backup/backup_document.dart' show BackupDocument;

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
  String get _authorization =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  /// Checks the server: a `PROPFIND` on the collection itself (depth 0)
  /// answers reachability and the credentials in one round trip; the
  /// backup file may still not exist.
  Future<void> test() => _send('PROPFIND', _base, headers: _propfindHeaders, body: _propfindBody);

  /// Reads the backup file's bytes (a `GET`).
  Future<List<int>> download() async => (await _send('GET', _fileUrl)).bodyBytes;

  /// Writes [bytes] as the backup file (a `PUT`, replacing what is there).
  Future<void> upload(List<int> bytes) =>
      _send('PUT', _fileUrl, headers: {'content-type': 'application/json; charset=utf-8'}, body: bytes);

  static const Map<String, String> _propfindHeaders = {
    'depth': '0',
    'content-type': 'application/xml; charset=utf-8',
  };

  static final Uint8List _propfindBody = Uint8List.fromList(
    utf8.encode(
      '<?xml version="1.0" encoding="utf-8"?> '
      '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
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
    throw WebDavFailure(
      switch (response.statusCode) {
        401 || 403 => WebDavProblem.auth,
        404 || 409 => WebDavProblem.notFound,
        _ => WebDavProblem.server,
      },
      status: response.statusCode,
    );
  }
}
