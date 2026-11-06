import 'dart:async';

import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

final class _Sink implements WebSocketSink {
  _Sink();

  final sent = <Object?>[];
  final _closed = Completer<void>();

  @override
  void add(Object? data) => sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _closed.future;

  @override
  Future<void> get done => _closed.future;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}
}

final class _FakeChannel extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  _FakeChannel({this.readyError});

  final Object? readyError;
  final incoming = StreamController<dynamic>();
  @override
  final _Sink sink = _Sink();

  @override
  Future<void> get ready {
    final error = readyError;
    if (error != null) {
      return Future<void>.error(error);
    }
    return Future<void>.value();
  }

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;
}

/// The channels the factory built, in order, keyed by the endpoint asked.
final class _Edges {
  final channels = <Uri, _FakeChannel>{};
  final asked = <Uri>[];

  WebSocketChannelFactory factoryFor({Set<Uri> refuse = const {}}) => (uri, config) {
    asked.add(uri);
    final channel = _FakeChannel(readyError: refuse.contains(uri) ? Exception('edge down') : null);
    channels[uri] = channel;
    return channel;
  };
}

void main() {
  final a = Uri.parse('wss://edge-a.example/danmu');
  final b = Uri.parse('wss://edge-b.example/danmu');

  test('a dead edge rotates to the live one', () async {
    final edges = _Edges();
    final handshakes = Completer<void>();
    final socket = DanmakuSocket(
      uri: a,
      endpoints: [a, b],
      config: const WebSocketConfig(),
      rotationBaseDelay: const Duration(milliseconds: 5),
      channelFactory: edges.factoryFor(refuse: {a}),
      onHandshake: (_) => handshakes.complete(),
      onFrame: (_) {},
      onLost: (_) {},
    );

    final opened = await socket.start();
    // The `connected` state lands a microtask after `connect` returns.
    await handshakes.future.timeout(const Duration(seconds: 2));

    expect(opened, isTrue);
    expect(edges.asked.first, a);
    expect(edges.asked.last, b);
    await socket.stop();
  });

  test('the rotation gives up only after its attempts, and says so', () async {
    final edges = _Edges();
    final losses = <String>[];
    final socket = DanmakuSocket(
      uri: a,
      endpoints: [a, b],
      config: const WebSocketConfig(),
      maxRotationAttempts: 2,
      rotationBaseDelay: const Duration(milliseconds: 5),
      channelFactory: edges.factoryFor(refuse: {a, b}),
      onHandshake: (_) {},
      onFrame: (_) {},
      onLost: losses.add,
    );

    final opened = await socket.start();

    expect(opened, isFalse);
    expect(losses, isEmpty, reason: 'a first attempt that never connected is the caller to report');
    expect(edges.asked, hasLength(2));
    await socket.stop();
  });

  test('a single endpoint fails without any rotation', () async {
    final edges = _Edges();
    final socket = DanmakuSocket(
      uri: a,
      config: const WebSocketConfig(),
      channelFactory: edges.factoryFor(refuse: {a}),
      onHandshake: (_) {},
      onFrame: (_) {},
      onLost: (_) {},
    );

    final opened = await socket.start();

    expect(opened, isFalse);
    expect(edges.asked, [a]);
    await socket.stop();
  });
}
