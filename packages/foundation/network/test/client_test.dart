// Module: test/client_test.dart
// Purpose: Verify status classification, retry behaviour and size ceilings against a scripted adapter.
// Author: liuchuancong
// Created: 2026-10-08
//
// No test here touches the network: the adapter is scripted, so a failure path is exercised deterministically
// and the retry counter is observable.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live_logging/pure_live_logging.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:test/test.dart';

/// Returns a fixed sequence of outcomes, one per call, and records what it was asked to do.
final class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.outcomes);

  final List<Future<ResponseBody> Function(RequestOptions options)> outcomes;
  final List<RequestOptions> requests = <RequestOptions>[];
  int _calls = 0;

  int get callCount => _calls;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    final index = _calls < outcomes.length ? _calls : outcomes.length - 1;
    _calls++;
    return outcomes[index](options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(String text, int status, {Map<String, String>? headers}) {
  return ResponseBody.fromString(
    text,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
      for (final entry in (headers ?? const <String, String>{}).entries) entry.key: <String>[entry.value],
    },
  );
}

NetworkSettings _fast({int attempts = 3}) => NetworkSettings(attempts: attempts, retryDelay: Duration.zero);

void main() {
  test('test_client_ok_returnsBodyAndSendsUserAgent', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => _body('{"ok":true}', 200),
    ]);
    final client = NetworkClient(
      settings: _fast(),
      adapter: adapter,
      options: BaseOptions(headers: <String, String>{'user-agent': 'PureLiveTest'}, validateStatus: (_) => true),
    );

    final json = await client.getJson('https://example.com/api');

    expect(json['ok'], isTrue);
    expect(adapter.requests.single.headers['user-agent'], 'PureLiveTest');
    client.close();
  });

  test('test_client_notFound_failsOnceWithoutRetry', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[(_) async => _body('nope', 404)]);
    final client = NetworkClient(settings: _fast(attempts: 3), adapter: adapter);

    await expectLater(
      client.get('https://example.com/gone'),
      throwsA(
        isA<NetworkFailure>()
            .having((f) => f.kind, 'kind', NetworkFailureKind.httpStatus)
            .having((f) => f.statusCode, 'statusCode', 404)
            .having((f) => f.retryable, 'retryable', isFalse)
            .having((f) => f.code, 'code', 'network.http_status'),
      ),
    );
    expect(adapter.callCount, 1);
    client.close();
  });

  test('test_client_serverError_retriesUpToTheAttemptBudget', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[(_) async => _body('boom', 503)]);
    final client = NetworkClient(settings: _fast(attempts: 3), adapter: adapter);

    await expectLater(client.get('https://example.com/flaky'), throwsA(isA<NetworkFailure>()));
    expect(adapter.callCount, 3);
    client.close();
  });

  test('test_client_rateLimited_isClassifiedAndRetried', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => _body('slow down', 429),
      (_) async => _body('{"ok":1}', 200),
    ]);
    final client = NetworkClient(settings: _fast(attempts: 3), adapter: adapter);

    final json = await client.getJson('https://example.com/limited');

    expect(json['ok'], 1);
    expect(adapter.callCount, 2);
    client.close();
  });

  test('test_client_forbidden_isNotRetried', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => _body('denied', 403),
    ]);
    final client = NetworkClient(settings: _fast(attempts: 4), adapter: adapter);

    await expectLater(
      client.get('https://example.com/private'),
      throwsA(
        isA<NetworkFailure>()
            .having((f) => f.kind, 'kind', NetworkFailureKind.forbidden)
            .having((f) => f.code, 'code', 'network.forbidden'),
      ),
    );
    expect(adapter.callCount, 1);
    client.close();
  });

  test('test_client_connectionTimeout_isRetriedAsTimeout', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => throw DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: 'https://example.com/slow'),
      ),
      (_) async => _body('{"ok":1}', 200),
    ]);
    final client = NetworkClient(settings: _fast(attempts: 2), adapter: adapter);

    // A timeout is transient, so the second attempt is allowed to succeed.
    final json = await client.getJson('https://example.com/slow');

    expect(json['ok'], 1);
    expect(adapter.callCount, 2);
    client.close();
  });

  test('test_client_timeoutThenFailure_reportsTimeoutCode', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => throw DioException(
        type: DioExceptionType.receiveTimeout,
        requestOptions: RequestOptions(path: 'https://example.com/slow'),
      ),
    ]);
    final client = NetworkClient(settings: _fast(attempts: 2), adapter: adapter);

    await expectLater(
      client.get('https://example.com/slow'),
      throwsA(
        isA<NetworkFailure>()
            .having((f) => f.kind, 'kind', NetworkFailureKind.timeout)
            .having((f) => f.code, 'code', 'network.timeout')
            .having((f) => f.retryable, 'retryable', isTrue),
      ),
    );
    expect(adapter.callCount, 2);
    client.close();
  });

  test('test_client_cancelledRequest_isNotRetried', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => throw DioException(
        type: DioExceptionType.cancel,
        requestOptions: RequestOptions(path: 'https://example.com/live'),
      ),
    ]);
    final client = NetworkClient(settings: _fast(attempts: 5), adapter: adapter);
    final token = CancelToken();

    await expectLater(
      client.get('https://example.com/live', cancelToken: token),
      throwsA(
        isA<NetworkFailure>()
            .having((f) => f.kind, 'kind', NetworkFailureKind.cancelled)
            .having((f) => f.retryable, 'retryable', isFalse),
      ),
    );
    expect(adapter.callCount, 1);
    client.close();
  });

  test('test_client_oversizedContentLength_isRejectedBeforeReading', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => _body('{"ok":1}', 200, headers: <String, String>{'content-length': '999999999'}),
    ]);
    final client = NetworkClient(
      settings: NetworkSettings(attempts: 1, retryDelay: Duration.zero, maxResponseBytes: 1024),
      adapter: adapter,
    );

    await expectLater(
      client.get('https://example.com/huge'),
      throwsA(
        isA<NetworkFailure>()
            .having((f) => f.kind, 'kind', NetworkFailureKind.responseTooLarge)
            .having((f) => f.code, 'code', 'network.response_too_large'),
      ),
    );
    client.close();
  });

  test('test_client_emptyBody_reportsTheUrlThatFailed', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[(_) async => _body('', 200)]);
    final client = NetworkClient(settings: _fast(attempts: 1), adapter: adapter);

    await expectLater(
      client.getJson('https://example.com/empty'),
      throwsA(isA<NetworkFailure>().having((f) => f.toString(), 'description', contains('https://example.com/empty'))),
    );
    client.close();
  });

  test('test_client_jsonArrayBody_isRejectedAsUnexpectedShape', () async {
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => _body(jsonEncode(<int>[1, 2]), 200),
    ]);
    final client = NetworkClient(settings: _fast(attempts: 1), adapter: adapter);

    await expectLater(
      client.getJson('https://example.com/list'),
      throwsA(isA<NetworkFailure>().having((f) => f.cause! as String, 'cause', contains('expected a JSON object'))),
    );
    client.close();
  });

  test('test_client_retryIsLoggedWithRedactedUrl', () async {
    final sink = MemoryLogSink();
    final router = LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug);
    final adapter = _ScriptedAdapter(<Future<ResponseBody> Function(RequestOptions)>[
      (_) async => _body('again', 500),
      (_) async => _body('{"ok":1}', 200),
    ]);
    final client = NetworkClient(settings: _fast(attempts: 2), adapter: adapter, logger: router.logger('network'));

    await client.getJson('https://example.com/v.m3u8?token=abc');

    final retry = sink.records.firstWhere((record) => record.message == 'retrying request');
    expect(retry.fields['playUrl'], contains('token=***'));
    expect(retry.fields['playUrl'], isNot(contains('abc')));
    client.close();
  });
}
