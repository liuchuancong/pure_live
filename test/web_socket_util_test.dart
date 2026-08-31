import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('a silent half-open socket is closed and reconnected on the next endpoint', () async {
    final endpoints = <String>[];
    final channels = <_FakeWebSocketChannel>[];
    final socket = WebScoketUtils(
      url: 'wss://primary.example/ws',
      serverUrls: const ['wss://primary.example/ws', 'wss://backup.example/ws'],
      heartBeatTime: 10,
      inactivityTimeout: const Duration(milliseconds: 25),
      reconnectBaseDelay: const Duration(milliseconds: 5),
      connector: (endpoint, {connectTimeout, protocols, headers, customClient}) {
        endpoints.add(endpoint);
        final channel = _FakeWebSocketChannel();
        channels.add(channel);
        return channel;
      },
    );

    await socket.connect();
    expect(socket.status, SocketStatus.connected);

    await Future<void>.delayed(const Duration(milliseconds: 55));

    expect(endpoints.length, greaterThanOrEqualTo(2));
    expect(endpoints.take(2), ['wss://primary.example/ws', 'wss://backup.example/ws']);
    expect(channels.first.outgoing.closed, isTrue);

    await socket.close();
    final connectionCount = endpoints.length;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(endpoints.length, connectionCount, reason: 'manual close must cancel watchdog reconnects');
  });

  test('incoming heartbeat traffic keeps one connection alive', () async {
    late _FakeWebSocketChannel channel;
    var connectionCount = 0;
    final socket = WebScoketUtils(
      url: 'wss://primary.example/ws',
      heartBeatTime: 10,
      inactivityTimeout: const Duration(milliseconds: 40),
      reconnectBaseDelay: const Duration(milliseconds: 5),
      connector: (endpoint, {connectTimeout, protocols, headers, customClient}) {
        connectionCount++;
        channel = _FakeWebSocketChannel();
        return channel;
      },
    );

    await socket.connect();
    for (var index = 0; index < 4; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 15));
      channel.incoming.add('heartbeat-$index');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(connectionCount, 1);
    expect(socket.status, SocketStatus.connected);
    await socket.close();
  });

  test('configured proxy routing is applied to the WebSocket handshake client', () async {
    HttpClient? capturedClient;
    configureWebSocketProxyRouting((uri) => 'PROXY localhost:7897');
    addTearDown(() => configureWebSocketProxyRouting(null));

    final socket = WebScoketUtils(
      url: 'wss://primary.example/ws',
      heartBeatTime: 0,
      connector: (endpoint, {connectTimeout, protocols, headers, customClient}) {
        capturedClient = customClient;
        return _FakeWebSocketChannel();
      },
    );

    await socket.connect();
    expect(capturedClient, isNotNull);
    expect(resolveWebSocketProxyDirective(Uri.parse('wss://primary.example/ws')), 'PROXY localhost:7897');
    await socket.close();
  });
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  final _FakeWebSocketSink outgoing = _FakeWebSocketSink();

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => outgoing;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> sent = <dynamic>[];
  final Completer<void> _done = Completer<void>();
  bool closed = false;

  @override
  void add(dynamic data) {
    if (closed) throw StateError('socket is closed');
    sent.add(data);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
