import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:live_net/live_net.dart';

import 'package:pure_live/features/backup/web_dav_config.dart';

/// Why a WebDAV call failed, in the granularity the UI can name.
enum WebDavFailure {
  /// The server rejected the credentials (401/403).
  unauthorized,

  /// The configured directory does not exist (404).
  notFound,

  /// The server answered with another non-success status.
  server,

  /// The request never reached a WebDAV answer (DNS, TLS, timeout...).
  network,
}

/// A WebDAV call failure carrying the coarse kind and the status, if any.
final class WebDavException implements Exception {
  /// A WebDAV failure.
  const new({required this.kind, this.statusCode, this.detail});

  /// The coarse kind the message is chosen by.
  final WebDavFailure kind;

  /// The HTTP status, when the server answered.
  final int? statusCode;

  /// The transport's own words, for the expandable error line.
  final String? detail;

  @override
  String toString() {
    final head = 'WebDavException(${kind.name}${statusCode == null ? '' : ', $statusCode'})';
    return detail == null ? head : '$head: $detail';
  }
}

/// One entry of a WebDAV directory listing.
final class WebDavEntry {
  /// A directory entry.
  const new({required this.name, required this.href, required this.isDirectory, this.modified, this.size});

  /// The display name, decoded.
  final String name;

  /// The href exactly as the server returned it — the address requests for
  /// this entry are built from, never re-derived from the display name.
  final String href;

  /// Whether the entry is a collection.
  final bool isDirectory;

  /// The server's last-modified time, when it reported one.
  final DateTime? modified;

  /// The content length in bytes, when the server reported one.
  final int? size;
}

/// A WebDAV client over the live_net transport: the four calls cloud backup
/// needs — a connect test, a directory listing, an upload and a download —
/// with Basic authentication. The error statuses are ordinary
/// [WebDavException]s, so the page can name 401 "wrong credentials" instead
/// of showing a raw protocol word.
///
/// The verbs ride on `LiveRequest.custom`, the same contract every site
/// uses; the transport's `validateStatus: true` hands 4xx/5xx back as
/// responses rather than throwing them away.
final class WebDavService {
  /// A service speaking to [config]'s server through [http].
  ///
  /// The transport is created here (the `plugin` profile: nothing cached,
  /// strictly limited retries) and released by [close].
  new({required this.config, LiveHttp? http})
    : _ownsHttp = http == null,
      _http = http ?? DioFactory().create(profile: ClientProfile.plugin);

  /// The server and credentials this service speaks to.
  final WebDavConfig config;

  final LiveHttp _http;
  final bool _ownsHttp;

  /// Per-phase budget for metadata calls (PROPFIND, DELETE).
  static const Duration _callTimeout = Duration(seconds: 30);

  /// Per-phase budget for the archive transfers, which carry whole data
  /// areas over home connections.
  static const Duration _transferTimeout = Duration(minutes: 10);

  // The PROPFIND body, kept as one literal: `allprop` asks for the names,
  // sizes and times the listing shows without dragging every dead property
  // along.
  static const String _propfindBody =
      '<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/><d:resourcetype/><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>';

  /// The directory this service operates on, as an absolute URL ending in
  /// `/` — the address plus the configured directory.
  Uri get directoryUri => _uri(_directoryPath());

  /// [path] (a `/`-joined sequence of sub-directory names, '' for the
  /// configured directory itself) as an absolute server path ending in `/`
  /// — the browse door the page walks through.
  Uri uriAt(String path) => _uri(_joined(path));

  String _joined(String path) {
    final base = _directoryPath();
    final parts = path.split('/').where((part) => part.isNotEmpty).map(Uri.encodeComponent).join('/');
    if (parts.isEmpty) {
      return base;
    }
    return '$base$parts/';
  }

  /// The Basic auth header value for the configured credentials.
  String get _authHeader {
    final credentials = base64Encode(utf8.encode('${config.username}:${config.password}'));
    return 'Basic $credentials';
  }

  /// Proves the configuration can talk to the server: a `Depth: 0` PROPFIND
  /// on the backup directory. 207 (or a plain 200 from a lenient server)
  /// means the address, the account and the password all work.
  Future<void> testConnection() async {
    final response = await _send(
      method: 'PROPFIND',
      url: directoryUri,
      headers: const {'Depth': '0'},
      body: _propfindBody,
      contentType: 'application/xml',
      timeout: _callTimeout,
    );
    _expect(response, const {207, 200}, WebDavFailure.server);
  }

