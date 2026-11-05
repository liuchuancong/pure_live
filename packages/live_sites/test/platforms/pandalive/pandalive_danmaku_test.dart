import 'dart:convert';

import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/pandalive/api/pandalive_endpoints.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';
import 'package:test/test.dart';

/// A `live/play` answer as the transport hands it.
({String text, int status}) _play(Object? data, {int status = 200}) =>
    (text: data is String ? data : jsonEncode(data), status: status);

/// The `live/play` answer that grants a chat.
Map<String, Object?> _granted({
  Object? channel = '123456',
  String token = 'a.b.c',
  bool result = true,
  Object? media,
}) => {'result': result, 'channel': ?channel, 'token': token, 'media': ?media};

/// One JWT of [exp] as the site writes it (header.payload.signature).
String _jwt(Object? exp) => [
  base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256'}))),
  base64Url.encode(utf8.encode(jsonEncode({'exp': ?exp, 'sub': '123456'}))),
  'signature',
].map((part) => part.replaceAll('=', '')).join('.');

/// The publication `chat` and `hearts` read: the message and its place.
Map<String, Object?> _publication(Map<String, Object?> message, {Object? offset = 42}) => {
  'data': message,
  'offset': ?offset,
};

/// A push of [channel] carrying that publication.
String _push(Map<String, Object?> message, {Object? offset = 42, String channel = '123456'}) => jsonEncode({
  'result': {'channel': channel, 'data': _publication(message, offset: offset)},
});

/// A chat message of the site's shape.
Map<String, Object?> _message({
  String type = 'chatter',
  String message = '안녕',
  Object? nk = 'viewers',
  Object? id = 'user1',
  Object? createdAt = 1790733600,
  Object? emoticon,
}) => {'type': type, 'message': message, 'nk': ?nk, 'id': ?id, 'created_at': ?createdAt, 'emoticon': ?emoticon};

/// One frame: these reply/push lines joined by the newline the protocol uses.
String _frameOf(List<String> lines) => lines.join('\n');

/// A reply of [id] with an optional result or error.
String _reply(Object? id, {Object? result, Object? error}) =>
    jsonEncode({'id': ?id, 'result': ?result, 'error': ?error});

