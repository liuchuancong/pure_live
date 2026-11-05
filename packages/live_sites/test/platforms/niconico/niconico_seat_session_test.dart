import 'dart:async';
import 'dart:convert';

import 'package:live_net/live_net.dart';

import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_seat_session.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_websocket/live_websocket.dart';
import 'package:test/test.dart';

final Uri _seatSocket = Uri.parse('wss://${NiconicoEndpoints.seatHost}/wsapi/v2/watch/123456?frontend_id=3');

/// A `stream` answer the parser accepts: the media host's HLS playlist and two
/// qualities, with no cookies.
Map<String, Object?> _stream({
  String quality = 'high',
  List<String> qualities = const ['high', 'low'],
  String name = 'master',
}) => {
  'protocol': 'hls',
  'uri': 'https://${NiconicoEndpoints.mediaHost}/hls/playlists/$name.m3u8',
  'quality': quality,
  'availableQualities': qualities,
  'cookies': const <Object?>[],
};

/// One seat frame.
String _type(String type, [Object? data]) => jsonEncode({'type': type, 'data': ?data});

/// The two frames that make a seat ready.
String get _seat => _type('seat', {'keepIntervalSec': 30});
String get _grant => _type('stream', _stream());

/// The socket the seat rides, by hand.
final class _Socket implements SocketChannel {
  final _incoming = StreamController<Object?>();
  final sent = <Object>[];
  bool closed = false;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  void add(Object data) {
    if (throwsOnAdd case final error?) throw error;
    sent.add(data);
  }

  /// When set, every send throws this, as a broken socket does.
  Exception? throwsOnAdd;

  /// What the peer reports as the close code.
  int? code;

  @override
  Future<void> close([int? closeCode, String? reason]) async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  int? get closeCode => code;

  @override
  String? get closeReason => null;

  void deliver(Object? frame) => _incoming.add(frame);
  void fail(Object error) => _incoming.addError(error);

  void closeByServer() {
    code = 1001;
    unawaited(_incoming.close());
  }
}

/// The connector the seat was built with.
final class _Connector {
  final sockets = <_Socket>[];
  final asked = <Uri>[];
  final headers = <Map<String, String>>[];
  final budgets = <Duration>[];
  final protocols = <Iterable<String>?>[];

  /// When set, opening throws this instead of answering.
  Exception? failure;

  /// When set, the socket arrives only after its completer is completed.
  Completer<void>? hold;

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
    budgets.add(connectTimeout);
    if (failure case final error?) throw error;
    final socket = _Socket();
    sockets.add(socket);
    if (hold case final waiting?) await waiting.future;
    return socket;
  }

  _Socket get last => sockets.last;
}

Future<(NiconicoSeat, _Connector, _Socket)> _joined({Uri? socket}) async {
  final connector = _Connector();
  final seat = NiconicoSeat(socket ?? _seatSocket, connector: connector.call);
  final starting = seat.connect();
  await _settle();
  connector.last
    ..deliver(_seat)
    ..deliver(_grant);
  await starting;
  final created = connector.sockets.last;
  created.sent.clear();
  return (seat, connector, created);
}

