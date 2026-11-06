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
//
// Schema 2 extends what one sample can answer, for shapes the wire has that a
// single response cannot spell: the same request form answered differently
// call by call, a request the host accepts and never answers, a connect-phase
// failure, and a body that breaks mid-flight. `request` means the same as in
// schema 1 (the `body` key stays optional: without it the sample answers
// every request to the method, host, path and query); the answers live in an
// `answers` list, consumed in call order, and the LAST answer repeats once
// the list runs out (a poll loop keeps hearing the last recorded answer; a
// test that pins the call count asserts it through `ReplayHttp.requests`).
// Every answer object carries a `kind`, default `response`:
//
//   {"status": 401, "headers": {...}, "body": "body-2.json"}
//       an ordinary answer; `headers` and `body` are optional (no body key
//       means an empty body), and `body` names a file in the sample
//       directory like the schema-1 `body`.
//   {"kind": "connect", "description": "dns down"}
//       the request fails with a `ConnectFailure` before any answer.
//   {"kind": "hang"}
//       the request is accepted and never answered — the returned future
//       stays pending until the request's cancel token is cancelled, which
//       fails it with a `CancelledFailure` (as a caller's timeout or
//       cancellation observes on the wire).
//   {"kind": "broken", "status": 200, "headers": {...}, "body": "body.flv",
//    "chunks": [8, 33], "end": "closed"}
//       the head of the answer is normal but the body breaks: the body file
//       is streamed in the listed chunk sizes (bytes beyond the listed sizes
//       never arrive), and then the stream ends as `end` says — `closed`
//       (the default) completes it, `interrupted` fails it with a
//       `ProtocolFailure`, and `stalled` leaves it open with nothing more to
//       come (the server that stopped talking). A broken answer is meant for
//       `open`; `send` hands out the bytes the chunks delivered (and fails
//       for `interrupted`).

// kareki: ignore_for_file=test_only_used
// Test support has no production consumer by design.
// ignore_for_file: unnecessary_type_name_in_constructor -- this SDK has no
// `new.named` shorthand: a named constructor must repeat its type name.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_net/src/contracts/live_http.dart';
import 'package:live_net/src/contracts/request.dart';
import 'package:live_net/src/contracts/response.dart';
import 'package:live_net/src/contracts/streamed_response.dart';
import 'package:live_net/src/contracts/transport_failure.dart';

/// One answer a sample can give, in the order its requests arrive. The
/// shapes are the schema-2 `answers` entries (see the file header); a
/// hand-built sample carries exactly one [_ResponseAnswer].
sealed class _Answer {
  const _Answer();
}

/// An ordinary recorded response.
final class _ResponseAnswer extends _Answer {
  new({required this.statusCode, required this.headers, required this.bodyBytes});

  final int statusCode;
  final Map<String, List<String>> headers;
  final Uint8List bodyBytes;
}

/// A request that fails before any answer (the connection did not happen).
final class _ConnectAnswer extends _Answer {
  const new(this.description);

  final String description;
}

/// A request the host accepted and never answers.
final class _HangAnswer extends _Answer {
  const new();
}

/// A normal answer head whose body breaks after the declared chunks.
final class _BrokenAnswer extends _Answer {
  const new({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
    required this.chunks,
    required this.end,
  });

  final int statusCode;
  final Map<String, List<String>> headers;

  /// The full recorded body; [chunks] cut what arrives out of it.
  final Uint8List bodyBytes;
  final List<int> chunks;
  final _StreamEnd end;
}

/// How a broken body ends.
enum _StreamEnd {
  /// The stream completes after the chunks (the server closed early).
  closed,

  /// The stream fails after the chunks (the connection broke mid-flight).
  interrupted,

