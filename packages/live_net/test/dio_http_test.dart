import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_net/live_net.dart';
import 'package:live_net/src/http/dio_http.dart';
import 'package:test/test.dart';

import 'support/test_server.dart';

/// Starts a loopback server registered for teardown with the current test.
Future<TestServer> startServer(FutureOr<void> Function(HttpRequest request) handler) async {
  final server = await TestServer.start(handler);
  addTearDown(server.close);
  return server;
}

void main() {
  late DioLiveHttp http;

  setUp(() {
    http = DioLiveHttp();
    addTearDown(http.close);
  });

  group('send', () {
    test('GET round trip returns status, headers and JSON body', () async {
      final server = await startServer((request) async {
        expect(request.uri.path, '/room/1');
        expect(request.headers.value('x-probe'), 'probe-value');
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"code":0,"title":"客厅"}');
        await request.response.close();
      });

      final response = await http.send(
        LiveRequest.get(server.url.replace(path: '/room/1'), headers: {'x-probe': 'probe-value'}),
      );

      expect(response.statusCode, 200);
      expect(response.isOk, isTrue);
      expect(response.headers['content-type'], contains('application/json'));
      expect((response.json! as Map<String, Object?>)['title'], '客厅');
    });

    test('repeated Set-Cookie headers are kept per-line in setCookies', () async {
      final server = await startServer((request) async {
        request.response.headers.add('set-cookie', 'acf_jwt_token=NEW; path=/; secure');
        request.response.headers.add('set-cookie', 'LTP0=abc; path=/; expires=Wed, 09 Jun 2036 10:18:14 GMT');
        request.response.write('ok');
        await request.response.close();
      });

      final response = await http.send(LiveRequest.get(server.url));

      // The joined header cannot be split back (the expires date holds a comma),
      // but the per-line list keeps both cookies whole.
      expect(response.setCookies, hasLength(2));
      expect(response.setCookies.first, startsWith('acf_jwt_token=NEW'));
      expect(response.setCookies.last, startsWith('LTP0=abc'));
    });

    test('a malformed Secure attribute does not fail a valid response', () async {
      // Douyin has served `Set-Cookie: …; Secure=<value>`; dart:io rejects
      // that attribute, but the page's 200 must still reach the caller.
      final server = await startServer((request) async {
        request.response.headers.add('set-cookie', 'acf_jwt_token=NEW; path=/; Secure=abc');
        request.response.write('ok');
        await request.response.close();
      });

      final response = await http.send(LiveRequest.get(server.url));

      expect(response.statusCode, 200);
      expect(response.isOk, isTrue);
      expect(response.text, 'ok');
    });

    test('form POST reaches the server as urlencoded fields', () async {
      final server = await startServer((request) async {
        final body = await utf8.decoder.bind(request).join();
        expect(request.headers.value('content-type'), startsWith('application/x-www-form-urlencoded'));
        final fields = Uri(query: body).queryParameters;
        request.response.write(fields['name']);
        await request.response.close();
      });

      final response = await http.postForm(server.url, fields: {'name': '虎牙-01'});

      expect(response.isOk, isTrue);
      expect(response.text, '虎牙-01');
    });

    test('json POST keeps the content type and body intact', () async {
      final server = await startServer((request) async {
        final body = await utf8.decoder.bind(request).join();
        expect(request.headers.value('content-type'), startsWith('application/json'));
        final decoded = jsonDecode(body) as Map<String, Object?>;
        request.response.write('{"echo":"${decoded["name"]}"}');
        await request.response.close();
      });

      final result = await http.postJson(server.url, body: {'name': 'douyu'});

      expect((result! as Map<String, Object?>)['echo'], 'douyu');
    });

    test('error statuses are responses, not exceptions', () async {
      final server = await startServer((request) async {
        request.response.statusCode = 503;
        request.response.write('busy');
        await request.response.close();
      });

      final response = await http.send(LiveRequest.get(server.url));

      expect(response.statusCode, 503);
      expect(response.isOk, isFalse);
      expect(response.text, 'busy');
    });

    test('latin-1 charset is honoured by the text getter', () async {
      final server = await startServer((request) async {
        request.response.headers.set('content-type', 'text/plain; charset=iso-8859-1');
        request.response.add(latin1.encode('caf\u00e9'));
        await request.response.close();
      });

      final response = await http.send(LiveRequest.get(server.url));

      expect(response.text, 'café');
    });

    test('connection refused becomes ConnectFailure', () async {
      final port = await _freePort();

      await expectLater(
        http.send(LiveRequest.get(Uri.parse('http://127.0.0.1:$port/x'))),
        throwsA(isA<ConnectFailure>()),
      );
    });
  });

  group('open', () {
    test('streams chunked body incrementally', () async {
      final server = await startServer((request) async {
        request.response.bufferOutput = false;
        for (final chunk in ['a', 'b', 'c']) {
          request.response.write(chunk);
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await request.response.close();
      });

      final streamed = await http.open(LiveRequest.get(server.url));
      final chunks = await streamed.stream.map(utf8.decode).fold<String>('', (a, b) => a + b);

      expect(streamed.statusCode, 200);
      expect(chunks, 'abc');
    });

    test('close mid-stream ends the stream without an error', () async {
      final server = await startServer((request) async {
        request.response.bufferOutput = false;
        for (var i = 0; i < 100; i++) {
          request.response.write('x');
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await request.response.close();
      });

      final streamed = await http.open(LiveRequest.get(server.url));
      final received = <int>[];
      var endedCleanly = false;
      final done = Completer<void>();
      streamed.stream.listen(
        received.addAll,
        onDone: () {
          endedCleanly = true;
          done.complete();
        },
        onError: done.completeError,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await streamed.close();
      await done.future.timeout(const Duration(seconds: 3));

      expect(endedCleanly, isTrue);
      expect(received.length, lessThan(100));
    });
  });

  group('timeouts and cancellation', () {
    test('slow response surfaces as TimeoutFailure', () async {
      final server = await startServer((request) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await request.response.close();
      });

      await expectLater(
        http.send(LiveRequest.get(server.url, timeout: const Duration(milliseconds: 150))),
        throwsA(isA<TimeoutFailure>()),
      );
    });

    test('cancelled request surfaces as CancelledFailure', () async {
      final server = await startServer((request) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        await request.response.close();
      });

      final token = CancelToken();
      final future = http.send(LiveRequest.get(server.url, cancelToken: token));
      Timer(const Duration(milliseconds: 100), token.cancel);

      await expectLater(future, throwsA(isA<CancelledFailure>()));
      expect(token.isCancelled, isTrue);
    });
  });
}

/// Returns a loopback port that is currently free.
Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
