import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_codec.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:test/test.dart';

const List<int> _key = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
const List<int> _otherKey = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
const List<int> _sessionKey = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115];
const List<int> _iv = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31];

final String _security = base64.encode(_key);

/// The arguments of one broadcast, with a visitor that has a `acSecurity` key.
AcfunDanmakuArgs _args({String liveId = 'live-1', String attach = 'attach-1'}) => AcfunDanmakuArgs(
  authorId: '42',
  liveId: liveId,
  visitor: AcfunVisitor(userId: '42', deviceId: 'web_did', token: 'svc-token', security: _security),
  tickets: const ['t-1', 't-2'],
  enterRoomAttach: attach,
);

/// A link whose IVs come from [seed], so a test can compare two frames.
AcfunDanmakuLink _link({int seed = 7, AcfunDanmakuArgs? args}) =>
    AcfunDanmakuLink(args: args ?? _args(), security: _key, random: Random(seed));

/// A link after its register answer, so its frames are sealed with the session
/// key the answer brought.
AcfunDanmakuLink _registered() => _link()
  ..register()
  ..read(_downstream(AcfunDanmakuProtocol.registerCommand, body: _registerBody(), key: _key));

/// What a frame the link wrote holds: its header, the payload it sealed and the
/// IV that payload starts with.
({AcfunProtoMessage header, Uint8List plain, Uint8List iv, AcfunProtoMessage upstream}) _sent(
  Uint8List frame,
  List<int> key,
) {
  final (:header, :payload) = AcfunDanmakuProtocol.unframe(frame);
  final plain = AcfunDanmakuProtocol.open(payload, key);
  return (
    header: header,
    plain: plain,
    iv: Uint8List.fromList(payload.sublist(0, AcfunDanmakuProtocol.aesBlock)),
    upstream: AcfunProtoMessage.decode(plain),
  );
}

/// A `DownstreamPayload` as the server writes it, [key] sealing it when given.
Uint8List _downstream(
  String command, {
  int seqId = 1,
  int errorCode = 0,
  Uint8List? body,
  String error = '',
  List<int>? key,
  int mode = 1,
}) {
  final down = AcfunProtoWriter()
    ..string(1, command)
    ..integer(2, seqId)
    ..integer(3, errorCode);
  if (body != null) down.bytes(4, body);
  if (error.isNotEmpty) down.string(5, error);
  final header =
      (AcfunProtoWriter()
            ..integer(1, AcfunDanmakuProtocol.appId)
            ..integer(8, mode)
            ..integer(10, seqId))
          .toBytes();
  final plain = down.toBytes();
  return AcfunDanmakuProtocol.frame(header, key == null ? plain : AcfunDanmakuProtocol.seal(plain, key, _iv));
}

/// `RegisterResponse {sessionKey 2, instanceId 3}`.
Uint8List _registerBody({List<int>? sessionKey = _sessionKey, int instanceId = 99}) {
  final answer = AcfunProtoWriter()..integer(3, instanceId);
  if (sessionKey != null) answer.bytes(2, sessionKey);
  return answer.toBytes();
}

/// A `CommonActionSignalComment` payload with text [text] and a sender.
Uint8List _comment(String text) =>
    (AcfunProtoWriter()
          ..string(1, text)
          ..bytes(
            3,
            (AcfunProtoWriter()
                  ..integer(1, 42)
                  ..string(2, 'Ann'))
                .toBytes(),
          ))
        .toBytes();

/// A `ZtLiveScMessage` of [type] holding [body].
Uint8List _scMessage(String type, [Uint8List? body]) =>
    (AcfunProtoWriter()
          ..string(1, type)
          ..bytes(3, body ?? const []))
        .toBytes();