  /// Lists the configured directory (or the sub-folder [path] inside it),
  /// directories first and each group newest-entry first; the directory's
  /// own entry is dropped. This is the browse listing the page walks —
  /// folders included, unlike the plain backup list.
  Future<List<WebDavEntry>> list({String path = ''}) async {
    final response = await _send(
      method: 'PROPFIND',
      url: uriAt(path),
      headers: const {'Depth': '1'},
      body: _propfindBody,
      contentType: 'application/xml',
      timeout: _callTimeout,
    );
    _expect(response, const {207, 200}, WebDavFailure.server);
    final selfPath = _joined(path);
    final entries = _parseMultistatus(response.text)
        .where((entry) => _pathOf(entry.href) != selfPath)
        .toList()
          ..sort((a, b) {
            // Folders lead a browse listing; inside each group, newest
            // first, names breaking equal (or missing) timestamps.
            if (a.isDirectory != b.isDirectory) {
              return a.isDirectory ? -1 : 1;
            }
            final byTime = (b.modified ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.modified ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
            return byTime != 0 ? byTime : b.name.compareTo(a.name);
          });
    return entries;
  }

  /// The plain backup list: the files of the configured directory, newest
  /// first (the page's flat view when it is not browsing).
  Future<List<WebDavEntry>> listDirectory() async => [
    for (final entry in await list())
      if (!entry.isDirectory) entry,
  ];

  /// Uploads [bytes] as [fileName] into the configured directory,
  /// overwriting an older file of the same name (a re-upload of the same
  /// backup is a repair, not an error). A server that refuses to
  /// auto-create the target collection (404/409) gets one `MKCOL` attempt
  /// and a second PUT before the failure is reported.
  Future<void> upload(String fileName, Uint8List bytes, {String path = ''}) async {
    final target = _childAt(fileName, path);
    final contentType = fileName.toLowerCase().endsWith('.json') ? 'application/json' : 'application/zip';
    var response = await _send(
      method: 'PUT',
      url: target,
      headers: const {'Overwrite': 'T'},
      bodyBytes: bytes,
      contentType: contentType,
      timeout: _transferTimeout,
    );
    if (response.statusCode == 404 || response.statusCode == 409) {
      await _mkcol(path);
      response = await _send(
        method: 'PUT',
        url: target,
        headers: const {'Overwrite': 'T'},
        bodyBytes: bytes,
        contentType: contentType,
        timeout: _transferTimeout,
      );
    }
    _expect(response, const {200, 201, 204}, WebDavFailure.server);
  }

  /// Creates the configured directory; parents are assumed to exist (the
  /// address' own path does), so one `MKCOL` answers the common first-run
  /// case. A server that already has the directory answers 405/301 and the
  /// failure is deliberately swallowed — the upload after it decides.
  Future<void> _mkcol([String path = '']) async {
    try {
      await _send(method: 'MKCOL', url: uriAt(path), timeout: _callTimeout);
    } on WebDavException {
      // The retry PUT reports the real failure.
    }
  }

  /// Creates [path] (and any missing parents, one MKCOL per step) under the
  /// configured directory — the folder the page just entered on a server
  /// that does not auto-create on upload.
  Future<void> ensureFolder(String path) async {
    final steps = path.split('/').where((part) => part.isNotEmpty).toList();
    final walked = StringBuffer();
    for (final step in steps) {
      walked.write('$step/');
      await _mkcol(walked.toString());
    }
  }

  /// Downloads the file at [entry]. Returns the raw archive bytes.
  Future<Uint8List> download(WebDavEntry entry) async {
    final response = await _send(method: 'GET', url: _resolve(entry.href), timeout: _transferTimeout);
    _expect(response, const {200}, WebDavFailure.server);
    return response.bodyBytes;
  }

  /// Deletes the file at [entry]. A missing file is already the requested
  /// state, so 404 counts as success.
  Future<void> delete(WebDavEntry entry) async {
    final response = await _send(method: 'DELETE', url: _resolve(entry.href), timeout: _callTimeout);
    _expect(response, const {200, 202, 204, 404}, WebDavFailure.server);
  }

  /// Releases the pooled transport when this service owns it. The instance
  /// is unusable afterwards.
  void close() {
    if (_ownsHttp) {
      _http.close();
    }
  }

  Future<LiveResponse> _send({
    required String method,
    required Uri url,
    Map<String, String> headers = const {},
    String? body,
    Uint8List? bodyBytes,
    String? contentType,
    Duration? timeout,
  }) async {
    try {
      return await _http.send(
        LiveRequest.custom(
          method: method,
          url: url,
          headers: {'Authorization': _authHeader, ...headers},
          body: body,
          bodyBytes: bodyBytes,
          contentType: contentType,
          timeout: timeout,
        ),
      );
    } on TransportFailure catch (failure) {
      throw WebDavException(kind: WebDavFailure.network, detail: '$failure');
    }
  }

  void _expect(LiveResponse response, Set<int> accepted, WebDavFailure otherwise) {
    if (accepted.contains(response.statusCode)) {
      return;
    }
    throw WebDavException(
      kind: switch (response.statusCode) {
        401 || 403 => WebDavFailure.unauthorized,
        404 => WebDavFailure.notFound,
        _ => otherwise,
      },
      statusCode: response.statusCode,
      detail: switch (response.text.length) {
        0 => null,
        final length => response.text.substring(0, length > 300 ? 300 : length),
      },
    );
  }

  /// The configured directory as an absolute server path ending in `/`,
  /// e.g. `/dav/pure_live/`.
  String _directoryPath() {
    final base = Uri.parse(config.address.trim());
    final segments = [
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      ...config.directory.trim().split('/').where((segment) => segment.isNotEmpty),
    ];
    return '/${segments.join('/')}${segments.isEmpty ? '' : '/'}';
  }

  Uri _uri(String path) => Uri.parse(config.address.trim()).replace(path: path);

  /// The directory's own URL with [child] appended.
  Uri _child(String child) => _childAt(child, '');

  Uri _childAt(String child, String path) =>
      _uri('${_joined(path)}${Uri.encodeComponent(child).replaceAll('%2F', '/')}');

  /// Resolves an href exactly as the server returned it: a full URL stands
  /// alone, a path resolves against the server's origin.
  Uri _resolve(String href) {
    final parsed = Uri.tryParse(href);
    if (parsed == null) {
      return _child(href);
    }
    if (parsed.hasScheme) {
      return parsed;
    }
    final base = Uri.parse(config.address.trim());
    return parsed.path.startsWith('/') ? base.replace(path: parsed.path) : _uri('${_directoryPath()}${parsed.path}');
  }

  /// The path half of an href, for the self-entry comparison in
  /// [listDirectory].
  static String _pathOf(String href) {
    final parsed = Uri.tryParse(href);
    if (parsed == null) {
      return href;
    }
    final raw = parsed.hasScheme ? parsed.path : parsed.path;
    return raw.endsWith('/') ? raw : '$raw/';
  }

  /// Parses a `207 Multi-Status` body.
  ///
  /// Backup listing needs five facts per entry, so the parser is a tolerant
  /// scanner rather than an XML stack: namespace prefixes vary between
  /// servers (`d:`, `D:`, none), and a server that omits a property must
  /// cost one null field, not the whole listing. It reads the elements'
  /// local names and ignores everything else.
  static List<WebDavEntry> _parseMultistatus(String body) {
    final entries = <WebDavEntry>[];
    for (final match in _responseBlock.allMatches(body)) {
      final block = match.group(0)!;

      final hrefMatch = _hrefPattern.firstMatch(block);
      final href = hrefMatch == null ? '' : _decodeXml(hrefMatch.group(1)!).trim();
      if (href.isEmpty) {
        continue;
      }

      final name = Uri.tryParse(href) == null
          ? href
          : Uri.decodeComponent(href.split('?').first.split('/').where((part) => part.isNotEmpty).lastOrNull ?? '');

      final isDirectory = _collectionPattern.hasMatch(block) || href.endsWith('/');

      final modified = switch (_lastModifiedPattern.firstMatch(block)) {
        null => null,
        final match => _parseHttpDate(_decodeXml(match.group(1)!).trim()),
      };

      final size = switch (_lengthPattern.firstMatch(block)) {
        null => null,
        final match => int.tryParse(_decodeXml(match.group(1)!).trim()),
      };

      entries.add(WebDavEntry(name: name, href: href, isDirectory: isDirectory, modified: modified, size: size));
    }
    return entries;
  }

  static DateTime? _parseHttpDate(String value) {
    try {
      return HttpDate.parse(value);
    } on FormatException {
      return DateTime.tryParse(value);
    }
  }

  static String _decodeXml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");

  /// One `<response>` (any prefix) of a multistatus body.
  static final RegExp _responseBlock = RegExp(
    r'<(?:[\w.-]+:)?response(?:\s[^>]*)?>.*?</(?:[\w.-]+:)?response\s*>',
    multiLine: true,
    dotAll: true,
    caseSensitive: false,
  );

  static final RegExp _hrefPattern = RegExp(
    r'<(?:[\w.-]+:)?href(?:\s[^>]*)?>(.*?)</(?:[\w.-]+:)?href\s*>',
    dotAll: true,
    caseSensitive: false,
  );

  static final RegExp _lastModifiedPattern = RegExp(
    r'<(?:[\w.-]+:)?getlastmodified(?:\s[^>]*)?>(.*?)</',
    dotAll: true,
    caseSensitive: false,
  );

  static final RegExp _lengthPattern = RegExp(
    r'<(?:[\w.-]+:)?getcontentlength(?:\s[^>]*)?>(.*?)</',
    dotAll: true,
    caseSensitive: false,
  );

  static final RegExp _collectionPattern = RegExp(r'<(?:[\w.-]+:)?collection\s*/?>', caseSensitive: false);
}
