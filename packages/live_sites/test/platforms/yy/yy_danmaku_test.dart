import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku_codec.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_packet.dart';
import 'package:test/test.dart';

/// The uris the H5 service spells in its headers (the session keeps its own
/// copies private; naming them here is the point of the pin).
const int _anonymousLoginRequest = 778244;
const int _anonymousLoginResponse = 778500;
const int _anonymousLoginReal = 20078;
const int _apLoginRequest = 775684;
const int _apLoginResponse = 775940;
const int _apPingRequest = 794116;
const int _apRouterResponse = 512011;
const int _joinChannelRequest = 513035;
const int _appSubscription = 538456;
const int _joinChannelResponse = 2048514;
const int _userGroupMessage = 533080;
const int _bySidMessage = 28760;
const int _textChat = 3104600;
const int _popularity = 3139586;
const int _otherAudience = 3165186;
const int _chatAppId = 31;
const int _audienceAppId = 103;

const int _topSid = 123456;
const int _subSid = 789012;
const String _uuid = '12345678-1234-4234-8234-123456789abc';

/// A packet of [uri] with [body] behind its header.
Uint8List _packetOf(int uri, void Function(YyPacketWriter writer) body) {
  final writer = YyPacketWriter(uri: uri);
  body(writer);
  // takeBytes fills the header's length, so a packet writes itself as the
  // edge does.
  return writer.takeBytes();
}

/// A bare field list (a payload that rides inside another packet).
Uint8List _fields(void Function(YyPacketWriter writer) body) {
  final writer = YyPacketWriter();
  body(writer);
  return writer.takeBytes();
}

int _uriOf(List<int> packet) => YyPacketReader(Uint8List.fromList(packet), hasHeader: true).uri;

/// The anonymous login's answer, as the edge writes it.
Uint8List _anonymousLoginReply({
  int envelopeCode = 200,
  int realUri = _anonymousLoginReal,
  int resultCode = 200,
  int uid32 = 4242,
  String userName = 'guest',
}) {
  final payload = _fields((w) {
    w
      ..writeString('')
      ..writeUint32(resultCode)
      ..writeUint32(uid32)
      ..writeUint32(uid32) // yyid
      ..writeString(userName)
      ..writeString('ticket-password')
      ..writeByteArray(utf8.encode('cookie'))
      ..writeByteArray(const <int>[1, 2, 3])
      ..writeString('')
      ..writeString('');
  });
  return _packetOf(_anonymousLoginResponse, (w) {
    w
      ..writeString('')
      ..writeUint32(envelopeCode)
      ..writeUint32(realUri)
      ..writeByteArray32(payload);
  });
}

/// The AP login's answer.
Uint8List _apLoginReply({int resultCode = 200}) => _packetOf(_apLoginResponse, (w) {
  w
    ..writeUint32(0)
    ..writeUint32(resultCode)
    ..writeString('1:0');
});

/// A routed answer: the join's, or a message wrapped in the router.
Uint8List _routed(int realUri, Uint8List payload, {int responseCode = 0}) => _packetOf(_apRouterResponse, (w) {
  w
    ..writeString('')
    ..writeUint32(realUri)
    ..writeUint16(responseCode)
    ..writeByteArray32(payload);
});

/// The join's answer inside the router's envelope.
Uint8List _joinReply({int topSid = _topSid, int subSid = _subSid, int loginStatus = 4, String error = ''}) {
  return _fields((w) {
    w
      ..writeUint32(topSid)
      ..writeUint32(4242)
      ..writeUint32(subSid)
      ..writeUint32(1)
      ..writeUint32(1790519893)
      ..writeUint8(loginStatus)
      ..writeUtf8String(error);
  });
}

/// A chat body for app 31 (`3104600`).
Uint8List _chatBody({
  int topSid = _topSid,
  int subSid = _subSid,
  String text = 'hello',
  String userName = 'speaker',
  int extras = 0,
}) {
  final block = _fields((w) {
    w
      ..writeUint32(0) // effects
      ..writeUcs2String32('微软雅黑') // font
      ..writeUint32(0xFFFFFF) // colour
      ..writeUint32(18) // height
      ..writeUcs2String32(text)
      ..writeUint32(0); // screen mode
  });
  final tail = _fields((w) {
    w
      ..writeString('')
      ..writeString('');
    if (userName.isNotEmpty) {
      w
        ..writeUtf8String(userName)
        ..writeUint32(extras);
      for (var index = 0; index < extras; index++) {
        w
          ..writeUint16(index)
          ..writeUtf8String('extra');
      }
    }
  });
  return _packetOf(_textChat, (w) {
    w
      ..writeUint32(4242)
      ..writeUint32(topSid)
      ..writeUint32(subSid)
      ..writeUint16(block.length)
      ..writeBytes(block)
      ..writeBytes(tail);
  });
}

