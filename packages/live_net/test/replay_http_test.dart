import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_net/testing.dart';
import 'package:test/test.dart';

/// A fresh sample root, deleted after the test.
Future<Directory> _root() async {
  final root = await Directory.systemTemp.createTemp('replay');
  addTearDown(() => root.delete(recursive: true));
  return root;
}

/// Writes `<root>/<name>/meta.json` and `body.json` the way the capture
/// tooling does (fixture schema 1); [requestBody] is the form or JSON text
/// the request was recorded with.
void _sample(
  Directory root,
  String name, {
  required String url,
  required String body,
  String method = 'GET',
  String? requestBody,
  int status = 200,
  Map<String, Object> headers = const {},
}) {
  final directory = Directory('${root.path}/$name')..createSync();
  File('${directory.path}/body.json').writeAsStringSync(body);
  File('${directory.path}/meta.json').writeAsStringSync(
    jsonEncode({
      'schema': 1,
      'platform': 'example',
      'sample': name,
      'capturedAt': '2026-11-06T12:00:00Z',
      'route': 'direct',
      'request': {'method': method, 'url': url, 'headers': <String, String>{}, 'body': ?requestBody},
      'response': {'status': status, 'headers': headers},
      'raw': {'sha256': '', 'length': utf8.encode(body).length},
      'body': 'body.json',
      'scrubbed': <Object>[],
      'tool': 'replay_http_test',
    }),
  );
}

/// Writes `<root>/<name>/meta.json` as a hand-written schema-2 sample; every
/// answer names its body file among [bodies] (an answer without one has an
/// empty body).
void _sample2(
  Directory root,
  String name, {
  required String url,
  required List<Map<String, Object>> answers,
  String method = 'GET',
  String? requestBody,
  Map<String, String> bodies = const {},
}) {
  final directory = Directory('${root.path}/$name')..createSync();
  for (final entry in bodies.entries) {
    File('${directory.path}/${entry.key}').writeAsStringSync(entry.value);
  }
  File('${directory.path}/meta.json').writeAsStringSync(
    jsonEncode({
      'schema': 2,
      'platform': 'example',
      'sample': name,
      'capturedAt': '2026-11-07T12:00:00Z',
      'route': 'direct',
      'request': {'method': method, 'url': url, 'headers': <String, String>{}, 'body': ?requestBody},
      'answers': answers,
      'scrubbed': <Object>[],
      'tool': 'replay_http_test',
    }),
  );
}

/// Matches the replay's miss, whose message names [request].
Matcher _unanswered(String request) =>
    throwsA(isA<StateError>().having((error) => error.message, 'message', contains(request)));