  /// The stream stays open with nothing more to come.
  stalled,
}

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
  }) : _answers = [
        _ResponseAnswer(statusCode: statusCode, headers: headers, bodyBytes: bodyBytes),
      ];

  ReplaySample._({
    required this.method,
    required this.url,
    required List<_Answer> answers,
    this.form,
    this.json,
  }) : _answers = answers,
       statusCode = _firstResponse(answers)?.statusCode ?? 0,
       headers = _firstResponse(answers)?.headers ?? const {},
       bodyBytes = _firstResponse(answers)?.bodyBytes ?? Uint8List(0);

  /// Loads `<directory>/meta.json` and the body files it names (the schema-1
  /// and schema-2 layouts at the top of this file).
  factory load(String directory) {
    final meta = jsonDecode(File('$directory/meta.json').readAsStringSync()) as Map<String, dynamic>;
    final schema = meta['schema'];
    if (schema == 2) return ReplaySample._schema2(directory, meta);
    if (schema == 1) return ReplaySample._schema1(directory, meta);
    throw ArgumentError('replay sample $directory: unsupported schema $schema (1 or 2)');
  }

  factory ReplaySample._schema1(String directory, Map<String, dynamic> meta) {
    final request = meta['request'] as Map<String, dynamic>;
    final response = meta['response'] as Map<String, dynamic>;
    final body = request['body'];
    final json = body is String ? _decodeJson(body) : null;
    return ReplaySample(
      method: request['method'] as String,
      url: Uri.parse(request['url'] as String),
      statusCode: response['status'] as int,
      headers: _headersOf(response['headers']),
      bodyBytes: File('$directory/${meta['body']}').readAsBytesSync(),
      form: body is String && json == null ? Uri.splitQueryString(body) : null,
      json: json,
    );
  }

  factory ReplaySample._schema2(String directory, Map<String, dynamic> meta) {
    final request = meta['request'] as Map<String, dynamic>;
    final answers = meta['answers'];
    if (answers is! List || answers.isEmpty) {
      throw ArgumentError('replay sample $directory: schema 2 needs a non-empty "answers" list');
    }
    final body = request['body'];
    final json = body is String ? _decodeJson(body) : null;
    return ReplaySample._(
      method: request['method'] as String,
      url: Uri.parse(request['url'] as String),
      form: body is String && json == null ? Uri.splitQueryString(body) : null,
      json: json,
      answers: [for (final answer in answers) _parseAnswer(directory, answer)],
    );
  }

  /// One schema-2 answer object (see the file header for the shapes).
  static _Answer _parseAnswer(String directory, Object? answer) {
    if (answer is! Map<String, dynamic>) {
      throw ArgumentError('replay sample $directory: every answer is an object');
    }
    switch (answer['kind'] ?? 'response') {
      case 'response':
        return _ResponseAnswer(
          statusCode: (answer['status'] ?? 200) as int,
          headers: _headersOf(answer['headers']),
          bodyBytes: answer['body'] == null
              ? Uint8List(0)
              : File('$directory/${answer['body']}').readAsBytesSync(),
        );
      case 'connect':
        return _ConnectAnswer('${answer['description'] ?? 'connection failed'}');
      case 'hang':
        return const _HangAnswer();
      case 'broken':
        final bodyBytes = answer['body'] == null
            ? Uint8List(0)
            : File('$directory/${answer['body']}').readAsBytesSync();
        final chunks = [for (final chunk in answer['chunks'] as List? ?? const []) chunk as int];
        if (chunks.fold(0, (total, chunk) => total + chunk) > bodyBytes.length) {
          throw ArgumentError('replay sample $directory: the chunks deliver more than the body holds');
        }
        final end = switch (answer['end'] ?? 'closed') {
          'closed' => _StreamEnd.closed,
          'interrupted' => _StreamEnd.interrupted,
          'stalled' => _StreamEnd.stalled,
          final other => throw ArgumentError('replay sample $directory: "$other" is not a broken-stream end'),
        };
        return _BrokenAnswer(
          statusCode: (answer['status'] ?? 200) as int,
          headers: _headersOf(answer['headers']),
          bodyBytes: bodyBytes,
          chunks: chunks,
          end: end,
        );
      case final other:
        throw ArgumentError(
          'replay sample $directory: "$other" is not an answer kind (response, connect, hang, broken)',
        );
    }
  }

  /// [headers] as the samples spell them: one string or a list per header,
  /// keyed by lower-case name.
  static Map<String, List<String>> _headersOf(Object? headers) => {
    for (final entry in ((headers as Map<String, dynamic>?) ?? const {}).entries)
      entry.key.toLowerCase(): entry.value is List
          ? [for (final value in entry.value as List) '$value']
          : ['${entry.value}'],
  };

  /// The first ordinary answer of [answers], whose recording the public
  /// fields describe (they exist for introspection; the replay answers
  /// through [_answers]).
  static _ResponseAnswer? _firstResponse(List<_Answer> answers) =>
      answers.whereType<_ResponseAnswer>().firstOrNull;

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

  /// The answers this sample gives, in call order (the last one repeats).
  final List<_Answer> _answers;

  /// Recorded method.
  final String method;

  /// Recorded URL (signatures scrubbed).
  final Uri url;

  /// Status of the first ordinary answer (0 when none).
  final int statusCode;

  /// Headers of the first ordinary answer, by lower-case name; a repeated
  /// header keeps every value.
  final Map<String, List<String>> headers;

  /// Body of the first ordinary answer, after content decoding.
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
/// A sample with more than one answer (schema 2) gives them in call order and
/// repeats its last one once they run out. A request whose cancel token is
/// already cancelled fails with [CancelledFailure], as on the wire.
///
/// [samples] is read on every request, so a test whose platform changes its
/// answer midway puts the new sample first there.
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

  /// Every streamed response [open] handed out, in order, so a test can ask
  /// through [ReplayStreamedResponse.closed] how its consumption ended.
  final List<ReplayStreamedResponse> opens = [];

  /// How many requests each sample has answered, send or open alike.
  final Map<ReplaySample, int> _calls = {};

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final answer = _answer(request);
    return switch (answer) {
      _ResponseAnswer(:final statusCode, :final headers, :final bodyBytes) => LiveResponse(
        statusCode: statusCode,
        headers: _joined(headers),
        setCookies: headers['set-cookie'] ?? const [],
        bodyBytes: bodyBytes,
      ),
      _ConnectAnswer(:final description) => throw ConnectFailure(description),
      _HangAnswer() => await _hung(request),
      _BrokenAnswer(:final statusCode, :final headers, :final bodyBytes, :final chunks, :final end) => switch (end) {
        _StreamEnd.interrupted => throw const ProtocolFailure('connection closed mid-body'),
        // A buffered reader holds the bytes that arrived before the break.
        _ => LiveResponse(
          statusCode: statusCode,
          headers: _joined(headers),
          setCookies: headers['set-cookie'] ?? const [],
          bodyBytes: _cut(bodyBytes, chunks),
        ),
      },
    };
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    final answer = _answer(request);
    if (answer is _ConnectAnswer) throw ConnectFailure(answer.description);
    if (answer is _HangAnswer) return await _hung(request);
    final (statusCode, headers, chunks, interrupted, stalled) = switch (answer) {
      _ResponseAnswer(:final statusCode, :final headers, :final bodyBytes) => (
        statusCode,
        _joined(headers),
        [bodyBytes],
        false,
        false,
      ),
      _BrokenAnswer(:final statusCode, :final headers, :final bodyBytes, :final chunks, :final end) => (
        statusCode,
        _joined(headers),
        _chunksOf(bodyBytes, chunks),
        end == _StreamEnd.interrupted,
        end == _StreamEnd.stalled,
      ),
      _HangAnswer() || _ConnectAnswer() => throw StateError('handled above'),
    };
    final response = ReplayStreamedResponse(
      statusCode: statusCode,
      headers: headers,
      chunks: chunks,
      interrupted: interrupted,
      stalled: stalled,
    );
    opens.add(response);
    return response;
  }

  /// Nothing to release.
  @override
  void close() {}

  /// The answer [request] gets: the matching sample's next one, or its last
  /// again once the answers ran out.
  _Answer _answer(LiveRequest request) {
    requests.add(request);
    if (request.cancelToken.isCancelled) throw CancelledFailure(cause: request.cancelToken.reason);
    for (final sample in samples) {
      if (_matches(sample, request)) {
        final call = _calls.update(sample, (count) => count + 1, ifAbsent: () => 0);
        return sample._answers[call < sample._answers.length ? call : sample._answers.length - 1];
      }
    }
    final bytes = request.bodyBytes;
    final body = bytes != null ? '${bytes.length} body bytes' : request.body;
    throw StateError('No recorded sample for $request${body == null ? '' : ' ($body)'}');
  }

  /// A future that stays pending until [request]'s cancel token is cancelled,
  /// then fails as cancelled — the host that accepts and never answers.
  Future<T> _hung<T>(LiveRequest request) {
    final completer = Completer<T>();
    unawaited(
      request.cancelToken.whenCancel.then((reason) {
        if (!completer.isCompleted) completer.completeError(CancelledFailure(cause: reason));
      }),
    );
    return completer.future;
  }

  /// The bytes of [bodyBytes] the [chunks] deliver.
  static Uint8List _cut(Uint8List bodyBytes, List<int> chunks) {
    final cut = Uint8List(chunks.fold(0, (total, chunk) => total + chunk));
    var target = 0;
    var source = 0;
    for (final chunk in chunks) {
      cut.setRange(target, target + chunk, bodyBytes, source);
      target += chunk;
      source += chunk;
    }
    return cut;
  }

  /// [bodyBytes] cut into the [chunks] to stream.
  static List<Uint8List> _chunksOf(Uint8List bodyBytes, List<int> chunks) {
    final cut = <Uint8List>[];
    var offset = 0;
    for (final chunk in chunks) {
      cut.add(Uint8List.sublistView(bodyBytes, offset, offset + chunk));
      offset += chunk;
    }
    return cut;
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

/// A replayed streamed answer: its body arrives in the declared chunks once
/// the stream is listened to and ends as the answer declared (after the
/// chunks, or interrupted, or not at all while the server stalls). [close]
/// before that ends the stream empty.
///
/// [closed] says whether the CONSUMER ended the response itself — a [close]
/// call, or a stream subscription cancelled before the declared end arrived.
/// A body read to its end is not closed.
final class ReplayStreamedResponse implements LiveStreamedResponse {
  /// A response streaming [chunks] and then completing, failing
  /// ([interrupted]) or never ending ([stalled]).
  new({
    required this.statusCode,
    required this.headers,
    required List<Uint8List> chunks,
    bool interrupted = false,
    bool stalled = false,
  }) {
    _controller = StreamController<Uint8List>(
      onCancel: () {
        // Fires for an abandoned stream and again after a done event; only
        // the abandonment is the consumer ending it.
        if (!_ended) _cancelled = true;
      },
    );
    _controller.onListen = () => scheduleMicrotask(() => _deliver(chunks, interrupted, stalled));
  }

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  late final StreamController<Uint8List> _controller;
  bool _ended = false;
  bool _closed = false;
  bool _cancelled = false;

  /// Whether the consumer ended this response: [close] called, or the stream
  /// subscription cancelled before the declared end arrived.
  bool get closed => _closed || _cancelled;

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  Future<void> close() {
    _closed = true;
    _ended = true;
    // The done event goes to a listener there is; nobody must wait for it —
    // a response closed before its first listen has none to deliver to.
    if (!_controller.isClosed) unawaited(_controller.close());
    return Future.value();
  }

  /// Puts the whole body on the stream in one go — every chunk and the end
  /// land in this one microtask, so a consumer reads them in order and can
  /// only stop before the end while the stream is still open.
  void _deliver(List<Uint8List> chunks, bool interrupted, bool stalled) {
    if (_controller.isClosed) return; // closed before the first listen: nothing to deliver
    chunks.forEach(_controller.add);
    if (stalled) return; // the server stopped talking; ending it is the consumer's
    _ended = true;
    if (interrupted) _controller.addError(const ProtocolFailure('connection closed mid-body'));
    unawaited(_controller.close());
  }
}