void main() {
  group('what the link writes', () {
    test('register is sealed with acSecurity and spells the H5 client out', () {
      final link = _link();
      final (:header, :plain, :upstream, :iv) = _sent(link.register(), _key);

      expect(header.integer(1), AcfunDanmakuProtocol.appId);
      expect(header.integer(2), 42, reason: 'the header carries the visitor account');
      expect(header.integer(3), 0, reason: 'no instance id until the answer gives one');
      expect(header.integer(7), plain.length, reason: 'the header says how long the payload is once opened');
      expect(header.integer(8), 1, reason: 'mode 1 is keyed by acSecurity');
      expect(header.integer(10), 1, reason: 'the first frame is sequence 1');
      expect(header.string(12), AcfunDanmakuProtocol.kpn);
      final tokenInfo = header.message(9)!;
      expect(tokenInfo.integer(1), 1);
      expect(tokenInfo.string(2), 'svc-token', reason: 'only the register asks with the service token');

      expect(upstream.string(1), AcfunDanmakuProtocol.registerCommand);
      expect(upstream.integer(2), 1);
      expect(upstream.integer(3), 1, reason: 'the page sends retryCount 1 on the first try');
      expect(upstream.string(9), AcfunDanmakuProtocol.subBiz);
      final request = upstream.message(4)!;
      expect(request.message(1)!.string(1), 'link-sdk');
      expect(request.message(1)!.string(4), '1.2.1');
      final device = request.message(2)!;
      expect(device.integer(1), 6, reason: 'platform type 6 is H5');
      expect(device.string(3), 'h5');
      expect(device.string(5), 'web_did');
      expect(request.integer(4), 1);
      expect(request.integer(5), 1);
      expect(request.integer(8), 0);
      final zt = request.message(11)!;
      expect(zt.string(1), AcfunDanmakuProtocol.kpn);
      expect(zt.string(2), AcfunEndpoints.kpf);
      expect(zt.integer(4), 42);
      expect(zt.string(5), 'web_did');
      expect(iv, hasLength(AcfunDanmakuProtocol.aesBlock));
      expect(link.registered, isFalse);
    });

    test('a command before the register answer is refused, not sent unsealed', () {
      final link = _link();
      expect(link.keepAlive, throwsStateError);
      expect(() => link.enterRoom(ticket: 't-1'), throwsStateError);
      expect(() => link.heartbeat(ticket: 't-1', now: DateTime.now()), throwsStateError);
      // The register itself is the one frame the security key can carry.
      expect(link.register(), isNotEmpty);
    });

    test('every frame moves the sequence, and a push answer carries the push id', () {
      final link = _registered();
      expect(_sent(link.keepAlive(), _sessionKey).header.integer(10), 2);
      expect(_sent(link.enterRoom(ticket: 't-1'), _sessionKey).header.integer(10), 3);

      final ack = link.pushAck(AcfunDanmakuPacket(command: 'Push.X', seqId: 77, payload: Uint8List(0)));
      final sent = _sent(ack, _sessionKey);
      expect(sent.header.integer(10), 77, reason: 'the answer echoes the push it acknowledges');
      expect(sent.upstream.integer(2), 4, reason: 'the link is not on a new sequence for an answer');
      expect(sent.upstream.string(1), 'Push.X');
      expect(sent.upstream.bytes(4), isNull, reason: 'an acknowledgement carries no payload');
      expect(_sent(link.keepAlive(), _sessionKey).header.integer(10), 4, reason: 'the next send reuses the sequence');
      expect(_sent(link.keepAlive(), _sessionKey).header.integer(10), 5);
    });

    test('enter room and heartbeat wrap the room command around the ticket', () {
      final link = _registered();
      final entered = _sent(link.enterRoom(ticket: 't-2', reconnects: 4), _sessionKey).upstream;
      expect(entered.string(1), AcfunDanmakuProtocol.roomCommand);
      final cmd = entered.message(4)!;
      expect(cmd.string(1), 'ZtLiveCsEnterRoom');
      expect(cmd.string(3), 't-2', reason: 'the ticket the caller asked to try is the one written');
      expect(cmd.string(4), 'live-1');
      final body = cmd.message(2)!;
      expect(body.integer(1), 0, reason: 'a visitor is not the author');
      expect(body.integer(2), 4);
      expect(body.string(4), 'attach-1');
      expect(body.string(5), AcfunDanmakuProtocol.sdkVersion);

      final now = DateTime.fromMillisecondsSinceEpoch(1790733600000);
      for (final (sequence, beat) in [
        (0, link.heartbeat(ticket: 't-1', now: now)),
        (1, link.heartbeat(ticket: 't-1', now: now)),
        (2, link.heartbeat(ticket: 't-2', now: now)),
      ]) {
        final inner = _sent(beat, _sessionKey).upstream.message(4)!;
        expect(inner.string(1), 'ZtLiveCsHeartbeat');
        expect(inner.string(3), sequence == 2 ? 't-2' : 't-1');
        expect(inner.message(2)!.integer(1), 1790733600000);
        expect(inner.message(2)!.integer(2), sequence, reason: 'the heartbeat counts from 0 on this link');
      }
    });

    test('an IV drawn from the same seed is the same frame, and another IV is the same message', () {
      final first = _link(seed: 3).register();
      expect(first, _link(seed: 3).register());
      final other = _link(seed: 4).register();
      expect(other, isNot(first));
      expect(_sent(other, _key).upstream.string(1), _sent(first, _key).upstream.string(1));
    });
  });

  group('what the link reads', () {
    test('a register answer brings the session key, and everything after it is mode 2', () {
      final link = _link();
      final packet = link.read(_downstream(AcfunDanmakuProtocol.registerCommand, body: _registerBody(), key: _key));
      expect(packet.command, AcfunDanmakuProtocol.registerCommand);
      expect(packet.errorCode, 0);
      expect(packet.seqId, 1);
      expect(link.registered, isTrue);

      final keepAlive = _sent(link.keepAlive(), _sessionKey);
      expect(keepAlive.header.integer(8), 2, reason: 'after the answer the link seals with the session key');
      expect(keepAlive.header.integer(3), 99, reason: 'the instance id the answer gave rides on every frame');
      expect(keepAlive.upstream.string(1), AcfunDanmakuProtocol.keepAliveCommand);
    });

    test('an answer without a key of the right length leaves the link unregistered', () {
      for (final body in [
        _registerBody(sessionKey: List.filled(8, 1)),
        _registerBody(sessionKey: List.filled(32, 1)),
        _registerBody(sessionKey: null),
      ]) {
        final link = _link()..read(_downstream(AcfunDanmakuProtocol.registerCommand, body: body, key: _key));
        expect(link.registered, isFalse, reason: '$body is not a session key');
        expect(link.keepAlive, throwsStateError);
      }
      // A refused register keeps nothing either.
      final refused = _link()
        ..read(
          _downstream(
            AcfunDanmakuProtocol.registerCommand,
            errorCode: 42,
            error: 'no',
            body: _registerBody(),
            key: _key,
          ),
        );
      expect(refused.registered, isFalse);
    });

    test('every sealing mode is opened by the key it was sealed with', () {
      final body = (AcfunProtoWriter()..string(1, 'x')).toBytes();
      final link = _registered();

      final unsealed = link.read(_downstream(AcfunDanmakuProtocol.messageCommand, mode: 0, body: body, seqId: 5));
      expect(unsealed.command, AcfunDanmakuProtocol.messageCommand);
      expect(unsealed.payload, body);
      expect(unsealed.seqId, 5, reason: 'a mode 0 frame still carries the header sequence');

      final sealed = link.read(_downstream(AcfunDanmakuProtocol.messageCommand, mode: 2, body: body, key: _sessionKey));
      expect(sealed.payload, body);

      final bySecurity = _link().read(_downstream(AcfunDanmakuProtocol.enterRoomAck, body: body, key: _key));
      expect(bySecurity.payload, body);
    });

    test('a frame that cannot be opened is one bad packet, not one bad room', () {
      final body = (AcfunProtoWriter()..string(1, 'x')).toBytes();
      final sealed = _downstream(AcfunDanmakuProtocol.messageCommand, mode: 2, body: body, key: _sessionKey);
      expect(() => _link().read(sealed), throwsFormatException, reason: 'no session key to open it with');

      final link = _registered();
      expect(
        () => link.read(_downstream(AcfunDanmakuProtocol.messageCommand, mode: 2, body: body, key: _otherKey)),
        throwsFormatException,
        reason: 'the wrong key does not open it',
      );
      for (final mode in [3, 7]) {
        expect(
          () => link.read(_downstream('X', mode: mode, key: _key)),
          throwsFormatException,
          reason: 'mode $mode is not a sealing this link knows',
        );
      }
      expect(() => link.read(Uint8List.fromList([0, 0, 1])), throwsFormatException, reason: 'shorter than its prefix');
      final frame = AcfunDanmakuProtocol.frame(const [0x08, 0x01], const [1, 2, 3]);
      expect(
        () => link.read(Uint8List.fromList(frame.sublist(0, frame.length - 1))),
        throwsFormatException,
        reason: 'a frame whose lengths do not add up',
      );
    });

    test('a packet says what it is even when it says nothing else', () {
      final packet = _link().read(_downstream('Basic.Ping', key: _key));
      expect(packet.command, 'Basic.Ping');
      expect(packet.error, isEmpty);
      expect(packet.payload, isEmpty);
      expect(packet.errorCode, 0);
      final refused = _link().read(_downstream('Basic.Ping', errorCode: 50, error: 'rate limited', key: _key));
      expect(refused.errorCode, 50);
      expect(refused.error, 'rate limited');
    });
  });

  group('the payloads a room page reads apart from the link', () {
    test('an ack names its type, its code and its body', () {
      final body = (AcfunProtoWriter()..integer(1, 5000)).toBytes();
      final answer = AcfunDanmakuProtocol.ack(
        (AcfunProtoWriter()
              ..string(1, AcfunDanmakuProtocol.enterRoomAck)
              ..integer(2, 0)
              ..bytes(4, body))
            .toBytes(),
      );
      expect(answer.type, AcfunDanmakuProtocol.enterRoomAck);
      expect(answer.code, 0);
      expect(AcfunDanmakuProtocol.heartbeatInterval(answer.payload), const Duration(milliseconds: 5000));

      final empty = AcfunDanmakuProtocol.ack(const <int>[]);
      expect(empty.type, isEmpty);
      expect(empty.code, 0);
      expect(empty.payload, isEmpty);
      expect(
        AcfunDanmakuProtocol.ack((AcfunProtoWriter()..string(2, 'a code that is not a number')).toBytes()).code,
        0,
        reason: 'a field sent with another wire type is not the field',
      );
      expect(() => AcfunDanmakuProtocol.ack(Uint8List.fromList([0xFF, 0xFF])), throwsFormatException);
    });

    test('sealing and opening round trip, and a short payload is refused', () {
      final plain = utf8.encode('a payload the room page will decode');
      final sealed = AcfunDanmakuProtocol.seal(plain, _key, _iv);
      expect(sealed.sublist(0, 16), _iv);
      expect(AcfunDanmakuProtocol.open(sealed, _key), Uint8List.fromList(plain));
      expect(() => AcfunDanmakuProtocol.open(sealed.sublist(0, 31), _key), throwsFormatException);
      expect(() => AcfunDanmakuProtocol.open(Uint8List(31), _key), throwsFormatException);
      expect(() => AcfunDanmakuProtocol.open(sealed, _otherKey), throwsFormatException);
      // A whole block of padding is a valid empty payload.
      expect(AcfunDanmakuProtocol.open(AcfunDanmakuProtocol.seal(const [], _key, _iv), _key), isEmpty);
    });

    test('the keys an answer cannot bring are read as no key', () {
      expect(AcfunDanmakuProtocol.securityKey(_security), _key);
      expect(AcfunDanmakuProtocol.securityKey(base64.encode(List.filled(16, 9))), hasLength(16));
      for (final value in [
        null,
        '',
        'not base64!',
        base64.encode(List.filled(15, 1)),
        base64.encode(List.filled(32, 1)),
      ]) {
        expect(AcfunDanmakuProtocol.securityKey(value), isNull, reason: '$value seals nothing');
      }
    });

    test('a push skips a signal payload that does not read and keeps the ones that do', () {
      final oneSignal =
          (AcfunProtoWriter()
                ..string(1, 'CommonActionSignalComment')
                ..bytes(2, Uint8List.fromList([0xFF, 0xFF]))
                ..bytes(2, _comment('kept')))
              .toBytes();
      final push = AcfunDanmakuProtocol.push(
        _scMessage('ZtLiveScActionSignal', (AcfunProtoWriter()..bytes(1, oneSignal)).toBytes()),
      );
      expect(push.messages.map((message) => message.text), ['kept']);
      // A comment with no sender is not shown either, and a signal that does not
      // decode leaves the others standing.
      final body =
          (AcfunProtoWriter()
                ..bytes(1, Uint8List.fromList([0xFF, 0xFF]))
                ..bytes(
                  1,
                  (AcfunProtoWriter()
                        ..string(1, 'CommonActionSignalComment')
                        ..bytes(2, (AcfunProtoWriter()..string(1, 'text with no sender')).toBytes()))
                      .toBytes(),
                )
                ..bytes(
                  1,
                  (AcfunProtoWriter()
                        ..string(1, 'CommonActionSignalComment')
                        ..bytes(2, _comment('second')))
                      .toBytes(),
                ))
              .toBytes();
      final list = AcfunDanmakuProtocol.push(_scMessage('ZtLiveScActionSignal', body));
      expect(list.messages.map((message) => message.text), ['second'], reason: 'a signal names its type to be read');

      // Two comments in one signal are two messages, in the order they came.
      final two =
          (AcfunProtoWriter()
                ..string(1, 'CommonActionSignalComment')
                ..bytes(2, _comment('one'))
                ..bytes(2, _comment('two')))
              .toBytes();
      final both = AcfunDanmakuProtocol.push(
        _scMessage('ZtLiveScActionSignal', (AcfunProtoWriter()..bytes(1, two)).toBytes()),
      );
      expect(both.messages.map((message) => message.text), ['one', 'two']);
      expect(both.ticketInvalid, isFalse);
      expect(both.statusChanged, isNull);
    });

    test('a message that is not one the room shows gives nothing', () {
      final none = AcfunDanmakuProtocol.push(Uint8List.fromList([0x08, 0x01]));
      expect(none.messages, isEmpty);
      expect(none.ticketInvalid, isFalse);
      expect(none.statusChanged, isNull);

      expect(AcfunDanmakuProtocol.push(_scMessage('ZtLiveScNotifySignal')).messages, isEmpty);
      expect(AcfunDanmakuProtocol.push(_scMessage('')).ticketInvalid, isFalse);
      final bare = AcfunDanmakuProtocol.push((AcfunProtoWriter()..string(1, 'ZtLiveScStatusChanged')).toBytes());
      expect(bare.statusChanged, 0, reason: 'a status change with no body is still a status change');
    });

    test('a gzipped body that is not gzip yields nothing', () {
      final push = AcfunDanmakuProtocol.push(
        (AcfunProtoWriter()
              ..string(1, 'ZtLiveScActionSignal')
              ..integer(2, 2)
              ..bytes(3, Uint8List.fromList([1, 2, 3, 4])))
            .toBytes(),
      );
      expect(push.messages, isEmpty);
      expect(push.ticketInvalid, isFalse);
      expect(push.statusChanged, isNull);
    });
  });
}
