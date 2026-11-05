import 'dart:async';
import 'dart:convert';

import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_control.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_play_parser.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

// The harness throws whatever the site's socket throws, spells its own class
// name in its private constructors, and holds the peer's close code as a field.
// ignore_for_file: only_throw_errors, unnecessary_type_name_in_constructor

const String _channel = '1234567';

/// The grant of the channel these tests open a control for.
Fc2LiveGrant _grant() => Fc2LiveGrant(
  channelId: _channel,
  socket: Uri.parse('wss://node.live.fc2.com/control/channels/$_channel'),
  controlToken: 'ct-1',
  orz: 'orz-1',
);

/// A variant playlist of [mode], as the media server names it.
String _variant(int mode) => 'https://live.fc2.com/a/stream/$_channel/$mode/playlist?c=cc&d=dd';

/// The adaptive master of [mode].
String _master(int mode) => 'https://live.fc2.com/a/stream/$_channel/$mode/master_playlist?targets=10,20&c=cc&d=dd';

/// The answer to `get_hls_information` naming [rows] as mode and url.
String _hlsAnswer(Iterable<(int, String)> rows, {int status = 0}) => jsonEncode({
  'name': '_response_',
  'id': 1,
  'arguments': {
    'status': status,
    'playlists': [
      for (final (mode, url) in rows) {'mode': mode, 'status': 0, 'url': url},
    ],
  },
});

const String _connected = '{"name":"connect_complete"}';

/// Frames of any JSON that grants a control nothing.
final List<String> _ignored = [
  jsonEncode({'name': 'initial_connect'}),
  jsonEncode({'name': 'connect_data'}),
  jsonEncode({
    'name': 'user_count',
    'arguments': {'count': 3},
  }),
  jsonEncode({'name': 'ping'}),
];

/// One socket the control speaks through, with the frames the test hands it.
final class _Socket implements SocketChannel {
  final StreamController<Object?> _frames = StreamController<Object?>.broadcast();
  final List<Object> sent = [];
  @override
  int? closeCode;
  @override
  String? closeReason;
  bool closed = false;
  Object? sendError;

  void deliver(Object? frame) => _frames.add(frame);

  void fail(Object error) => _frames.addError(error);

  void end({int? code, String? reason}) {
    closeCode = code;
    closeReason = reason;
    unawaited(_frames.close());
  }

  @override
  Stream<Object?> get stream => _frames.stream;

  @override
  void add(Object data) {
    if (sendError != null) throw sendError!;
    sent.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }
}

/// A timer a test owns, so the startup wait is a fact it can assert on.
final class _Armed implements Timer {
  _Armed(this.delay, this.callback, this.clock);

  final Duration delay;
  final void Function() callback;
  final _Clock clock;
  bool _cancelled = false;

  @override
  void cancel() {
    _cancelled = true;
    clock.armed.remove(this);
  }

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}

/// The clock the control is given instead of the real one.
final class _Clock {
  final List<_Armed> armed = [];

  Timer after(Duration delay, void Function() callback) {
    final timer = _Armed(delay, callback, this);
    armed.add(timer);
    return timer;
  }

  /// Runs every watch armed for [delay], as the site's patience ending.
  void fire(Duration delay) {
    for (final timer in armed.where((timer) => timer.delay == delay).toList()) {
      timer.callback();
    }
  }
}

/// How the control's sockets are made, and what it was asked for.
final class _Connector {
  final List<Uri> asked = [];
  final List<Map<String, String>> headers = [];
  final List<Iterable<String>?> protocols = [];
  final List<Duration> timeouts = [];
  final List<Duration?> pings = [];
  final List<_Socket> sockets = [];

  /// When set, a connection is not answered until the test releases it.
  Completer<void>? hold;

  Object? failure;

