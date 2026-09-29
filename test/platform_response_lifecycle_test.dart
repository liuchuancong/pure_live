import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart' as shared;
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/site/inke/inke_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_api.dart';
import 'package:pure_live/core/site/missevan/missevan_api.dart';
import 'package:pure_live/core/site/picarto/picarto_api.dart';
import 'package:pure_live/core/site/twitcasting/twitcasting_api.dart';
import 'package:pure_live/core/site/xiaohongshu/xiaohongshu_api.dart';
import 'package:pure_live/core/site/xiaohongshu/xiaohongshu_share.dart';
import 'package:pure_live/core/site/weibo/weibo_api.dart';

typedef _Read = Future<Object?> Function(CancelToken?);
typedef _Case = ({String name, _Read read, String body, int cap});
final _cases = <_Case>[
  (
    name: 'Weibo',
    read: (c) => WeiboApi().directory(cancel: c),
    body: '{"code":100000,"error_code":0,"data":{"data":[]}}',
    cap: WeiboApi.responseLimit,
  ),
  (
    name: 'Xiaohongshu',
    read: (c) => XiaohongshuApi().room('123', cancel: c),
    body: '<script>window.__INITIAL_STATE__={"liveStream":{"pageStatus":"success","liveStatus":"end","roomData":{"roomInfo":{"status":3},"hostInfo":{}}}}</script>',
    cap: XiaohongshuShare.responseLimit,
  ),
  (
    name: 'Picarto',
    read: (c) => PicartoApi().read(Uri.parse('https://picarto.tv/fixture'), cancel: c),
    body: 'fixture',
    cap: 1024 * 1024,
  ),
  (
    name: 'Inke',
    read: (c) => InkeApi().categories(cancel: c),
    body: '{"error_code":0,"data":{"list":[]}}',
    cap: InkeApi.responseLimit,
  ),
  (
    name: 'Kilakila',
    read: (c) => KilakilaApi().recommendations(cancel: c),
    body: '{"code":200,"data":{"body":{"h":{"code":200,"success":true}}}}',
    cap: KilakilaApi.responseLimit,
  ),
  (
    name: 'Missevan',
    read: (c) => MissevanApi().directoryPage(cancel: c),
    body: '{"code":0,"info":{"pagination":{"p":1,"pagesize":20,"maxpage":0,"count":0},"Datas":[]}}',
    cap: MissevanApi.responseLimit,
  ),
  (
    name: 'TwitCasting',
    read: (c) => TwitcastingApi().read(Uri.parse('https://twitcasting.tv/fixture'), cancel: c),
    body: 'fixture',
    cap: 1024 * 1024,
  ),
];

String _kind(Object? error) => switch (error) {
  PicartoException e => e.kind.name,
  InkeException e => e.kind.name,
  KilakilaException e => e.kind.name,
  MissevanException e => e.kind.name,
  TwitcastingException e => e.kind.name,
  XiaohongshuException e => e.kind.name,
  WeiboException e => e.kind.name,
  _ => '${error.runtimeType}',
};
Matcher _failure(String kind) => throwsA(predicate<Object>((e) => _kind(e) == kind, kind));

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

class _Source {
  _Source({List<int>? initial}) {
    controller = StreamController<Uint8List>(
      onListen: () {
        listened.complete();
        if (initial != null) controller.add(Uint8List.fromList(initial));
      },
      onCancel: () {
        cancellations++;
      },
    );
  }
  late final StreamController<Uint8List> controller;
  final listened = Completer<void>();
  int cancellations = 0;
  ResponseBody body(int status) => ResponseBody(controller.stream, status);
  void add(String text) => controller.add(Uint8List.fromList(utf8.encode(text)));
  Future<void> close() => controller.close();
}

Future<void> _withDio(Future<ResponseBody> Function(RequestOptions) respond, Future<void> Function() run) async {
  final original = shared.HttpClient.instance.dio;
  final dio = Dio(BaseOptions(receiveTimeout: const Duration(seconds: 60)))..httpClientAdapter = _Adapter(respond);
  shared.HttpClient.instance.dio = dio;
  try {
    await run();
  } finally {
    shared.HttpClient.instance.dio = original;
    dio.close();
  }
}