/// The channel's heat for app 103 (`3139586`).
Uint8List _popularityBody({int heat = 5856, int topSid = _topSid}) => _packetOf(_popularity, (w) {
  w
    ..writeUint32(heat)
    ..writeUint32(1)
    ..writeUint32(topSid)
    ..writeUint32(heat - 40);
});

/// A user group message (`533080`) carrying [service] for [appId].
Uint8List _userGroup(int appId, Uint8List service) => _packetOf(_userGroupMessage, (w) {
  w
    ..writeUint64(1)
    ..writeUint64(2)
    ..writeUint32(appId)
    ..writeByteArray32(service);
});

/// The user group message's fields as the router carries them (a payload, so
/// no header of its own inside the envelope).
Uint8List _userGroupFields(int appId, Uint8List service) => _fields((w) {
  w
    ..writeUint64(1)
    ..writeUint64(2)
    ..writeUint32(appId)
    ..writeByteArray32(service);
});

/// A by-sid message (`28760`) carrying [service] for [appId].
Uint8List _bySid(int appId, Uint8List service) => _packetOf(_bySidMessage, (w) {
  w
    ..writeUint16(appId)
    ..writeUint32(_topSid)
    ..writeByteArray(service);
});

/// A session walked to [phase] of the anonymous handshake, so a case writes
/// only the answer it is about.
YyProtocolSession _awaiting(YyProtocolPhase phase, {int topSid = _topSid, int subSid = _subSid}) {
  final session = YyProtocolSession(topSid: topSid, subSid: subSid, uuid: _uuid)..beginHandshake();
  if (phase.index > YyProtocolPhase.waitingUdb.index) session.consume(_anonymousLoginReply());
  if (phase.index > YyProtocolPhase.waitingAp.index) session.consume(_apLoginReply());
  if (phase.index > YyProtocolPhase.waitingJoin.index) {
    session.consume(_routed(_joinChannelResponse, _joinReply(topSid: topSid, subSid: subSid)));
  }
  return session;
}

/// A session that has joined the channel, ready to read services.
YyProtocolSession _joined({int topSid = _topSid, int subSid = _subSid}) =>
    _awaiting(YyProtocolPhase.joined, topSid: topSid, subSid: subSid);

