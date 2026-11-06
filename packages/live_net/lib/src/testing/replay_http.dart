// Test support: a LiveHttp that answers from recorded samples instead of the
// network, so platform tests run offline against real (scrubbed) answers.
//
// Sample directories (fixture schema 1, the layout the capture tooling
// writes; hand-written samples use it too):
//
//   <root>/<platform>/<number>-<case>/   e.g. fixtures/kugoulive/S05-stream-live
//     meta.json     the exchange, see below
//     body.<ext>    the response body after content decoding (gzip, br, …),
//                   scrubbed; named by meta.json's `body`
//
// meta.json:
//
//   {
//     "schema": 1,
//     "platform": "kugoulive",
//     "sample": "S05-stream-live",
//     "capturedAt": "2026-09-27T17:52:52.882453Z",
//     "route": "direct",                        (or "proxy", "proxy:<host>:<port>")
//     "request": {
//       "method": "GET",
//       "url": "https://host/path?a=1&_=1790531600000",
//       "headers": {"Referer": "https://…"},   (as sent; not matched)
//       "body": "a=1&b=2"                       (optional: form or JSON text)
//     },
//     "response": {
//       "status": 200,
//       "headers": {"content-type": "…", "set-cookie": ["a=1", "b=2"]}
//     },
//     "raw": {"sha256": "…", "length": 4345},  (the body before scrubbing)
//     "body": "body.json",
//     "scrubbed": [{"where": "$.data.token", "rule": "secret"}],
//     "tool": "what wrote the sample"
//   }
//
// Only `request.method`, `request.url`, `request.body`, `response.status`,
// `response.headers` and the body file are read here; the rest is provenance
// for reviewers. A response header is one string or a list of them (a
// repeated header such as `set-cookie`). Signatures, tokens, sessions and
// clocks in the URL or the body are recorded with stand-in values; the test
// leaves those names out of matching through `ReplayHttp.ignoredQuery`.

// kareki: ignore_for_file=test_only_used
// Test support has no production consumer by design.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_net/src/contracts/live_http.dart';
import 'package:live_net/src/contracts/request.dart';
import 'package:live_net/src/contracts/response.dart';
import 'package:live_net/src/contracts/streamed_response.dart';
import 'package:live_net/src/contracts/transport_failure.dart';

/// One recorded exchange to replay.
final class ReplaySample {
  /// A sample answering [method] [url] with [statusCode], [headers] (by
  /// lower-case name) and [bodyBytes]; [form] or [json] is the request body
  /// it was recorded with, compared when set.
  new({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.bodyBytes,
    this.headers = const {},
    this.form,
    this.json,
  });

