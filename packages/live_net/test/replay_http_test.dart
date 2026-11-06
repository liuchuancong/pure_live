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
}