void main() {
  group('the protocol and its numbers', () {
    test('the endpoint names the app, the protocol version and this connection', () {
      final uri = YyDanmakuProtocol.endpoint(_uuid);
      expect(uri.toString(), 'wss://h5-sinchl.yy.com/websocket?appid=yymwebh5&version=3.2.10&uuid=$_uuid');
      expect(uri.queryParameters['version'], YyDanmakuProtocol.version);
    });

    test("the handshake headers are YY's spelling, in order", () {
      // REG-YY-001: the edge ignores a lower-cased handshake.
      expect(YyDanmakuProtocol.headers.keys, ['User-Agent', 'Origin']);
      expect(YyDanmakuProtocol.headers['Origin'], 'https://www.yy.com');
      expect(YyDanmakuProtocol.headers['User-Agent'], contains('Chrome/151.0.0.0'));
    });

    test('the timing is 3.x: 5 s heartbeat, 45 s silence, 15 s handshake, 8 reconnects', () {
      expect(YyDanmakuProtocol.heartbeatInterval, const Duration(seconds: 5));
      expect(YyDanmakuProtocol.inactivityTimeout, const Duration(seconds: 45));
      expect(YyDanmakuProtocol.handshakeTimeout, const Duration(seconds: 15));
      expect(YyDanmakuProtocol.maxReconnects, 8);
      expect(YyDanmakuProtocol.reconnectBaseDelay, const Duration(seconds: 1));
    });

    test('a connection uuid is version 4, lower case, and new each time', () {
      final seeds = [for (var seed = 0; seed < 20; seed++) YyDanmakuProtocol.uuid(Random(seed))];
      for (final uuid in seeds) {
        expect(uuid, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      }
      expect(seeds.toSet(), hasLength(20));
    });
  });

  group('the packet reader and writer', () {
    test('every field kind round-trips little endian', () {
      final bytes = _packetOf(1234, (w) {
        w
          ..writeUint8(200)
          ..writeUint16(0xBEEF)
          ..writeUint32(0xF00DBEEF)
          ..writeUint64(0x00000001_00000002)
          ..writeByteArray(const <int>[9, 8, 7])
          ..writeByteArray32(const <int>[6, 5, 4, 3])
          ..writeString('yy')
          ..writeUtf8String('用户')
          ..writeUcs2String32('用户');
      });
      final reader = YyPacketReader(bytes, hasHeader: true);
      expect(reader.packetLength, bytes.length);
      expect(reader.uri, 1234);
      expect(reader.responseCode, 200);
      expect(reader.readUint8(), 200);
      expect(reader.readUint16(), 0xBEEF);
      expect(reader.readUint32(), 0xF00DBEEF);
      expect(reader.readUint64(), 0x0000000100000002);
      expect(reader.readByteArray(), <int>[9, 8, 7]);
      expect(reader.readByteArray32(), <int>[6, 5, 4, 3]);
      expect(reader.readString(), 'yy');
      expect(reader.readUtf8String(), '用户');
      expect(reader.readUcs2String32(), '用户');
      expect(reader.bytesAvailable, 0);
    });

    test('the header answers with the packet it belongs to, not its body', () {
      final bytes = _packetOf(4321, (w) => w.writeUint32(7));
      expect(bytes.sublist(4, 8), [0xE1, 0x10, 0, 0], reason: 'the uri is the little-endian u32 after the length');
      expect(YyPacketReader(bytes, hasHeader: true).readUint32(), 7);
    });

    test('a read past the end is a FormatException, not a silent zero', () {
      final reader = YyPacketReader(Uint8List(3));
      expect(reader.readUint16, returnsNormally);
      expect(reader.readUint8, returnsNormally);
      expect(reader.readUint8, throwsFormatException);
      expect(() => YyPacketReader(Uint8List(2), hasHeader: true).readUint32(), throwsFormatException);
    });

    test('a header that lies about its own length is refused', () {
      final short = Uint8List(12);
      ByteData.sublistView(short).setUint32(0, 9, Endian.little);
      expect(() => YyPacketReader(short, hasHeader: true), throwsFormatException);

      final long = Uint8List(12);
      ByteData.sublistView(long).setUint32(0, 99, Endian.little);
      expect(() => YyPacketReader(long, hasHeader: true), throwsFormatException);
    });

    test('a UCS-2 string with an odd last byte drops it', () {
      final bytes = _fields(
        (w) => w
          ..writeUint32(5)
          ..writeBytes(<int>[0x41, 0x00, 0x42, 0x00, 0xFF]),
      );
      expect(YyPacketReader(bytes).readUcs2String32(), 'AB');
    });
  });

  group('the text of a line', () {
    test('an XML-wrapped body gives the txt data, joined and decoded', () {
      expect(
        YyDanmakuProtocol.chatText('<?xml version="1.0"?><msg><txt data="one" /></msg>'),
        'one',
        reason: '3.x showed the wrapper as the text',
      );
      expect(YyDanmakuProtocol.chatText('<msg><txt data=\'a\' /><txt data="b" /></msg>'), 'ab');
      expect(YyDanmakuProtocol.chatText('<msg><txt data="a&amp;b &lt;c &#65; &#x42;" /></msg>'), 'a&b <c A B');
      expect(YyDanmakuProtocol.chatText('<msg><txt other="x" /></msg>'), isEmpty);
    });

    test('a plain body and an emoticon code are kept as written', () {
      expect(YyDanmakuProtocol.chatText('  你好 /{tx  '), '你好 /{tx');
      expect(
        YyDanmakuProtocol.chatText('<msg>no txt data here</msg>'),
        isEmpty,
        reason: 'a wrapper with nothing in it',
      );
      expect(
        YyDanmakuProtocol.chatText('<txt data="not a msg wrapper" />'),
        '<txt data="not a msg wrapper" />',
        reason: 'only the xml and msg prefixes are unwrapped',
      );
      expect(
        YyDanmakuProtocol.chatText('<msg><txt data="&#xZZ;" /></msg>'),
        '&#xZZ;',
        reason: 'no such character: say it as written',
      );
    });

    test('a failure is one line and at most 120 characters', () {
      expect(YyDanmakuProtocol.compactFailure('line\n  one\r\ntwo'), 'line one two');
      final long = YyDanmakuProtocol.compactFailure('x' * 300);
      expect(long.length, 120);
      expect(long.endsWith('...'), isTrue);
    });
  });

  group('the anonymous handshake', () {
    test('it starts over and asks for the UDB login, with no heartbeat yet', () {
      final session = YyProtocolSession(topSid: _topSid, subSid: _subSid, uuid: _uuid);
      expect(session.phase, YyProtocolPhase.idle);
      expect(session.heartbeat(), isNull, reason: '3.x sent no heartbeat before the AP login');

      final first = session.beginHandshake();
      expect(session.phase, YyProtocolPhase.waitingUdb);
      expect(_uriOf(first), _anonymousLoginRequest);
    });

    test('the UDB answer asks for the AP login, and the heartbeat starts with it', () {
      final session = _awaiting(YyProtocolPhase.waitingUdb);
      final batch = session.consume(_anonymousLoginReply());
      expect(session.phase, YyProtocolPhase.waitingAp);
      expect(batch.failure, isNull);
      expect(batch.outbound, hasLength(1));
      expect(_uriOf(batch.outbound.single), _apLoginRequest);
      expect(_uriOf(session.heartbeat()!), _apPingRequest);
    });

    test('a refused or identity-less UDB answer fails the join', () {
      for (final reply in [
        _anonymousLoginReply(envelopeCode: 500),
        _anonymousLoginReply(resultCode: 401),
        _anonymousLoginReply(uid32: 0),
        _anonymousLoginReply(realUri: 999999),
      ]) {
        final session = _awaiting(YyProtocolPhase.waitingUdb);
        final batch = session.consume(reply);
        expect(session.phase, YyProtocolPhase.failed, reason: '$reply is not a login');
        expect(batch.failure, isNotNull);
      }
    });

    test('the AP answer sends the join and the app subscription together', () {
      final session = _awaiting(YyProtocolPhase.waitingAp);
      final batch = session.consume(_apLoginReply());
      expect(session.phase, YyProtocolPhase.waitingJoin);
      expect(batch.outbound.map(_uriOf), [_joinChannelRequest, _appSubscription]);

      final refused = _awaiting(YyProtocolPhase.waitingAp);
      final refusal = refused.consume(_apLoginReply(resultCode: 403));
      expect(refused.phase, YyProtocolPhase.failed);
      expect(refusal.failure, contains('403'));
    });

    test('the join lands on two subscriptions and says the room is ready', () {
      final session = _awaiting(YyProtocolPhase.waitingJoin);
      final batch = session.consume(_routed(_joinChannelResponse, _joinReply()));
      expect(session.phase, YyProtocolPhase.joined);
      expect(batch.becameReady, isTrue);
      expect(batch.failure, isNull);
    });

    test("another channel's join, or a status that is not 4, is a failure", () {
      for (final payload in [_joinReply(topSid: 999), _joinReply(subSid: 999), _joinReply(loginStatus: 2)]) {
        final session = _awaiting(YyProtocolPhase.waitingJoin);
        final batch = session.consume(_routed(_joinChannelResponse, payload));
        expect(session.phase, YyProtocolPhase.failed);
        expect(batch.failure, contains('YY failed to join the channel'));
      }
      final session = _awaiting(YyProtocolPhase.waitingJoin);
      final refused = session.consume(_routed(_joinChannelResponse, _joinReply(), responseCode: 403));
      expect(refused.failure, contains('YY channel routing failed'));
    });

    test('a packet that cannot be read while joining fails; later it only warns', () {
      final early = _awaiting(YyProtocolPhase.waitingUdb);
      final broken = _packetOf(_anonymousLoginResponse, (w) => w.writeUint8(1));
      expect(early.consume(broken).failure, isNotNull);
      expect(early.phase, YyProtocolPhase.failed);

      final session = _joined();
      final late = session.consume(_packetOf(_userGroupMessage, (w) => w.writeUint8(1)));
      expect(late.failure, isNull);
      expect(late.warnings, isNotEmpty);
      expect(session.phase, YyProtocolPhase.joined);
    });
  });

  group('after the join', () {
    test('a line arrives with the speaker it names, white, and the anonymous name when it says none', () {
      final batch = _joined().consume(_bySid(_chatAppId, _chatBody(text: '你好')));
      final line = batch.messages.single;
      expect(line.type, LiveMessageType.chat);
      expect(line.text, '你好');
      expect(line.effectiveSender.userName, 'speaker');
      expect(<int>[line.effectiveColor.r, line.effectiveColor.g, line.effectiveColor.b], [255, 255, 255]);

      final noName = _joined().consume(_bySid(_chatAppId, _chatBody(userName: '')));
      expect(noName.messages.single.effectiveSender.userName, YyDanmakuProtocol.anonymousUserName);

      final wrapped = _joined().consume(_bySid(_chatAppId, _chatBody(text: '<msg><txt data="unwrapped" /></msg>')));
      expect(wrapped.messages.single.text, 'unwrapped');
    });

    test('an empty line, another channel, and extras in the tail are handled as 3.x does', () {
      expect(_joined().consume(_bySid(_chatAppId, _chatBody(text: ''))).messages, isEmpty);
      expect(_joined().consume(_bySid(_chatAppId, _chatBody(topSid: 999))).messages, isEmpty);
      expect(_joined().consume(_bySid(_chatAppId, _chatBody(subSid: 999))).messages, isEmpty);
      expect(_joined().consume(_bySid(_chatAppId, _chatBody(extras: 2))).messages.single.text, 'hello');
    });

    test('chat also arrives routed, and services before the join are not read', () {
      expect(
        _joined().consume(_routed(_userGroupMessage, _userGroupFields(_chatAppId, _chatBody()))).messages,
        hasLength(1),
      );

      final early = _awaiting(YyProtocolPhase.waitingUdb);
      expect(early.consume(_bySid(_chatAppId, _chatBody())).messages, isEmpty, reason: 'not joined yet');
    });

    test("the channel's heat is popularity; another channel's and the unknown companion are not read", () {
      final batch = _joined().consume(_userGroup(_audienceAppId, _popularityBody()));
      final line = batch.messages.single;
      expect(line.type, LiveMessageType.audienceUpdate);
      final update = line.payload! as LiveAudienceUpdate;
      expect(update.kind, LiveAudienceSignalKind.popularity);
      expect(update.value, 5856);

      expect(_joined().consume(_userGroup(_audienceAppId, _popularityBody(topSid: 999))).messages, isEmpty);
      expect(
        _joined().consume(_userGroup(_audienceAppId, _packetOf(_otherAudience, (w) => w.writeUint32(3)))).messages,
        isEmpty,
      );
      expect(_joined().consume(_userGroup(15012, _packetOf(_textChat, (w) => w.writeUint32(1)))).messages, isEmpty);
      expect(
        _joined().consume(_userGroup(_audienceAppId, Uint8List(4))).messages,
        isEmpty,
        reason: 'a scrubbed body shorter than a header is nothing to read',
      );
    });

    test('one frame holds several packets in order, and a broken tail ends it', () {
      final session = _joined();
      final batch = session.consume([
        ..._bySid(_chatAppId, _chatBody(text: 'first')),
        ..._bySid(_chatAppId, _chatBody(text: 'second')),
        ..._userGroup(_audienceAppId, _popularityBody(heat: 30)),
      ]);
      expect(batch.messages.map((line) => line.text), ['first', 'second', '']);
      expect(batch.messages.first.text, 'first');
      expect(batch.messages.last.type, LiveMessageType.audienceUpdate);
      expect(batch.warnings, isEmpty);

      final trailing = session.consume([..._bySid(_chatAppId, _chatBody(text: 'kept')), 1, 2, 3]);
      expect(trailing.messages.map((line) => line.text), ['kept']);
      expect(trailing.warnings, isNotEmpty);

      final lying = session.consume(
        _packetOf(_bySidMessage, (w) {
          w
            ..writeUint32(_topSid)
            ..writeByteArray(utf8.encode('x'));
        }),
      );
      expect(lying.warnings, isNotEmpty);
    });

    test('a failure detail is one line, at most 120 characters, whatever the socket said', () {
      final long = 'YY could not join: ${'y' * 300}';
      expect(YyDanmakuProtocol.compactFailure(long).length, 120);
    });
  });
}
