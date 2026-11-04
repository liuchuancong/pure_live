import 'dart:async';
import 'dart:math' as math;

import 'package:live_websocket/live_websocket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final class _FakeSink implements WebSocketSink {
  new({this.hangClose = false});

  final sent = <Object?>[];
  int? closeCode;
  final bool hangClose;
  final _closed = Completer<void>();

  @override
  void add(Object? data) {
    sent.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(sent.add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    this.closeCode ??= closeCode;
    if (hangClose) {
      // A peer that never acknowledges: the socket's own close handshake is
      // what the client must not wait on forever.
      return Completer<void>().future;
    }
    _closed.complete();
    return Future<void>.value();
  }

  @override
  Future<void> get done => _closed.future;
}

final class _FakeChannel extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  new({this.readyError, this.hangClose = false});

  final Object? readyError;
  final bool hangClose;
  final incoming = StreamController<dynamic>();

  @override
  late final _FakeSink sink = _FakeSink(hangClose: hangClose);

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

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
  String message = 'Condition was not met in time',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(message);
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

const _fastReconnect = ReconnectPolicy(
  maxAttempts: 3,
  initialDelay: Duration(milliseconds: 5),
  maxDelay: Duration(milliseconds: 5),
);

void main() {
  group('LiveWebSocketClient', () {
    test('connects, delivers frames and sends payloads', () async {
      final channels = <_FakeChannel>[];
      final states = <WebSocketConnectionState>[];
      final frames = <Object?>[];
      final client = LiveWebSocketClient(
        uri: Uri.parse('wss://unit.test/stream'),
        channelFactory: (_, _) {
          final channel = _FakeChannel();
          channels.add(channel);
          return channel;
        },
      );
      addTearDown(() async {
        await client.dispose();
      });

      final stateSub = client.states.listen(states.add);
      final frameSub = client.messages.listen(frames.add);
      addTearDown(stateSub.cancel);
      addTearDown(frameSub.cancel);

      await client.connect();
      await pumpEventQueue();

      expect(client.state, WebSocketConnectionState.connected);
      expect(states, contains(WebSocketConnectionState.connected));

      channels.single.incoming.add('text');
      channels.single.incoming.add(<int>[1, 2, 3]);
      await pumpEventQueue();
      expect(frames, hasLength(2));

      client.send('hello');
      expect(channels.single.sink.sent, <Object?>['hello']);

      await client.disconnect();
      expect(client.state, WebSocketConnectionState.disconnected);
    });

    test('rejects non-ws URIs', () {
      expect(() => LiveWebSocketClient(uri: Uri.parse('https://unit.test')), throwsArgumentError);
    });

    test('reconnects after an abnormal close and resets retries', () async {
      final channels = <_FakeChannel>[];
      final client = LiveWebSocketClient(
        uri: Uri.parse('wss://unit.test/stream'),
        config: const WebSocketConfig(reconnectPolicy: _fastReconnect),
        channelFactory: (_, _) {
          final channel = _FakeChannel();
          channels.add(channel);
          return channel;
        },
      );
      addTearDown(() async {
        await client.dispose();
      });

      await client.connect();
      unawaited(channels.first.incoming.close());

      await _waitUntil(() => channels.length >= 2 && client.isConnected);

      expect(client.state, WebSocketConnectionState.connected);
      expect(client.retryCount, 0);
    });

    test('does not reconnect after an explicit disconnect', () async {
      final channels = <_FakeChannel>[];
      final client = LiveWebSocketClient(
        uri: Uri.parse('wss://unit.test/stream'),
        config: const WebSocketConfig(reconnectPolicy: _fastReconnect),
        channelFactory: (_, _) {
          final channel = _FakeChannel();
          channels.add(channel);
          return channel;
        },
      );
      addTearDown(() async {
        await client.dispose();
      });

      await client.connect();
      await client.disconnect();
      unawaited(channels.first.incoming.close());
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(channels, hasLength(1));
      expect(client.state, WebSocketConnectionState.disconnected);
    });

    test('drops a socket whose peer never acknowledges the close', () async {
      final client = LiveWebSocketClient(
        uri: Uri.parse('wss://unit.test/stream'),
        config: const WebSocketConfig(shutdownTimeout: Duration(milliseconds: 50)),
        channelFactory: (_, _) => _FakeChannel(hangClose: true),
      );
      addTearDown(() async {
        await client.dispose();
      });

      await client.connect();

      // A room's teardown, and behind it the app's exit, waits here. The
      // deadline, not the peer, decides when the caller gets its answer back.
      final stopped = client.disconnect().timeout(
        const Duration(seconds: 1),
        onTimeout: () => fail('disconnect waited on the peer instead of its deadline'),
      );
      await stopped;

      expect(client.state, WebSocketConnectionState.disconnected);
      expect(client.isConnected, isFalse);
    });

    test('the close deadline is short but not immediate', () {
      // Zero would drop sockets the peer is still acknowledging, and a long
      // one is the hang this bounds; two seconds is the reference runtime's
      // own shutdownTimeout.
      expect(const WebSocketConfig().shutdownTimeout, const Duration(seconds: 2));
    });

    test('stops after the retry limit and reports an error', () async {
      final errors = <Object>[];
      final client = LiveWebSocketClient(
        uri: Uri.parse('wss://unit.test/stream'),
        config: const WebSocketConfig(connectTimeout: Duration(seconds: 1), reconnectPolicy: _fastReconnect),
        channelFactory: (_, _) => _FakeChannel(readyError: Exception('nope')),
      );
      addTearDown(() async {
        await client.dispose();
      });

      final errorSub = client.errors.listen(errors.add);
      addTearDown(errorSub.cancel);

      await client.connect();
      await _waitUntil(
        () => client.state == WebSocketConnectionState.disconnected,
        message: 'Client never gave up reconnecting',
      );
      await pumpEventQueue();

      final messages = errors.whereType<WebSocketException>().map((error) => error.message);
      expect(messages, contains('Reconnect limit reached'));
    });

    test('heartbeat sends payloads and reconnects on timeout', () async {
      final channels = <_FakeChannel>[];
      final errors = <Object>[];
      final client = LiveWebSocketClient(
        uri: Uri.parse('wss://unit.test/stream'),
        config: WebSocketConfig(
          connectTimeout: const Duration(seconds: 1),
          reconnectPolicy: _fastReconnect,
          heartbeat: HeartbeatConfig(
            interval: const Duration(milliseconds: 20),
            timeout: const Duration(milliseconds: 60),
            payload: () => 'hb',
          ),
        ),
        channelFactory: (_, _) {
          final channel = _FakeChannel();
          channels.add(channel);
          return channel;
        },
      );
      addTearDown(() async {
        await client.dispose();
      });

      final errorSub = client.errors.listen(errors.add);
      addTearDown(errorSub.cancel);

      await client.connect();
      await _waitUntil(() => channels.first.sink.sent.contains('hb'));
      await _waitUntil(() => channels.length >= 2 && client.isConnected);

      final messages = errors.whereType<WebSocketException>().map((error) => error.message);
      expect(messages, contains('Heartbeat timeout'));
      expect(client.state, WebSocketConnectionState.connected);
    });

    test('rejects use after dispose and tolerates double dispose', () async {
      final client = LiveWebSocketClient(
        uri: Uri.parse('wss://unit.test/stream'),
        channelFactory: (_, _) => _FakeChannel(),
      );

      await client.connect();
      await client.dispose();
      await client.dispose();

      expect(client.connect, throwsA(isA<WebSocketException>()));
      expect(() => client.send('x'), throwsA(isA<WebSocketException>()));
    });
  });

  group('ReconnectPolicy', () {
    test('grows exponentially up to maxDelay', () {
      const policy = ReconnectPolicy(initialDelay: Duration(milliseconds: 100), maxDelay: Duration(milliseconds: 400));

      expect(policy.delayForAttempt(1), const Duration(milliseconds: 100));
      expect(policy.delayForAttempt(2), const Duration(milliseconds: 200));
      expect(policy.delayForAttempt(3), const Duration(milliseconds: 400));
      expect(policy.delayForAttempt(4), const Duration(milliseconds: 400));
    });

    test('applies jitter without exceeding the raw delay', () {
      const policy = ReconnectPolicy(
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(milliseconds: 100),
        jitter: 0.5,
      );

      final random = _SequentialRandom(<double>[0, 1]);
      expect(policy.delayForAttempt(1, random: random), const Duration(milliseconds: 100));
      expect(policy.delayForAttempt(1, random: random), const Duration(milliseconds: 50));
    });

    test('honours attempt limits and the enabled flag', () {
      const limited = ReconnectPolicy(maxAttempts: 2);
      const unlimited = ReconnectPolicy(maxAttempts: -1);
      const disabled = ReconnectPolicy(enabled: false);

      expect(limited.shouldRetry(2), isTrue);
      expect(limited.shouldRetry(3), isFalse);
      expect(unlimited.shouldRetry(10000), isTrue);
      expect(disabled.shouldRetry(1), isFalse);
    });
  });
}

final class _SequentialRandom implements math.Random {
  new(this.values);

  final List<double> values;
  int _index = 0;

  @override
  double nextDouble() {
    final value = values[_index % values.length];
    _index++;
    return value;
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor().clamp(0, max - 1);

  @override
  bool nextBool() => nextDouble() >= 0.5;
}