  /// Loads `<directory>/meta.json` and the body file it names (the layout
  /// at the top of this file).
  factory load(String directory) {
    final meta = jsonDecode(File('$directory/meta.json').readAsStringSync()) as Map<String, dynamic>;
    final request = meta['request'] as Map<String, dynamic>;
    final response = meta['response'] as Map<String, dynamic>;
    final body = request['body'];
    final json = body is String ? _decodeJson(body) : null;
    return ReplaySample(
      method: request['method'] as String,
      url: Uri.parse(request['url'] as String),
      statusCode: response['status'] as int,
      headers: {
        for (final entry in (response['headers'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key.toLowerCase(): entry.value is List
              ? [for (final value in entry.value as List) '$value']
              : ['${entry.value}'],
      },
      bodyBytes: File('$directory/${meta['body']}').readAsBytesSync(),
      form: body is String && json == null ? Uri.splitQueryString(body) : null,
      json: json,
    );
  }

  /// [body] decoded when it is a JSON object or array, else null.
  static Object? _decodeJson(String body) {
    final trimmed = body.trimLeft();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return null;
    }
  }

  /// Recorded method.
  final String method;

  /// Recorded URL (signatures scrubbed).
  final Uri url;

  /// Recorded status code.
  final int statusCode;

  /// Recorded headers by lower-case name; a repeated header keeps every
  /// value.
  final Map<String, List<String>> headers;

  /// Recorded body, after content decoding.
  final Uint8List bodyBytes;

  /// Recorded form fields of a form POST, or null.
  final Map<String, String>? form;

  /// Recorded JSON body (an object or array), or null.
  final Object? json;
}

/// Replays recorded samples: a request matches a sample by method, host,
/// path, and the query parameters, form fields and JSON body fields (at any
/// depth) other than [ignoredQuery] (the signature, session and clock values
/// whose recorded values were scrubbed or differ per run). Headers are not
/// compared. The first matching sample answers; a request without one throws
/// a [StateError], failing the test.
///
/// [samples] is read on every request, so a test whose platform changes its
/// answer midway puts the new sample first there. A request whose cancel
/// token is already cancelled fails with [CancelledFailure], as on the wire.
final class ReplayHttp implements LiveHttp {
  /// Replays a copy of [samples].
  new(List<ReplaySample> samples, {this.ignoredQuery = const {}}) : samples = [...samples];

  /// Loads `<root>/<name>` for every name in [names].
  factory fixtures(String root, List<String> names, {Set<String> ignoredQuery = const {}}) =>
      ReplayHttp([for (final name in names) ReplaySample.load('$root/$name')], ignoredQuery: ignoredQuery);

  /// Samples in match order.
  final List<ReplaySample> samples;

  /// Query parameters, form fields and JSON keys left out of matching.
  final Set<String> ignoredQuery;

  /// Every request handed to [send] or [open], in order (a cancelled one
  /// too).
  final List<LiveRequest> requests = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final sample = _answer(request);
    return LiveResponse(
      statusCode: sample.statusCode,
      headers: _joined(sample.headers),
      setCookies: sample.headers['set-cookie'] ?? const [],
      bodyBytes: sample.bodyBytes,
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    final sample = _answer(request);
    return _ReplayStreamedResponse(
      statusCode: sample.statusCode,
      headers: _joined(sample.headers),
      bytes: sample.bodyBytes,
    );
  }

  /// Nothing to release.
  @override
  void close() {}

  ReplaySample _answer(LiveRequest request) {
    requests.add(request);
    if (request.cancelToken.isCancelled) throw CancelledFailure(cause: request.cancelToken.reason);
    for (final sample in samples) {
      if (_matches(sample, request)) return sample;
    }
    final bytes = request.bodyBytes;
    final body = bytes != null ? '${bytes.length} body bytes' : request.body;
    throw StateError('No recorded sample for $request${body == null ? '' : ' ($body)'}');
  }

  bool _matches(ReplaySample sample, LiveRequest request) {
    if (sample.method.toUpperCase() != request.method.toUpperCase()) return false;
    if (sample.url.host != request.url.host || sample.url.path != request.url.path) return false;
    if (!_same(_kept(sample.url.queryParameters), _kept(request.url.queryParameters))) return false;
    final json = sample.json;
    if (json != null) {
      final text = _sent(request);
      final sent = text == null ? null : ReplaySample._decodeJson(text);
      return sent != null && jsonEncode(_strip(sent)) == jsonEncode(_strip(json));
    }
    final form = sample.form;
    if (form == null) return true;
    final text = _sent(request);
    return text != null && _same(_kept(form), _kept(Uri.splitQueryString(text)));
  }

  /// The body [request] puts on the wire, as text: [LiveRequest.bodyBytes]
  /// when set, else [LiveRequest.body].
  static String? _sent(LiveRequest request) {
    final bytes = request.bodyBytes;
    return bytes == null ? request.body : utf8.decode(bytes, allowMalformed: true);
  }

  Map<String, String> _kept(Map<String, String> fields) => {
    for (final entry in fields.entries)
      if (!ignoredQuery.contains(entry.key)) entry.key: entry.value,
  };

  /// [value] without the [ignoredQuery] keys, with object keys sorted.
  Object? _strip(Object? value) {
    if (value is Map) {
      final keys = [
        for (final key in value.keys)
          if (!ignoredQuery.contains(key)) '$key',
      ]..sort();
      return {for (final key in keys) key: _strip(value[key])};
    }
    if (value is List) return [for (final item in value) _strip(item)];
    return value;
  }

  static bool _same(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((entry) => b[entry.key] == entry.value);

  /// [headers] the way the dio transport reports them: repeated values
  /// joined with `, ` (the raw `set-cookie` lines go to
  /// [LiveResponse.setCookies]).
  static Map<String, String> _joined(Map<String, List<String>> headers) => {
    for (final entry in headers.entries) entry.key: entry.value.join(', '),
  };
}

/// The recorded body as one chunk, sent once the stream is listened to;
/// [close] before that ends the stream empty.
final class _ReplayStreamedResponse implements LiveStreamedResponse {
  new({required this.statusCode, required this.headers, required Uint8List bytes}) {
    _controller = StreamController<Uint8List>(
      onListen: () => scheduleMicrotask(() {
        if (!_closed) _controller.add(bytes);
        unawaited(_controller.close());
      }),
    );
  }

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  late final StreamController<Uint8List> _controller;
  bool _closed = false;

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  Future<void> close() async {
    _closed = true;
  }
}