void main() {
  group('ReplaySample.load', () {
    test('reads the request, the status, the lower-cased headers and the body file', () async {
      final root = await _root();
      _sample(
        root,
        'S01-list',
        url: 'https://api.example.test/list?page=2',
        body: '{"ok":1}',
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          'set-cookie': ['a=1', 'b=2'],
        },
      );

      final sample = ReplaySample.load('${root.path}/S01-list');

      expect(sample.method, 'GET');
      expect(sample.url, Uri.parse('https://api.example.test/list?page=2'));
      expect(sample.statusCode, 404);
      expect(sample.headers, {
        'content-type': ['application/json'],
        'set-cookie': ['a=1', 'b=2'],
      });
      expect(utf8.decode(sample.bodyBytes), '{"ok":1}');
      expect([sample.form, sample.json], [isNull, isNull]);
    });

    test('a recorded body is JSON when it is an object or array, else form fields', () async {
      final root = await _root();
      _sample(root, 'S01-json', method: 'POST', url: 'https://api.example.test/a', body: '', requestBody: '{"a":[1]}');
      _sample(
        root,
        'S01-form',
        method: 'POST',
        url: 'https://api.example.test/a',
        body: '',
        requestBody: 'a=1&b=%E4%BA%8C+x',
      );

      final json = ReplaySample.load('${root.path}/S01-json');
      final form = ReplaySample.load('${root.path}/S01-form');

      expect(
        [json.json, json.form],
        [
          {
            'a': [1],
          },
          isNull,
        ],
      );
      expect(
        [form.form, form.json],
        [
          {'a': '1', 'b': '二 x'},
          isNull,
        ],
      );
    });
  });

  group('matching', () {
    test('a GET matches method, host, path and the whole query, in any order', () async {
      final root = await _root();
      _sample(root, 'S01-list', url: 'https://api.example.test/list?page=2&size=20', body: '{"page":2}');
      final http = ReplayHttp.fixtures(root.path, ['S01-list']);

      final response = await http.send(LiveRequest.get(Uri.parse('https://api.example.test/list?size=20&page=2')));

      expect(response.text, '{"page":2}');
      for (final request in [
        LiveRequest.get(Uri.parse('https://api.example.test/list?size=20&page=3')),
        LiveRequest.get(Uri.parse('https://api.example.test/list?size=20&page=2&extra=1')),
        LiveRequest.get(Uri.parse('https://api.example.test/list?page=2')),
        LiveRequest.get(Uri.parse('https://other.example.test/list?size=20&page=2')),
        LiveRequest.get(Uri.parse('https://api.example.test/lists?size=20&page=2')),
        LiveRequest.head(Uri.parse('https://api.example.test/list?size=20&page=2')),
      ]) {
        await expectLater(http.send(request), _unanswered('$request'), reason: '$request');
      }
    });

    test('ignoredQuery leaves signatures and clocks out of matching, sent or not', () async {
      final root = await _root();
      _sample(root, 'S01-list', url: 'https://api.example.test/list?page=2&sign=SCRUBBED&_=1', body: '{}');
      final http = ReplayHttp.fixtures(root.path, ['S01-list'], ignoredQuery: {'sign', '_'});

      final signed = await http.send(
        LiveRequest.get(Uri.parse('https://api.example.test/list?_=1790000000&sign=f00&page=2')),
      );
      final unsigned = await http.send(LiveRequest.get(Uri.parse('https://api.example.test/list?page=2')));

      expect([signed.statusCode, unsigned.statusCode], [200, 200]);
      // Matching cannot tell a missing signature: a test asserts it through
      // the recorded requests.
      expect(http.requests.first.url.queryParameters['sign'], 'f00');
      await expectLater(
        http.send(LiveRequest.get(Uri.parse('https://api.example.test/list?page=3&sign=f00'))),
        _unanswered('page=3'),
      );
    });

    test('a form POST matches its fields in any order, ignoring the listed ones', () async {
      final root = await _root();
      _sample(
        root,
        'S01-feed',
        method: 'POST',
        url: 'https://api.example.test/feed',
        requestBody: 'tab=rec&sign=SCRUBBED&title=two+words&sid=',
        body: '{"feed":1}',
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-feed'], ignoredQuery: {'sign'});
      final url = Uri.parse('https://api.example.test/feed');

      final response = await http.send(
        LiveRequest.form(url, fields: {'sid': '', 'title': 'two words', 'sign': 'fresh', 'tab': 'rec'}),
      );

      expect(response.text, '{"feed":1}');
      await expectLater(
        http.send(LiveRequest.form(url, fields: {'sid': '', 'title': 'two words', 'tab': 'news'})),
        _unanswered('tab=news'),
      );
      await expectLater(http.send(LiveRequest.get(url)), _unanswered('GET $url'));
    });

    test('a JSON POST matches structurally, ignoring the listed keys at any depth', () async {
      final root = await _root();
      for (final (name, gear) in [('S01-g1', 1), ('S01-g4', 4)]) {
        _sample(
          root,
          name,
          method: 'POST',
          url: 'https://api.example.test/streams?seq=1',
          requestBody: jsonEncode({
            'head': {'seq': 1, 'cid': '9'},
            'avp': {'gear': gear, 'send_time': 1},
          }),
          body: '{"gear":$gear}',
        );
      }
      final http = ReplayHttp.fixtures(root.path, ['S01-g1', 'S01-g4'], ignoredQuery: {'seq', 'send_time'});
      Map<String, Object?> body(int gear, int time) => {
        'avp': {'send_time': time, 'gear': gear},
        'head': {'cid': '9', 'seq': time},
      };
      Uri url(int time) => Uri.parse('https://api.example.test/streams?seq=$time');

      expect((await http.send(LiveRequest.json(url(77), body: body(4, 77)))).text, '{"gear":4}');
      // A binary body goes on the wire instead of the text one: it is read
      // the same way.
      final bytes = LiveRequest.custom(method: 'POST', url: url(78), bodyBytes: utf8.encode(jsonEncode(body(1, 78))));
      expect((await http.send(bytes)).text, '{"gear":1}');
      await expectLater(http.send(LiveRequest.json(url(79), body: body(2, 79))), _unanswered('POST'));
    });
  });

  group('answers', () {
    test('a response carries the status, the joined headers, the raw set-cookie lines and the body', () async {
      final root = await _root();
      _sample(
        root,
        'S01-login',
        url: 'https://api.example.test/login',
        body: '{"code":0,"title":"客厅"}',
        status: 403,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'set-cookie': ['a=1; path=/', 'b=2; expires=Wed, 09 Jun 2036 10:18:14 GMT'],
        },
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-login']);

      final response = await http.send(LiveRequest.get(Uri.parse('https://api.example.test/login')));

      expect([response.statusCode, response.isOk], [403, isFalse]);
      expect(response.headers, {
        'content-type': 'application/json; charset=utf-8',
        'set-cookie': 'a=1; path=/, b=2; expires=Wed, 09 Jun 2036 10:18:14 GMT',
      });
      expect(response.setCookies, ['a=1; path=/', 'b=2; expires=Wed, 09 Jun 2036 10:18:14 GMT']);
      expect((response.json! as Map<String, Object?>)['title'], '客厅');
    });

    test('every request is recorded, an unanswered one too; the first matching sample answers', () async {
      final http = ReplayHttp([
        ReplaySample(
          method: 'GET',
          url: Uri.parse('https://api.example.test/room'),
          statusCode: 200,
          bodyBytes: utf8.encode('first'),
        ),
      ]);
      final room = LiveRequest.get(Uri.parse('https://api.example.test/room'));
      final missing = LiveRequest.get(Uri.parse('https://api.example.test/missing'));

      expect((await http.send(room)).text, 'first');
      await expectLater(http.send(missing), _unanswered('GET https://api.example.test/missing'));
      // The platform answers differently from now on.
      http.samples.insert(
        0,
        ReplaySample(
          method: 'GET',
          url: Uri.parse('https://api.example.test/room'),
          statusCode: 200,
          bodyBytes: utf8.encode('second'),
        ),
      );
      expect((await http.send(room)).text, 'second');
      expect(http.requests, [room, missing, room]);
    });

    test('an empty replay answers nothing', () async {
      final http = ReplayHttp(const []);
      await expectLater(http.send(LiveRequest.get(Uri.parse('https://api.example.test/'))), throwsStateError);
      expect(http.requests, hasLength(1));
    });

    test('open streams the recorded body; a close before listening ends it empty', () async {
      final http = ReplayHttp([
        ReplaySample(
          method: 'GET',
          url: Uri.parse('https://cdn.example.test/live.flv'),
          statusCode: 200,
          headers: const {
            'content-type': ['video/x-flv'],
          },
          bodyBytes: Uint8List.fromList([0x46, 0x4c, 0x56, 0x01]),
        ),
      ]);
      final request = LiveRequest.get(Uri.parse('https://cdn.example.test/live.flv'));

      final read = await http.open(request);
      expect([read.statusCode, read.headers['content-type']], [200, 'video/x-flv']);
      expect(await read.stream.expand((chunk) => chunk).toList(), [0x46, 0x4c, 0x56, 0x01]);

      final closed = await http.open(request);
      await closed.close();
      expect(await closed.stream.toList(), isEmpty);
      await closed.close();
      expect(http.requests, hasLength(2));
    });

    test('a request cancelled before it is sent fails as cancelled, as on the wire', () async {
      final http = ReplayHttp([
        ReplaySample(
          method: 'GET',
          url: Uri.parse('https://api.example.test/room'),
          statusCode: 200,
          bodyBytes: Uint8List(0),
        ),
      ]);
      final token = CancelToken()..cancel('left the page');

      await expectLater(
        http.send(LiveRequest.get(Uri.parse('https://api.example.test/room'), cancelToken: token)),
        throwsA(isA<CancelledFailure>().having((failure) => failure.cause, 'cause', 'left the page')),
      );
      await expectLater(
        http.open(LiveRequest.get(Uri.parse('https://api.example.test/room'), cancelToken: token)),
        throwsA(isA<CancelledFailure>()),
      );
      expect(http.requests, hasLength(2));
    });
  });

  group('schema 2', () {
    test('a sequence answers in call order and repeats its last answer', () async {
      final root = await _root();
      _sample2(
        root,
        'S01-poll',
        url: 'https://api.example.test/feed',
        answers: [
          {'status': 200, 'body': 'body-1.json'},
          {'status': 500},
          {'status': 200, 'body': 'body-3.json', 'headers': {'content-type': 'application/json'}},
        ],
        bodies: {'body-1.json': '{"poll":1}', 'body-3.json': '{"poll":3}'},
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-poll']);
      final request = LiveRequest.get(Uri.parse('https://api.example.test/feed'));

      final answers = [await http.send(request), await http.send(request), await http.send(request), await http.send(request)];

      expect([for (final answer in answers) answer.text], ['{"poll":1}', '', '{"poll":3}', '{"poll":3}'],
          reason: 'the last answer repeats once the sequence runs out');
      expect(answers[2].headers, {'content-type': 'application/json'});
      expect(answers[1].isOk, isFalse);
      expect(http.requests, hasLength(4));
    });

    test('a connect answer fails the request before any response, send or open', () async {
      final root = await _root();
      _sample2(root, 'S01-offline', url: 'https://api.example.test/room', answers: [
        {'kind': 'connect', 'description': 'dns down'},
      ]);
      final http = ReplayHttp.fixtures(root.path, ['S01-offline']);
      final request = LiveRequest.get(Uri.parse('https://api.example.test/room'));

      await expectLater(
        http.send(request),
        throwsA(isA<ConnectFailure>().having((failure) => failure.description, 'description', 'dns down')),
      );
      await expectLater(http.open(request), throwsA(isA<ConnectFailure>()));
      expect(http.requests, hasLength(2), reason: 'the failed requests are recorded all the same');
    });

    test('a sequence may mix a connect failure and a response, call by call', () async {
      final root = await _root();
      _sample2(
        root,
        'S01-flaky',
        url: 'https://api.example.test/room',
        answers: [
          {'kind': 'connect', 'description': 'down'},
          {'status': 200, 'body': 'body-2.json'},
        ],
        bodies: {'body-2.json': '{"room":2}'},
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-flaky']);
      final request = LiveRequest.get(Uri.parse('https://api.example.test/room'));

      await expectLater(http.send(request), throwsA(isA<ConnectFailure>()));
      expect((await http.send(request)).text, '{"room":2}');
      expect((await http.send(request)).text, '{"room":2}', reason: 'the response repeats');
      expect(http.requests, hasLength(3));
    });

    test('a hang answer never completes until the caller cancels, then fails as cancelled', () async {
      final root = await _root();
      _sample2(root, 'S01-hold', url: 'https://api.example.test/slow', answers: [
        {'kind': 'hang'},
      ]);
      final http = ReplayHttp.fixtures(root.path, ['S01-hold']);

      final token = CancelToken();
      final pending = http.send(LiveRequest.get(Uri.parse('https://api.example.test/slow'), cancelToken: token));
      var answered = false;
      unawaited(pending.then((_) => answered = true, onError: (Object _) => answered = true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(answered, isFalse, reason: 'the host accepted and never answers');
      expect(http.requests, hasLength(1));

      token.cancel('left the page');
      await expectLater(
        pending,
        throwsA(isA<CancelledFailure>().having((failure) => failure.cause, 'cause', 'left the page')),
      );

      final openToken = CancelToken();
      final opened = http.open(LiveRequest.get(Uri.parse('https://api.example.test/slow'), cancelToken: openToken));
      openToken.cancel('gone');
      await expectLater(opened, throwsA(isA<CancelledFailure>()));
      expect(http.requests, hasLength(2));
    });

    test('a broken answer streams its chunks and ends closed, interrupted or stalled', () async {
      final root = await _root();
      _sample2(
        root,
        'S01-cut',
        url: 'https://cdn.example.test/live.flv',
        answers: [
          {'kind': 'broken', 'body': 'body.flv', 'chunks': [3, 4], 'end': 'closed'},
        ],
        bodies: {'body.flv': 'abcdefghij'},
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-cut']);
      final request = LiveRequest.get(Uri.parse('https://cdn.example.test/live.flv'));

      final read = await http.open(request) as ReplayStreamedResponse;
      expect(await read.stream.toList(), [
        utf8.encode('abc'),
        utf8.encode('defg'),
      ], reason: 'the last three bytes never arrive');
      expect(read.closed, isFalse, reason: 'a body read to its end is not the consumer ending it');
      expect(http.opens.single, same(read));

      // A buffered send holds the bytes the chunks delivered.
      expect((await http.send(request)).text, 'abcdefg');
    });

    test('an interrupted broken answer fails the stream and the buffered send', () async {
      final root = await _root();
      _sample2(
        root,
        'S01-reset',
        url: 'https://cdn.example.test/live.flv',
        answers: [
          {'kind': 'broken', 'body': 'body.flv', 'chunks': [3], 'end': 'interrupted'},
        ],
        bodies: {'body.flv': 'abcdefghij'},
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-reset']);
      final request = LiveRequest.get(Uri.parse('https://cdn.example.test/live.flv'));

      final read = await http.open(request);
      await expectLater(read.stream.toList(), throwsA(isA<ProtocolFailure>()));
      await expectLater(http.send(request), throwsA(isA<ProtocolFailure>()));
    });

    test('a stalled broken answer ends only when the consumer stops reading', () async {
      final root = await _root();
      _sample2(
        root,
        'S01-stall',
        url: 'https://cdn.example.test/live.flv',
        answers: [
          {'kind': 'broken', 'body': 'body.flv', 'chunks': [3, 7], 'end': 'stalled'},
        ],
        bodies: {'body.flv': 'abcdefghij'},
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-stall']);
      final read =
          (await http.open(LiveRequest.get(Uri.parse('https://cdn.example.test/live.flv'))))
              as ReplayStreamedResponse;

      final iterator = StreamIterator(read.stream);
      final chunks = <String>[for (var n = 0; n < 2 && await iterator.moveNext(); n++) utf8.decode(iterator.current)];
      expect(chunks, ['abc', 'defghij']);
      await iterator.cancel();
      expect(read.closed, isTrue, reason: 'the consumer stopped a stream that never ends');
    });

    test('a response the consumer closes reports closed and reads back empty', () async {
      final root = await _root();
      _sample2(
        root,
        'S01-refused',
        url: 'https://cdn.example.test/live.flv',
        answers: [
          {'status': 404},
        ],
      );
      final http = ReplayHttp.fixtures(root.path, ['S01-refused']);
      final read =
          (await http.open(LiveRequest.get(Uri.parse('https://cdn.example.test/live.flv'))))
              as ReplayStreamedResponse;

      await read.close();
      expect(read.closed, isTrue);
      expect(await read.stream.toList(), isEmpty, reason: 'reading after a close ends without an error');
      await read.close();
      expect(http.opens, hasLength(1));
    });

    test('a sample the meta cannot spell fails the load loudly', () async {
      final root = await _root();
      _sample2(root, 'S01-heavy', url: 'https://cdn.example.test/live.flv', answers: [
        {'kind': 'broken', 'body': 'body.flv', 'chunks': [50]},
      ], bodies: {'body.flv': 'abc'});
      _sample2(root, 'S01-mystery', url: 'https://api.example.test/room', answers: [
        {'kind': 'quantum'},
      ]);
      Directory('${root.path}/S01-ancient').createSync();
      File('${root.path}/S01-ancient/meta.json').writeAsStringSync(
        jsonEncode({
          'schema': 3,
          'platform': 'example',
          'sample': 'S01-ancient',
          'request': {'method': 'GET', 'url': 'https://api.example.test/room'},
          'response': {'status': 200, 'headers': <String, String>{}},
          'body': 'body.json',
        }),
      );

      expect(() => ReplayHttp.fixtures(root.path, ['S01-heavy']), throwsArgumentError);
      expect(() => ReplayHttp.fixtures(root.path, ['S01-mystery']), throwsArgumentError);
      expect(() => ReplayHttp.fixtures(root.path, ['S01-ancient']), throwsArgumentError);
    });
  });
}