void main() {
  test('request scope cancels before dispatch when caller is already cancelled', () async {
    final caller = CancelToken()..cancel();
    await withRequestCancellation(caller, (transport) async {
      expect(transport.isCancelled, isTrue);
      expect(identical(transport, caller), isFalse);
    });
  });

  test('request scope preserves original synchronous failure and closes only its token', () async {
    final caller = CancelToken();
    final error = StateError('fixture');
    CancelToken? scoped;
    await expectLater(
      withRequestCancellation<void>(caller, (transport) {
        scoped = transport;
        throw error;
      }),
      throwsA(same(error)),
    );
    expect(scoped!.isCancelled, isTrue);
    expect(caller.isCancelled, isFalse);
  });

  for (final platform in _cases) {
    test('${platform.name}: HTTP error closes upstream, not just transformed stream', () async {
      final source = _Source();
      final caller = CancelToken();
      try {
        await _withDio((_) async => source.body(403), () async {
          await expectLater(platform.read(caller), _failure('access'));
          expect(source.cancellations, 1);
          expect(caller.isCancelled, isFalse);
        });
      } finally {
        await source.close();
      }
    });

    test('${platform.name}: byte overflow closes upstream and preserves caller token', () async {
      final source = _Source(initial: Uint8List(platform.cap + 1));
      final caller = CancelToken();
      try {
        await _withDio((_) async => source.body(200), () async {
          await expectLater(platform.read(caller), _failure('schema'));
          expect(source.cancellations, 1);
          expect(caller.isCancelled, isFalse);
        });
      } finally {
        await source.close();
      }
    });

    test('${platform.name}: completed response preserves shared caller and supports next request', () async {
      final caller = CancelToken();
      final tokens = <CancelToken?>[];
      await _withDio(
        (options) async {
          tokens.add(options.cancelToken);
          return ResponseBody.fromString(platform.body, 200);
        },
        () async {
          expect(await platform.read(caller), isNotNull);
          expect(caller.isCancelled, isFalse);
          expect(await platform.read(caller), isNotNull);
          expect(caller.isCancelled, isFalse);
          expect(tokens, hasLength(2));
          expect(identical(tokens.first, tokens.last), isFalse);
          expect(tokens.every((token) => token?.isCancelled == true), isTrue);
        },
      );
    });

    test('${platform.name}: a failed sibling does not stop an in-flight shared-token request', () async {
      final failure = _Source();
      final pending = _Source();
      final caller = CancelToken();
      var calls = 0;
      try {
        await _withDio((_) async => ++calls == 1 ? pending.body(200) : failure.body(503), () async {
          final waiting = platform.read(caller);
          await pending.listened.future;
          await expectLater(platform.read(caller), _failure('service'));
          expect(pending.cancellations, 0);
          expect(caller.isCancelled, isFalse);
          pending.add(platform.body);
          await pending.close();
          expect(await waiting, isNotNull);
        });
      } finally {
        await failure.close();
        await pending.close();
      }
    });

    test('${platform.name}: caller cancellation reaches stalled upstream', () async {
      final source = _Source();
      final caller = CancelToken();
      try {
        await _withDio((_) async => source.body(200), () async {
          final check = expectLater(platform.read(caller), _failure('cancelled'));
          await source.listened.future;
          caller.cancel();
          await check;
          expect(source.cancellations, 1);
        });
      } finally {
        await source.close();
      }
    });

    test('${platform.name}: already cancelled caller dispatches no adapter request', () async {
      var calls = 0;
      await _withDio(
        (_) async {
          calls++;
          return ResponseBody.fromString(platform.body, 200);
        },
        () async {
          await expectLater(platform.read(CancelToken()..cancel()), _failure('cancelled'));
          expect(calls, 0);
        },
      );
    });
  }

  test('Picarto injected text enforces the production UTF8 byte limit', () async {
    final body = jsonEncode({'fixture': '中' * 360000});
    expect(body.length, lessThan(1024 * 1024));
    final api = PicartoApi(request: (_, _) async => (status: 200, body: body));
    await expectLater(api.read(Uri.parse('https://picarto.tv/fixture')).then<void>((_) {}), _failure('schema'));
  });

  test('Picarto direct object parsing enforces the UTF8 byte limit', () {
    final body = jsonEncode({'fixture': '中' * 360000});
    expect(body.length, lessThan(1024 * 1024));
    expect(() {
      PicartoApi.object(body);
    }, _failure('schema'));
  });

  test('Picarto cancellation dominates a coincident typed request error', () async {
    final caller = CancelToken();
    final api = PicartoApi(
      request: (_, _) async {
        caller.cancel();
        throw const PicartoException(PicartoFailure.schema);
      },
    );
    await expectLater(api.read(Uri.parse('https://picarto.tv/fixture'), cancel: caller), _failure('cancelled'));
  });

  test('Picarto body preserves split UTF8 and exact cap, rejecting invalid and excess bytes', () async {
    final bytes = utf8.encode('中文');
    expect(await PicartoApi.readBody(Stream.fromIterable([bytes.sublist(0, 1), bytes.sublist(1)])), '中文');
    expect(
      (await PicartoApi.readBody(Stream.value(Uint8List(PicartoApi.responseLimit)))).length,
      PicartoApi.responseLimit,
    );
    await expectLater(PicartoApi.readBody(Stream.value([255])), _failure('schema'));
    await expectLater(PicartoApi.readBody(Stream.value(Uint8List(PicartoApi.responseLimit + 1))), _failure('schema'));
  });

  test('Picarto standalone body deadline closes a stalled source', () async {
    var closed = false;
    final source = StreamController<List<int>>(
      onCancel: () {
        closed = true;
      },
    );
    await expectLater(
      PicartoApi.readBody(source.stream, timeout: const Duration(milliseconds: 30)),
      throwsA(isA<TimeoutException>()),
    );
    expect(closed, isTrue);
    await source.close();
  });

  test('Picarto transport stream error releases its scope without cancelling the caller', () async {
    final source = _Source();
    final caller = CancelToken();
    CancelToken? transport;
    try {
      await _withDio(
        (options) async {
          transport = options.cancelToken;
          return source.body(200);
        },
        () async {
          final check = expectLater(
            PicartoApi().read(Uri.parse('https://picarto.tv/fixture'), cancel: caller),
            _failure('transport'),
          );
          await source.listened.future;
          source.controller.addError(StateError('fixture upstream error'));
          await check;
          expect(source.cancellations, 1);
          expect(transport!.isCancelled, isTrue);
          expect(caller.isCancelled, isFalse);
        },
      );
    } finally {
      await source.close();
    }
  });

  test('TwitCasting injected text and object parsing enforce UTF8 byte limits', () async {
    final body = jsonEncode({'fixture': List.filled(360000, '中').join()});
    expect(body.length, lessThan(TwitcastingApi.responseLimit));
    final api = TwitcastingApi(request: (_, _) async => (status: 200, body: body));
    await expectLater(api.read(Uri.parse('https://twitcasting.tv/fixture')), _failure('schema'));
    expect(() => TwitcastingApi.object(body), _failure('schema'));
  });

  test('TwitCasting cancellation dominates a coincident typed request error', () async {
    final caller = CancelToken();
    final api = TwitcastingApi(
      request: (_, _) async {
        caller.cancel();
        throw const TwitcastingException(TwitcastingFailure.schema);
      },
    );
    await expectLater(api.read(Uri.parse('https://twitcasting.tv/fixture'), cancel: caller), _failure('cancelled'));
  });

  test('TwitCasting body preserves split UTF8, exact cap and rejects invalid UTF8', () async {
    final bytes = utf8.encode('中文');
    expect(await TwitcastingApi.readBody(Stream.fromIterable([bytes.sublist(0, 1), bytes.sublist(1)])), '中文');
    expect(
      (await TwitcastingApi.readBody(Stream.value(Uint8List(TwitcastingApi.responseLimit)))).length,
      TwitcastingApi.responseLimit,
    );
    await expectLater(TwitcastingApi.readBody(Stream.value([255])), _failure('schema'));
  });

  test('continuous small chunks obey total body deadline and close all upstream sources', () async {
    // A 60-second inactivity timeout cannot explain termination of a response
    // that emits a chunk every second. Exercise each API's real 20-second cap.
    final sources = <_Source>[];
    final timers = <Timer>[];
    final failures = <String>[];
    try {
      await _withDio(
        (_) async {
          final source = _Source(initial: [32]);
          sources.add(source);
          timers.add(
            Timer.periodic(const Duration(seconds: 1), (_) {
              source.add(' ');
            }),
          );
          return source.body(200);
        },
        () async {
          await Future.wait(
            _cases.map((platform) async {
              Object? result;
              try {
                await platform.read(null).timeout(const Duration(seconds: 24));
              } catch (error) {
                result = error;
              }
              if (_kind(result) != 'transport') failures.add('${platform.name}: ${_kind(result)}');
            }),
          );
          expect(failures, isEmpty);
          expect(sources, hasLength(_cases.length));
          expect(sources.map((s) => s.cancellations), everyElement(1));
        },
      );
    } finally {
      for (final timer in timers) {
        timer.cancel();
      }
      for (final source in sources) {
        await source.close();
      }
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}