void main() {
  group('what the client sends', () {
    test('the connect carries the token, the subscribe the channel, the ping its id', () {
      expect(jsonDecode(PandaliveDanmakuCodec.connect('t-1')), {
        'params': {'token': 't-1', 'name': 'js'},
        'id': 1,
      });
      expect(jsonDecode(PandaliveDanmakuCodec.subscribe('123456')), {
        'method': 1,
        'params': {'channel': '123456'},
        'id': 2,
      });
      expect(jsonDecode(PandaliveDanmakuCodec.ping(9)), {'method': 7, 'id': 9});
      expect(PandaliveDanmakuCodec.connectId, 1);
      expect(PandaliveDanmakuCodec.subscribeId, 2, reason: 'pings count on from the subscription');
    });

    test('the session’s own numbers', () {
      expect(PandaliveDanmakuCodec.heartbeatInterval, const Duration(seconds: 25));
      expect(PandaliveDanmakuCodec.joinTimeout, const Duration(seconds: 8));
      expect(PandaliveDanmakuCodec.silenceTimeout, const Duration(seconds: 90));
      expect(PandaliveDanmakuCodec.renewalLead, const Duration(seconds: 60));
      expect(PandaliveDanmakuCodec.maxRefusals, 3);
      expect(PandaliveDanmakuCodec.maxReconnects, 8);
      expect(PandaliveDanmakuCodec.reconnectBaseDelay, const Duration(seconds: 1));
      expect(PandaliveDanmakuCodec.chatTypes, {'bj', 'chatter', 'manager', 'support'});
      expect(PandaliveDanmakuCodec.heartName, '하트');
      expect(PandaliveDanmakuCodec.endpoint.toString(), PandaliveEndpoints.chatUrl);
      expect(PandaliveDanmakuCodec.socketHeaders, {
        'origin': PandaliveEndpoints.origin,
        'user-agent': PandaliveEndpoints.userAgent,
      });
    });

    test('a token is renewed a minute early, or halfway when it is short', () {
      expect(PandaliveDanmakuCodec.renewalDelay(const Duration(minutes: 30)), const Duration(minutes: 29));
      expect(PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 121)), const Duration(seconds: 61));
      expect(
        PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 120)),
        const Duration(seconds: 60),
        reason: 'exactly twice the lead is not over it',
      );
      expect(PandaliveDanmakuCodec.renewalDelay(const Duration(seconds: 10)), const Duration(seconds: 5));
      expect(PandaliveDanmakuCodec.renewalDelay(Duration.zero), Duration.zero);
    });
  });

  group('the grant of a broadcast', () {
    test('an accepted answer gives the channel and its token', () {
      expect(PandaliveDanmakuCodec.grant(_play(_granted())), (channel: '123456', token: 'a.b.c'));
      expect(
        PandaliveDanmakuCodec.grant(_play(_granted(channel: ' 123456 '))).channel,
        '123456',
        reason: 'the answer is trimmed, as every text field here is',
      );
    });

    test('a refused answer names the platform’s reason', () {
      PandaliveChatRefusal refused(Map<String, Object?> data) {
        try {
          PandaliveDanmakuCodec.grant(_play(data));
          throw StateError('the answer was accepted');
        } on PandaliveChatRefusal catch (failure) {
          return failure;
        }
      }

      expect(
        refused({
          'result': false,
          'errorData': {'code': 'castEnd'},
        }).code,
        'castEnd',
      );
      expect(
        refused({
          'result': false,
          'errorData': {'code': 'castEnd'},
        }).toString(),
        'live/play: castEnd',
      );
      expect(refused({'result': false}).code, isEmpty);
      expect(refused({'result': false}).toString(), 'live/play: refused');
      expect(refused(_granted(media: {'isLive': false})).code, 'not live');
      expect(refused(_granted(media: {'isLive': 'N'})).code, 'not live');
      expect(refused(_granted(media: {'isLive': 0})).code, 'not live');
      expect(
        PandaliveDanmakuCodec.grant(_play(_granted(media: {'isLive': 'Y'}))).channel,
        '123456',
        reason: 'the site writes its flags as text',
      );
      expect(
        PandaliveDanmakuCodec.grant(_play(_granted(media: {'other': 1}))).channel,
        '123456',
        reason: 'a media without the flag is not a refusal',
      );
    });

    test('an answer that cannot be used is the site’s shape changing', () {
      PandaliveFailureKind of(Object? data, {int status = 200}) {
        try {
          PandaliveDanmakuCodec.grant(_play(data, status: status));
          return PandaliveFailureKind.network;
        } on PandaliveFailure catch (failure) {
          return failure.kind;
        }
      }

      expect(of('not json'), PandaliveFailureKind.apiChanged);
      expect(of([1, 2]), PandaliveFailureKind.apiChanged, reason: 'not an object');
      expect(of({'channel': '123456', 'token': 'a.b.c'}), PandaliveFailureKind.apiChanged, reason: 'no result flag');
      expect(of(_granted(channel: 'abc')), PandaliveFailureKind.apiChanged, reason: 'a channel that is not a number');
      expect(
        of(_granted(channel: 123456)),
        PandaliveFailureKind.apiChanged,
        reason: 'the answer must write the number as text: this reads only text',
      );
      expect(of(_granted(channel: '')), PandaliveFailureKind.apiChanged);
      expect(of(_granted(channel: null)), PandaliveFailureKind.apiChanged);
      expect(of(_granted(token: '')), PandaliveFailureKind.apiChanged, reason: 'an empty token is no token');
      expect(of(_granted()..remove('token')), PandaliveFailureKind.apiChanged);
      expect(of(_granted(token: 'two parts')), PandaliveFailureKind.apiChanged, reason: 'a token with a space');
      expect(
        of(_granted(), status: 400),
        PandaliveFailureKind.network,
        reason: 'HTTP 400 is how the site answers a refusal, so it is not a shape change',
      );
      expect(of(_granted(), status: 503), PandaliveFailureKind.network);
    });

    test('when the token lapses, from its own claim', () {
      expect(
        PandaliveDanmakuCodec.tokenExpiry(_jwt(1790733600)),
        DateTime.fromMillisecondsSinceEpoch(1790733600 * 1000, isUtc: true),
      );
      expect(PandaliveDanmakuCodec.tokenExpiry(_jwt(null)), isNull, reason: 'no exp says nothing');
      expect(PandaliveDanmakuCodec.tokenExpiry(_jwt(0)), isNull);
      expect(PandaliveDanmakuCodec.tokenExpiry(_jwt(-1)), isNull);
      expect(PandaliveDanmakuCodec.tokenExpiry(_jwt('1790733600')), isNull, reason: 'a text exp is not read');
      expect(PandaliveDanmakuCodec.tokenExpiry(_jwt(8640000000001)), isNull, reason: 'beyond any clock');
      expect(PandaliveDanmakuCodec.tokenExpiry('a.b'), isNull, reason: 'not three parts');
      expect(PandaliveDanmakuCodec.tokenExpiry('a.###.c'), isNull, reason: 'a payload that is not base64url');
      expect(PandaliveDanmakuCodec.tokenExpiry('a${'.'}b.c'), isNull, reason: 'a payload that is not JSON');
      expect(PandaliveDanmakuCodec.tokenExpiry(''), isNull);
    });

    test('the arguments are kept only if they name a chat', () {
      PandaliveDanmakuArgs? checked(String userId, String channel, {String? token}) =>
          PandaliveDanmakuCodec.checked(PandaliveDanmakuArgs(userId: userId, channel: channel, token: token));

      expect(checked(' ann ', ' 123456 ', token: ' a.b.c ')!.userId, 'ann');
      expect(checked('ann', '123456', token: 'a.b.c')!.token, 'a.b.c');
      expect(checked('ann', '123456')!.token, isNull, reason: 'without one a fresh token is asked for');
      expect(checked('ann', '123456', token: 'two words')!.token, isNull, reason: 'a token with a space is dropped');
      expect(checked('ann', '123456', token: '  ')!.token, isNull);
      expect(checked('ann', 'abc'), isNull, reason: 'a channel that is not a number');
      expect(checked('ann', ''), isNull);
      expect(checked('a nn', '123456'), isNull, reason: 'an id with a space is not a login');
      expect(checked('', '123456'), isNull);
      expect(checked('ann@kick', '123456')!.userId, 'ann@kick', reason: 'the site does append a suffix');
    });
  });

  group('one frame of the socket', () {
    test('the subscription reply joins, and the connect reply says how long the token lives', () {
      expect(PandaliveDanmakuCodec.decode(_reply(2), channel: '123456').joined, isTrue);
      expect(
        PandaliveDanmakuCodec.decode(_reply(1), channel: '123456').joined,
        isFalse,
        reason: 'the connect is not the join',
      );
      expect(PandaliveDanmakuCodec.decode(_reply(7), channel: '123456').joined, isFalse);
      expect(PandaliveDanmakuCodec.decode(_reply(3), channel: '123456').messages, isEmpty);

      final connect = PandaliveDanmakuCodec.decode(_reply(1, result: {'expires': true, 'ttl': 600}), channel: '123456');
      expect(connect.expiresIn, const Duration(seconds: 600));
      expect(
        PandaliveDanmakuCodec.decode(_reply(1, result: {'expires': true, 'ttl': 0}), channel: '123456').expiresIn,
        isNull,
        reason: 'a ttl of zero says nothing',
      );
      expect(
        PandaliveDanmakuCodec.decode(_reply(1, result: {'expires': false, 'ttl': 600}), channel: '123456').expiresIn,
        isNull,
        reason: 'the flag must say the token does lapse',
      );
      expect(PandaliveDanmakuCodec.decode(_reply(1), channel: '123456').expiresIn, isNull);
    });

    test('an error reply names the command and the server’s own words', () {
      expect(
        PandaliveDanmakuCodec.decode(
          _reply(1, error: {'code': 109, 'message': 'token expired'}),
          channel: '123456',
        ).refusal,
        'connect: 109 token expired',
      );
      expect(
        PandaliveDanmakuCodec.decode(
          _reply(2, error: {'code': 110, 'message': 'bad channel'}),
          channel: '123456',
        ).refusal,
        'subscribe: 110 bad channel',
      );
      expect(
        PandaliveDanmakuCodec.decode(_reply(2, error: 'nope'), channel: '123456').refusal,
        'subscribe: nope',
        reason: 'an error may be plain text',
      );
      expect(
        PandaliveDanmakuCodec.decode(_reply(7, error: {'code': 1}), channel: '123456').refusal,
        isNull,
        reason: 'a ping error is not the join’s',
      );
      final both = PandaliveDanmakuCodec.decode(
        _frameOf([
          _reply(1, error: {'code': 109, 'message': 'first'}),
          _reply(2, error: {'code': 110, 'message': 'second'}),
        ]),
        channel: '123456',
      );
      expect(both.refusal, 'connect: 109 first', reason: 'the first refusal is the one that matters');
      expect(
        PandaliveDanmakuCodec.decode(_reply(2, error: {'code': 1}), channel: '123456').joined,
        isFalse,
        reason: 'a refused subscription is not a join',
      );
    });

    test('a publication of this channel is read, and everything else is not', () {
      PandaliveDanmakuFrame of(String line, {String channel = '123456'}) =>
          PandaliveDanmakuCodec.decode(line, channel: channel);

      final published = of(_push(_message()));
      expect(published.messages.single.text, '안녕');
      expect(
        of(_push(_message()), channel: '999').messages,
        isEmpty,
        reason: 'another broadcaster’s channel is not ours',
      );
      expect(
        of(
          jsonEncode({
            'result': {
              'channel': '123456',
              'type': 'sub',
              'data': {'client': 'x'},
            },
          }),
        ).messages,
        isEmpty,
        reason: 'a join, leave or unsubscribe push carries a type',
      );
      expect(of(jsonEncode({'result': 'not a map'})).messages, isEmpty);
      expect(of(jsonEncode({'channel': '123456'})).messages, isEmpty, reason: 'a reply without an id is not a push');
      expect(
        of(
          jsonEncode({
            'result': {
              'channel': '123456',
              'data': {'offset': 1},
            },
          }),
        ).messages,
        isEmpty,
        reason: 'a publication without its message',
      );
    });

    test('a frame may hold several lines, and a bad one is only itself', () {
      final frame = PandaliveDanmakuCodec.decode(
        _frameOf([
          '',
          '   ',
          'not json',
          '[1,2]',
          _reply(2),
          _push(_message(message: 'one'), offset: 1),
          _push(_message(message: 'two'), offset: 2),
        ]),
        channel: '123456',
      );
      expect(frame.joined, isTrue);
      expect(frame.messages.map((message) => message.text), ['one', 'two'], reason: 'in the order they came');
      expect(frame.messages.map((message) => message.messageId), ['123456:1', '123456:2']);

      expect(PandaliveDanmakuCodec.decode(null, channel: '123456').messages, isEmpty);
      expect(PandaliveDanmakuCodec.decode(12, channel: '123456').messages, isEmpty);
      expect(
        PandaliveDanmakuCodec.decode(utf8.encode(_push(_message())), channel: '123456').messages,
        hasLength(1),
        reason: 'bytes are decoded',
      );
      expect(
        PandaliveDanmakuCodec.decode([0xFF, 0xFF], channel: '123456').messages,
        isEmpty,
        reason: 'malformed bytes are replaced, not thrown',
      );
    });
  });

  group('the chat line', () {
    LiveMessage? of(Object? publication, {String channel = '123456'}) =>
        PandaliveDanmakuCodec.chat(publication, channel: channel);

    test('the four kinds the website writes as chat', () {
      for (final type in PandaliveDanmakuCodec.chatTypes) {
        final message = of(_publication(_message(type: type)))!;
        expect(message.type, LiveMessageType.chat, reason: type);
        expect(message.text, '안녕');
        expect(message.sender?.userName, 'viewers');
        expect(message.sender?.userId, 'user1');
        expect(message.color, LiveMessageColor.white, reason: 'the site does not colour a line');
      }
      expect(of(_publication(_message(type: 'ItemCoin'))), isNull);
      expect(of(_publication(_message(type: 'notice'))), isNull);
      expect(of(_publication(_message(nk: null)))?.sender?.userName, isEmpty);
      expect(of(_publication(_message(id: 42)))?.sender?.userId, '42');
      expect(of({'offset': 1, 'data': 'not a map'}), isNull);
      expect(of('not a map'), isNull);
      expect(
        of({
          'data': {'type': 'chatter', 'message': 'x'},
        })?.messageId,
        isEmpty,
        reason: 'no offset names no line',
      );
      expect(of(_publication(_message(), offset: -1))?.messageId, isEmpty);
      expect(of(_publication(_message(), offset: '42'))?.messageId, isEmpty);
    });

    test('a line without words may be only an emoticon', () {
      expect(of(_publication(_message(message: '  '))), isNull, reason: 'no words and no emoticon');
      expect(
        of(
          _publication(
            _message(
              message: '  ',
              emoticon: {
                'block': {'name': 'pandaS하트다발png'},
              },
            ),
          ),
        )!.text,
        '[pandaS하트다발png]',
      );
      expect(
        of(
          _publication(
            _message(
              message: ' hi ',
              emoticon: {
                'block': {'name': 'ignored'},
              },
            ),
          ),
        )!.text,
        'hi',
        reason: 'words come first',
      );
      expect(
        of(
          _publication(
            _message(
              message: 'x',
              emoticon: {
                'block': {'name': ''},
              },
            ),
          ),
        )!.text,
        'x',
      );
      expect(
        of(
          _publication(
            _message(
              message: '',
              emoticon: {
                'block': <String, Object?>{},
                'inline': {'name': 'a', 'b': 'c'},
              },
            ),
          ),
        )!.text,
        '[a]',
        reason: 'the first emoticon that names itself, of any kind',
      );
      expect(of(_publication(_message(message: '', emoticon: {'block': 'not a map'}))), isNull);
      expect(of(_publication(_message(message: '', emoticon: 'not a map'))), isNull);
    });

    test('the time is the site’s seconds, and its clocks only', () {
      DateTime? at(Object? created) => of(_publication(_message(createdAt: created)))?.sentAt;
      expect(at(1790733600), DateTime.fromMillisecondsSinceEpoch(1790733600 * 1000));
      expect(at('1790733600'), isNull, reason: 'a text time is not read');
      expect(at(0), isNull);
      expect(at(-1), isNull);
      expect(at(8640000000001), isNull, reason: 'beyond any clock');
      expect(at(8640000000000), isNotNull);
      expect(at(null), isNull);
    });
  });
}