Future<void> _settle() async {
  for (var turn = 0; turn < 20; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('opening the seat', () {
    test('a socket that is not the seat endpoint is refused before any connect', () async {
      final connector = _Connector();
      final seat = NiconicoSeat(Uri.parse('wss://evil.example/wsapi/v2/watch/1'), connector: connector.call);
      await expectLater(
        seat.connect(),
        throwsA(isA<NiconicoFailure>().having((failure) => failure.kind, 'kind', NiconicoFailureKind.apiChanged)),
      );
      expect(connector.asked, isEmpty, reason: 'the endpoint is checked before anything is opened');
      expect(seat.isClosed, isFalse, reason: 'nothing was opened, so there is nothing ended');
    });

    test('a handshake that cannot open is a network failure, and the seat is over', () async {
      final connector = _Connector()..failure = const ConnectFailure('no route to the seat');
      final seat = NiconicoSeat(_seatSocket, connector: connector.call);
      await expectLater(
        seat.connect(),
        throwsA(
          isA<NiconicoFailure>().having((failure) => failure.message, 'message', contains('no route to the seat')),
        ),
      );
      expect(connector.sockets, isEmpty);
      expect(seat.isClosed, isFalse, reason: 'the caller abandons the seat, as openSeat does');
    });

    test('the handshake asks for the seat, then sends startWatching and getAkashic', () async {
      final connector = _Connector();
      final seat = NiconicoSeat(_seatSocket, connector: connector.call);
      final starting = seat.connect();
      await _settle();
      expect(connector.asked.single, _seatSocket);
      expect(connector.headers.single, NiconicoEndpoints.seatHeaders);
      expect(connector.budgets.single, NiconicoSeat.startupTimeout);
      expect(connector.protocols.single, isNull);
      expect(connector.last.texts, [NiconicoSeatMessages.startWatching, NiconicoSeatMessages.getAkashic]);
      expect(seat.currentGrant, isNull, reason: 'nothing is granted before the answers');
      expect(seat.messageServer, isNull);

      connector.last
        ..deliver(_seat)
        ..deliver(_grant);
      await starting;
      expect(seat.currentGrant?.isActive, isTrue);
      expect(seat.isClosed, isFalse);
      await seat.close();
    });

    test('both grants make it ready, in either order', () async {
      for (final first in [_seat, _grant]) {
        final connector = _Connector();
        final seat = NiconicoSeat(_seatSocket, connector: connector.call);
        final starting = seat.connect();
        await _settle();
        var settled = false;
        unawaited(starting.then((_) => settled = true));
        connector.last.deliver(first);
        await _settle();
        expect(settled, isFalse, reason: 'one grant alone is not a seat');
        connector.last.deliver(first == _seat ? _grant : _seat);
        await _settle();
        expect(settled, isTrue, reason: 'and the other one is');
        await seat.close();
      }
    });

    test('a seat frame without a usable interval ends it', () async {
      final (seat, _, socket) = await _half();
      socket.deliver(_type('seat', {'keepIntervalSec': 0}));
      await _settle();
      expect(
        await seat.done,
        isA<NiconicoFailure>().having((failure) => failure.message, 'message', contains('keepIntervalSec 0')),
      );
      expect(socket.closed, isTrue);
    });
  });

  group('what the seat says', () {
    test('a ping is answered with a pong and one more keepSeat', () async {
      final (seat, _, socket) = await _joined();
      addTearDown(seat.close);

      socket.deliver(_type('ping'));
      await _settle();
      expect(socket.texts, [NiconicoSeatMessages.pong, NiconicoSeatMessages.keepSeat]);
    });

    test('a later stream revokes the grant it replaces', () async {
      final (seat, _, socket) = await _joined();
      addTearDown(seat.close);

      final first = seat.currentGrant!;
      final seen = <String>[];
      final subscription = seat.grants.listen((grant) => seen.add(grant.uri.path.split('/').last));
      socket.deliver(_type('stream', _stream(name: 'second', quality: 'low', qualities: const ['low'])));
      await _settle();
      expect(first.isActive, isFalse, reason: 'the old playlist is no longer ours to read');
      expect(seat.currentGrant?.uri.path, endsWith('second.m3u8'));
      expect(seen, ['second.m3u8'], reason: 'the broadcast carries the grants as they arrive');
      await subscription.cancel();
    });

    test('the comment server is named when it arrives, and other frames grant nothing', () async {
      final (seat, _, socket) = await _joined();
      addTearDown(seat.close);

      const view = 'https://livecomment2.dlive.nicovideo.jp/api/v1/programs/so1/view';
      socket
        ..deliver(_type('messageServer', {'viewUri': view}))
        ..deliver(_type('serverTime', {'now': '2026-11-05T12:00:00Z'}))
        ..deliver(_type('statistics'));
      await _settle();
      expect(seat.messageServer.toString(), contains('/api/v1/programs/so1/view'));
      expect(seat.currentGrant?.isActive, isTrue, reason: 'none of those end the seat');
    });

    test('a frame that is not text, JSON, or an object with a type ends it', () async {
      for (final frame in <Object?>[
        [1, 2, 3],
        'not json',
        '[1,2]',
        '{"data":{}}',
        '{"type":7}',
      ]) {
        final (seat, _, socket) = await _joined();
        socket.deliver(frame);
        await _settle();
        expect(
          await seat.done,
          isA<NiconicoFailure>().having((failure) => failure.kind, 'kind', NiconicoFailureKind.apiChanged),
          reason: 'frame $frame',
        );
        expect(socket.closed, isTrue);
      }
    });

    test('a send that throws ends the seat with the socket’s own words', () async {
      final (seat, _, socket) = await _joined();
      socket
        ..throwsOnAdd = Exception('pipe broken')
        ..deliver(_type('ping'));
      await _settle();
      expect(
        await seat.done,
        isA<NiconicoFailure>().having((failure) => failure.message, 'message', contains('pipe broken')),
      );
    });
  });

  group('the end of a seat', () {
    test('an error frame names its code and its kind', () async {
      for (final (code, kind) in <(String, NiconicoFailureKind)>[
        ('NO_PERMISSION', NiconicoFailureKind.needsLogin),
        ('TICKET_REQUIRED', NiconicoFailureKind.needsLogin),
        ('TOO_MANY_CONNECTIONS', NiconicoFailureKind.rateLimited),
        ('INVALID_MESSAGE', NiconicoFailureKind.apiChanged),
        ('WHATEVER', NiconicoFailureKind.streamUnavailable),
      ]) {
        final (seat, _, socket) = await _joined();
        socket.deliver(_type('error', {'code': code}));
        await _settle();
        expect(
          await seat.done,
          isA<NiconicoFailure>()
              .having((failure) => failure.kind, 'kind', kind)
              .having((failure) => failure.message, 'message', 'seat error $code'),
          reason: code,
        );
        expect(socket.closed, isTrue, reason: 'the socket goes with it');
      }
    });

    test('a disconnect frame carries the platform’s reason', () async {
      final (seat, _, socket) = await _joined();
      socket.deliver(_type('disconnect', {'reason': 'PROGRAM_ENDED'}));
      await _settle();
      expect(
        await seat.done,
        isA<NiconicoFailure>().having((failure) => failure.message, 'message', 'seat disconnect PROGRAM_ENDED'),
      );
    });

    test('the server closing the socket ends the seat, naming the code', () async {
      final (seat, _, socket) = await _joined();
      socket.closeByServer();
      await _settle();
      expect(
        await seat.done,
        isA<NiconicoFailure>().having(
          (failure) => failure.message,
          'message',
          contains('seat closed by the server (1001)'),
        ),
      );
      expect(seat.currentGrant?.isActive, isFalse, reason: 'the grant goes with the seat');
    });

    test('a socket that errors ends the seat in the socket’s words', () async {
      final (seat, _, socket) = await _joined();
      socket.fail(StateError('connection reset'));
      await _settle();
      expect(
        await seat.done,
        isA<NiconicoFailure>().having((failure) => failure.message, 'message', contains('connection reset')),
      );
    });

    test('a closed seat reports a clean end, twice', () async {
      final (seat, _, socket) = await _joined();
      await seat.close();
      expect(await seat.done, isNull);
      await seat.close();
      expect(seat.isClosed, isTrue);
      expect(socket.closed, isTrue);
    });
  });
}

/// A seat whose socket opened but which is not yet ready (no grant).
Future<(NiconicoSeat, _Connector, _Socket)> _half() async {
  final connector = _Connector();
  final seat = NiconicoSeat(_seatSocket, connector: connector.call);
  // The handshake is left unfinished here; its own end is what the test reads.
  unawaited(seat.connect().catchError((Object _) {}));
  await _settle();
  return (seat, connector, connector.sockets.last);
}

extension on _Socket {
  List<String> get texts => sent.map((frame) => '$frame').toList();
}