  Future<SocketChannel> call(
    Uri endpoint, {
    required Map<String, String> headers,
    required Iterable<String>? protocols,
    required Duration connectTimeout,
    Duration? pingInterval,
  }) async {
    asked.add(endpoint);
    this.headers.add(headers);
    this.protocols.add(protocols);
    timeouts.add(connectTimeout);
    pings.add(pingInterval);
    if (failure != null) throw failure!;
    final socket = _Socket();
    final parked = hold;
    if (parked != null) {
      // The socket only exists once the handshake is answered.
      await parked.future;
    }
    sockets.add(socket);
    return socket;
  }
}

/// Starts an open and hands back the socket it made with the future the test
/// must still answer.
Future<(_Socket, Future<Fc2LiveControl>)> _opening({
  required _Connector connector,
  String quality = Fc2LivePlayParser.autoQualityId,
  _Clock? clock,
  Duration startupTimeout = Fc2LiveEndpoints.requestTimeout,
}) async {
  final pending = Fc2LiveControl.open(
    _grant(),
    connect: connector.call,
    quality: quality,
    startupTimeout: startupTimeout,
    timer: clock?.after,
  );
  await Future<void>.delayed(Duration.zero);
  return (connector.sockets.single, pending);
}

/// The quality a control plays when it asked for [quality] and the channel
/// answered with [rows].
Future<String> _played(String quality, List<(int, String)> rows) async {
  final connector = _Connector();
  final (socket, pending) = await _opening(quality: quality, connector: connector);
  socket
    ..deliver(_connected)
    ..deliver(_hlsAnswer(rows));
  final control = await pending;
  return control.playlist.quality;
}

void main() {
  group('opening a control', () {
    test('a quality the site does not know opens nothing', () async {
      final connector = _Connector();
      for (final quality in ['60', '030', '', 'adaptive', '9', 'AUTO']) {
        await expectLater(
          Fc2LiveControl.open(_grant(), connect: connector.call, quality: quality),
          throwsA(isA<Fc2LiveFailure>().having((f) => f.kind, 'kind', Fc2LiveFailureKind.invalidArgument)),
          reason: '"$quality" is not one of the site\'s six',
        );
      }
      expect(connector.asked, isEmpty, reason: 'a caller error never reaches the socket');
    });

    test('every quality it does know is asked for on its own socket', () async {
      for (final quality in Fc2LivePlayParser.qualityIds) {
        final connector = _Connector();
        final (socket, pending) = await _opening(quality: quality, connector: connector);
        socket
          ..deliver(_connected)
          ..deliver(_hlsAnswer([(51, _variant(51)), (0, _master(0))]));
        final control = await pending;
        expect(socket.sent, [Fc2LiveControl.hlsRequest], reason: '$quality asked once');
        expect(control.requestedQuality, quality);
        await control.close();
      }
    });

    test("the handshake goes to the grant's endpoint with its headers", () async {
      final connector = _Connector();
      final (socket, pending) = await _opening(connector: connector);
      socket
        ..deliver(_connected)
        ..deliver(_hlsAnswer([(0, _master(0))]));
      final control = await pending;

      expect(connector.asked.single, _grant().endpoint);
      expect(connector.asked.single.queryParameters['control_token'], 'ct-1');
      expect(connector.headers.single['origin'], Fc2LiveEndpoints.origin);
      expect(connector.headers.single['user-agent'], Fc2LiveEndpoints.userAgent);
      expect(connector.headers.single['cookie'], contains('l_ortkn=orz-1'));
      expect(connector.protocols.single, isNull);
      expect(connector.timeouts.single, Fc2LiveEndpoints.connectTimeout);
      expect(connector.pings.single, isNull, reason: 'this path asks for no site ping');
      expect(control.channelId, _channel);
      expect(control.mediaHeaders['referer'], Fc2LiveEndpoints.channelUrl(_channel));
      expect(Fc2LiveControl.pingInterval, const Duration(seconds: 15), reason: 'what the io connector adds');
      await control.close();
    });

    test('a socket that cannot be opened is a network failure', () async {
      final connector = _Connector()..failure = StateError('no route');
      await expectLater(
        Fc2LiveControl.open(_grant(), connect: connector.call),
        throwsA(
          isA<Fc2LiveFailure>()
              .having((f) => f.kind, 'kind', Fc2LiveFailureKind.network)
              .having((f) => f.message, 'message', 'control handshake: StateError'),
        ),
      );
      expect(connector.sockets, isEmpty);
    });

    test('after connect_complete the control asks for the HLS information once', () async {
      final connector = _Connector();
      final clock = _Clock();
      final (socket, pending) = await _opening(quality: '40', connector: connector, clock: clock);
      socket
        ..deliver(_connected)
        ..deliver(_connected);
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent, [Fc2LiveControl.hlsRequest], reason: 'the page sends it once, and so does this');
      expect(clock.armed, hasLength(1), reason: 'the startup wait is still held');

      socket.deliver(_hlsAnswer([(41, _variant(41))]));
      final control = await pending;
      expect(control.playlist.quality, '40');
      expect(control.playlist.url.toString(), _variant(41));
      expect(control.playlists.keys, [41]);
      expect(clock.armed, isEmpty, reason: 'the answer cancels the startup wait');
      await control.close();
    });

    test('a frame that answers some other request grants nothing', () async {
      final connector = _Connector();
      final (socket, pending) = await _opening(quality: '30', connector: connector);
      socket
        ..deliver(_hlsAnswer([(31, _variant(31))]))
        ..deliver(
          jsonEncode({
            'name': '_response_',
            'id': 2,
            'arguments': {'status': 0, 'playlists': <Object?>[]},
          }),
        );
      _ignored.forEach(socket.deliver);
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent, isEmpty, reason: 'the reply came before the control had asked for anything');

      socket
        ..deliver(_connected)
        ..deliver(
          jsonEncode({
            'name': '_response_',
            'id': 2,
            'arguments': {'status': 0, 'playlists': <Object?>[]},
          }),
        )
        ..deliver(
          jsonEncode({
            'name': 'control_disconnection',
            'arguments': {'code': 4500},
          }),
        );
      await expectLater(pending, throwsA(isA<Fc2LiveFailure>()));
    });

    test('the answer opens the control on the tier it still has, naming what plays', () async {
      expect(await _played('auto', [(0, _master(0))]), Fc2LivePlayParser.autoQualityId);
      expect(await _played('50', [(51, _variant(51))]), '50', reason: 'the high-latency twin of the tier asked for');
      expect(await _played('50', [(41, _variant(41)), (11, _variant(11))]), '40', reason: 'the next lower tier');
      expect(await _played('10', [(21, _variant(21))]), '20', reason: 'and the next higher when nothing is lower');
      expect(await _played('50', [(0, _master(0))]), Fc2LivePlayParser.autoQualityId, reason: 'a master beats no tier');
      expect(await _played('auto', [(11, _variant(11))]), '10', reason: 'a tier is better than nothing for adaptive');
    });

    test('an answer that names no playlist, or refuses, ends the control', () async {
      final empty = _Connector();
      final (emptySocket, emptyPending) = await _opening(quality: '50', connector: empty);
      emptySocket
        ..deliver(_connected)
        ..deliver(_hlsAnswer(const []));
      await expectLater(
        emptyPending,
        throwsA(
          isA<Fc2LiveFailure>()
              .having((f) => f.kind, 'kind', Fc2LiveFailureKind.apiChanged)
              .having((f) => f.message, 'message', contains('no playlist')),
        ),
      );
      expect(emptySocket.closed, isTrue, reason: 'a failed open still closes what it opened');

      final refused = _Connector();
      final (refusedSocket, refusedPending) = await _opening(quality: '50', connector: refused);
      refusedSocket
        ..deliver(_connected)
        ..deliver(_hlsAnswer([(51, _variant(51))], status: 3));
      await expectLater(
        refusedPending,
        throwsA(isA<Fc2LiveFailure>().having((f) => f.kind, 'kind', Fc2LiveFailureKind.streamUnavailable)),
      );

      final missing = _Connector();
      final (missingSocket, missingPending) = await _opening(quality: '50', connector: missing);
      missingSocket
        ..deliver(_connected)
        ..deliver(
          jsonEncode({
            'name': '_response_',
            'id': 1,
            'arguments': {'status': 0},
          }),
        );
      await expectLater(missingPending, throwsA(isA<Fc2LiveFailure>()));
      expect(missingSocket.sent, [Fc2LiveControl.hlsRequest]);
    });

    test('a playlist of another channel is not a playlist at all', () async {
      final connector = _Connector();
      final (socket, pending) = await _opening(quality: '50', connector: connector);
      socket
        ..deliver(_connected)
        ..deliver(_hlsAnswer([(51, 'https://live.fc2.com/a/stream/7654321/51/playlist?c=cc&d=dd')]));
      await expectLater(
        pending,
        throwsA(isA<Fc2LiveFailure>().having((f) => f.kind, 'kind', Fc2LiveFailureKind.apiChanged)),
      );
    });
  });

  group('what ends a control', () {
    test('a frame that is not text, or is past the limit, is api-changed', () async {
      for (final frame in <Object?>[
        [1, 2, 3],
        'x' * (Fc2LiveEndpoints.messageLimit + 1),
        'not json',
        '[1,2]',
        '"a string"',
        null,
      ]) {
        final connector = _Connector();
        final (socket, pending) = await _opening(connector: connector);
        socket
          ..deliver(_connected)
          ..deliver(frame);
        await expectLater(
          pending,
          throwsA(isA<Fc2LiveFailure>().having((f) => f.kind, 'kind', Fc2LiveFailureKind.apiChanged)),
          reason: '${frame is String && frame.length > 40 ? 'a frame over the limit' : frame} is nothing to read',
        );
        expect(socket.closed, isTrue);
      }
    });

    test('control_disconnection says its code, and 4500 is the grant expiring', () async {
      final connector = _Connector();
      final (socket, pending) = await _opening(connector: connector);
      socket
        ..deliver(_connected)
        ..deliver(
          jsonEncode({
            'name': 'control_disconnection',
            'arguments': {'code': 4500},
          }),
        );
      await expectLater(
        pending,
        throwsA(
          isA<Fc2LiveFailure>()
              .having((f) => f.kind, 'kind', Fc2LiveFailureKind.network)
              .having((f) => f.message, 'message', 'control_disconnection 4500'),
        ),
      );

      final bare = _Connector();
      final (bareSocket, barePending) = await _opening(connector: bare);
      bareSocket
        ..deliver(_connected)
        ..deliver(jsonEncode({'name': 'control_disconnection', 'arguments': 'not a map'}));
      await expectLater(
        barePending,
        throwsA(isA<Fc2LiveFailure>().having((f) => f.message, 'message', 'control_disconnection')),
      );
    });

    test('the server closing or breaking the socket is told with its code', () async {
      final connector = _Connector();
      final (socket, pending) = await _opening(connector: connector);
      socket
        ..deliver(_connected)
        ..end(code: 1006);
      await expectLater(
        pending,
        throwsA(
          isA<Fc2LiveFailure>()
              .having((f) => f.kind, 'kind', Fc2LiveFailureKind.network)
              .having((f) => f.message, 'message', 'control closed by the server (1006)'),
        ),
      );

      final quiet = _Connector();
      final (quietSocket, quietPending) = await _opening(connector: quiet);
      quietSocket
        ..deliver(_connected)
        ..end();
      await expectLater(
        quietPending,
        throwsA(isA<Fc2LiveFailure>().having((f) => f.message, 'message', 'control closed by the server')),
      );

      final broken = _Connector();
      final (brokenSocket, brokenPending) = await _opening(connector: broken);
      brokenSocket
        ..deliver(_connected)
        ..fail(StateError('socket broke'));
      await expectLater(
        brokenPending,
        throwsA(isA<Fc2LiveFailure>().having((f) => f.message, 'message', 'control: StateError')),
      );
    });

    test('a send the socket refuses ends the control', () async {
      final connector = _Connector();
      final (socket, pending) = await _opening(connector: connector);
      socket
        ..sendError = StateError('gone')
        ..deliver(_connected);
      await expectLater(
        pending,
        throwsA(isA<Fc2LiveFailure>().having((f) => f.message, 'message', 'control send: StateError')),
      );
    });
  });

  group('the patience it is given', () {
    test('the startup wait bounds the handshake and the answer together', () async {
      final connector = _Connector();
      final clock = _Clock();
      final (socket, pending) = await _opening(
        connector: connector,
        clock: clock,
        startupTimeout: const Duration(seconds: 5),
      );
      socket.deliver(_connected);
      await Future<void>.delayed(Duration.zero);
      expect(clock.armed.single.delay, const Duration(seconds: 5));

      clock.fire(const Duration(seconds: 5));
      await expectLater(
        pending,
        throwsA(
          isA<Fc2LiveFailure>()
              .having((f) => f.kind, 'kind', Fc2LiveFailureKind.network)
              .having((f) => f.message, 'message', 'control: no HLS information within 5 s'),
        ),
      );
      expect(socket.closed, isTrue);

      // An answer that comes after the wait changes nothing: the control is gone.
      socket.deliver(_hlsAnswer([(0, _master(0))]));
      await Future<void>.delayed(Duration.zero);
    });

    test('a handshake that lands after the wait is closed, not used', () async {
      final connector = _Connector()..hold = Completer<void>();
      final clock = _Clock();
      final pending = Fc2LiveControl.open(
        _grant(),
        connect: connector.call,
        startupTimeout: const Duration(seconds: 4),
        timer: clock.after,
      );
      await Future<void>.delayed(Duration.zero);
      expect(connector.sockets, isEmpty, reason: 'the connection is still parked');

      clock.fire(const Duration(seconds: 4));
      await expectLater(pending, throwsA(isA<Fc2LiveFailure>()));
      connector.hold!.complete();
      await Future<void>.delayed(Duration.zero);
      final socket = connector.sockets.single;
      expect(socket.closed, isTrue, reason: 'what landed late is closed quietly');
      expect(socket.sent, isEmpty);
      expect(connector.asked, hasLength(1));
    });

    test('close is idempotent and a clean end says nothing went wrong', () async {
      final connector = _Connector();
      final clock = _Clock();
      final (socket, pending) = await _opening(connector: connector, clock: clock);
      socket
        ..deliver(_connected)
        ..deliver(_hlsAnswer([(0, _master(0))]));
      final control = await pending;
      expect(clock.armed, isEmpty);

      await control.close();
      await control.close();
      expect(control.isClosed, isTrue);
      expect(await control.done, isNull, reason: 'the owner closed it; there is no reason to report');
      expect(socket.closed, isTrue);
      expect(control.playlists.keys, [0], reason: 'what it learned stays readable once it is closed');
    });

    test('a control only serves one socket, so a used grant is never reopened', () async {
      final connector = _Connector();
      final (socket, pending) = await _opening(connector: connector);
      socket
        ..deliver(_connected)
        ..deliver(_hlsAnswer([(0, _master(0))]));
      final control = await pending;
      expect(connector.asked, hasLength(1));
      expect(control.grant.controlToken, 'ct-1');

      await control.close();
      expect(connector.asked, hasLength(1), reason: 'closing does not ask for a second socket with the same token');
      expect(await control.done, isNull);
    });
  });
}
