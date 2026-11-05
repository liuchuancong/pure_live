import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_chat_visitor.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';
import 'package:test/test.dart';

const String _room = '123456789';

/// The Base64 of a UTF-8 JSON `payload.content`, as the chat list sends it.
String _content(Map<String, Object?> json) => base64.encode(utf8.encode(jsonEncode(json)));

/// A `10|24` broadcast of a room holding [payload].
Map<String, Object?> _text(Object? payload, {String room = _room, String oriUri = '2584', String seq = '9'}) => {
  'room_id': room,
  'oriUri': oriUri,
  'seqId': seq,
  'payload': payload,
};

/// A frame as the server writes it: the decimal uri, a tab, then the JSON.
String _frame(int uri, Map<String, Object?> body) => '$uri\t${jsonEncode(body)}';

/// The bytes the socket gives for [uri] and [body].
List<int> _bytes(int uri, Map<String, Object?> body) => utf8.encode(_frame(uri, body));

void main() {
  group('the uris and the shapes they come in', () {
    test('a uri is the page\'s toUri("high|low")', () {
      expect(BigoDanmakuCodec.uri(3, 23), BigoDanmakuCodec.pingUri);
      expect(BigoDanmakuCodec.uri(2001, 23), BigoDanmakuCodec.loginUri);
      expect(BigoDanmakuCodec.uri(2002, 23), BigoDanmakuCodec.loginReplyUri);
      expect(BigoDanmakuCodec.uri(5, 24), BigoDanmakuCodec.enterUri);
      expect(BigoDanmakuCodec.uri(6, 24), BigoDanmakuCodec.enterReplyUri);
      expect(BigoDanmakuCodec.uri(42, 24), BigoDanmakuCodec.usersUri);
      expect(BigoDanmakuCodec.uri(43, 24), BigoDanmakuCodec.usersReplyUri);
      expect(BigoDanmakuCodec.uri(10, 24), BigoDanmakuCodec.textUri);
      expect(BigoDanmakuCodec.uri(40, 24), BigoDanmakuCodec.audienceUri);
    });

    test('everything before the first brace is the uri, however it is spaced', () {
      for (final frame in [
        _frame(BigoDanmakuCodec.challengeUri, {'challenge': 'abc'}),
        '${BigoDanmakuCodec.challengeUri}{"challenge":"abc"}',
        '\x00 ${BigoDanmakuCodec.challengeUri}\t\n{"challenge":"abc"}',
        '${BigoDanmakuCodec.challengeUri} \t{"challenge":"abc"}',
      ]) {
        expect(BigoDanmakuCodec.decode(frame, roomId: _room).challenge, 'abc', reason: '$frame is one challenge');
      }
      // The same frame as UTF-8 bytes, as a binary WebSocket frame would give it.
      expect(
        BigoDanmakuCodec.decode(_bytes(BigoDanmakuCodec.challengeUri, {'challenge': 'abc'}), roomId: _room).challenge,
        'abc',
      );
      // An empty challenge answers nothing, so the join is not asked for.
      for (final body in [
        {'challenge': ''},
        {'challenge': null},
        <String, Object?>{},
        {'challenge': 7},
      ]) {
        final frame = BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.challengeUri, body), roomId: _room);
        expect(frame.challenge, isNull);
        expect(frame.refusal, isNull);
      }
    });

    test('a frame that is not a JSON object gives nothing', () {
      for (final data in <Object?>[
        null,
        7,
        const <int>[],
        'no brace at all',
        '256 not json',
        '256 {',
        '256 {"challenge": ',
        '256 [1,2]',
        '256 "a string"',
        'notanumber{"challenge":"abc"}',
      ]) {
        final frame = BigoDanmakuCodec.decode(data, roomId: _room);
        expect(frame.challenge, isNull, reason: '$data is nothing to answer');
        expect(frame.refusal, isNull);
        expect(frame.messages, isEmpty);
        expect(frame.loggedIn, isFalse);
        expect(frame.entered, isFalse);
      }
    });

    test('a refusal outranks whatever else the frame carries', () {
      for (final body in <Map<String, Object?>>[
        {'info': 'unsigned'},
        {'info': 'unsigned', 'challenge': 'abc'},
        {
          'errUri': '${BigoDanmakuCodec.textUri}',
          'payload': {
            'tag': '1',
            'content': _content({'m': 'x'}),
          },
        },
        {'errUri': 2584, 'res': '200'},
      ]) {
        final frame = BigoDanmakuCodec.decode(_frame(BigoDanmakuCodec.textUri, body), roomId: _room);
        expect(frame.refusal, isNotNull, reason: '$body says the socket is not signed up');
        expect(frame.messages, isEmpty);
        expect(frame.loggedIn, isFalse);
      }
      // A false-ish errUri is not a refusal.
      for (final errUri in <Object?>[null, '', 0, false]) {
        final frame = BigoDanmakuCodec.decode(
          _frame(BigoDanmakuCodec.challengeUri, {'challenge': 'abc', 'errUri': errUri}),
          roomId: _room,
        );
        expect(frame.refusal, isNull, reason: 'errUri $errUri says nothing');
        expect(frame.challenge, 'abc');
      }
      expect(BigoDanmakuCodec.decode(_frame(2584, {'errUri': '791'}), roomId: _room).refusal, 'unsigned: 791');
    });

    test('the join answers are read as the page reads them', () {
      BigoDanmakuFrame decode(int uri, Map<String, Object?> body) =>
          BigoDanmakuCodec.decode(_frame(uri, body), roomId: _room);

      expect(decode(BigoDanmakuCodec.loginReplyUri, {'res': '200'}).loggedIn, isTrue);
      expect(decode(BigoDanmakuCodec.loginReplyUri, {'res': '201'}).refusal, 'login: res 201');
      expect(decode(BigoDanmakuCodec.loginReplyUri, {}).refusal, 'login: res ');
      // Only the text "200" logs in: a JSON number is the server saying it another way.
      final asNumber = decode(BigoDanmakuCodec.loginReplyUri, {'res': 200});
      expect(asNumber.loggedIn, isFalse);
      expect(asNumber.refusal, 'login: res 200');

      expect(decode(BigoDanmakuCodec.enterReplyUri, {'resCode': '200', 'sid': '77'}).entered, isTrue);
      expect(decode(BigoDanmakuCodec.enterReplyUri, {'resCode': '200'}).entered, isFalse);
      for (final sid in ['0', '', <Object?>[], null, 0]) {
        final frame = decode(BigoDanmakuCodec.enterReplyUri, {'resCode': '200', 'sid': sid});
        expect(frame.idle, isTrue, reason: 'sid $sid is a room with no broadcast');
        expect(frame.entered, isFalse);
      }
      expect(decode(BigoDanmakuCodec.enterReplyUri, {'resCode': '500', 'sid': '77'}).refusal, 'enter: resCode 500');
      // Every other frame on this socket (pings, likes, heat, seats) is nothing.
      for (final uri in [BigoDanmakuCodec.pingUri, BigoDanmakuCodec.usersUri, 999999]) {
        final frame = decode(uri, {'res': '200', 'totalUserCount': '10'});
        expect(frame.messages, isEmpty, reason: 'uri $uri is not a room figure');
        expect(frame.refusal, isNull);
      }
    });
  });

  group('a comment line', () {
    test('the text, the name, the level and the id come from the Base64 payload', () {
      final line = BigoDanmakuCodec.chat(
        _text({
          'tag': '1',
          'uid': '1001',
          'grade': '31',
          'content': _content({'n': ' Ann ', 'm': '  hello  '}),
        }),
        roomId: _room,
      )!;
      expect(line.type, LiveMessageType.chat);
      expect(line.text, 'hello');
      expect(line.effectiveSender.userName, 'Ann');
      expect(line.effectiveSender.userId, '1001');
      expect(line.effectiveSender.userLevel, '31');
      expect(line.messageId, '1001:9', reason: 'the same message resent keeps its seqId');
      expect(line.sentAt, isNull, reason: 'payload.timestamp is "0" for every recorded comment');
      // A paid bullet comment is a comment, as the page's chat list shows it.
      final paid = BigoDanmakuCodec.chat(
        _text({
          'tag': '${BigoDanmakuCodec.chatTags.last}',
          'uid': '1001',
          'content': _content({'n': 'Ann', 'm': 'pinned'}),
        }),
        roomId: _room,
      )!;
      expect(paid.text, 'pinned');
    });

    test('a line the page would drop is dropped here too', () {
      for (final payload in <Map<String, Object?>>[
        {},
        {'tag': '1'},
        {
          'tag': '0',
          'content': _content({'m': 'x'}),
        },
        {
          'tag': '3',
          'content': _content({'m': 'x'}),
        },
        {
          'tag': 'one',
          'content': _content({'m': 'x'}),
        },
        {'tag': 1, 'content': 7},
        {'tag': 1, 'content': 'not base64 at all ☃'},
        {'tag': 1, 'content': base64.encode(utf8.encode('[1,2]'))},
        {
          'tag': 1,
          'content': _content({'m': ''}),
        },
        {
          'tag': 1,
          'content': _content({'m': '   '}),
        },
        {
          'tag': 1,
          'content': _content({'m': null}),
        },
      ]) {
        expect(BigoDanmakuCodec.chat(_text(payload), roomId: _room), isNull, reason: '$payload carries no chat');
      }
      expect(
        BigoDanmakuCodec.chat(_text({'tag': 1}, room: '999'), roomId: _room),
        isNull,
        reason: 'another room',
      );
      expect(BigoDanmakuCodec.chat({'room_id': _room, 'payload': 'a string'}, roomId: _room), isNull);
      expect(
        BigoDanmakuCodec.chat({
          'room_id': _room,
          'payload': <Object?>['tag', 1],
        }, roomId: _room),
        isNull,
      );
    });

    test('a payload without padding still decodes, and an unreadable account gives no id', () {
      final unpadded = base64.encode(utf8.encode(jsonEncode({'n': 'Ann', 'm': 'hi'}))).replaceAll('=', '');
      final line = BigoDanmakuCodec.chat(_text({'tag': 1, 'uid': '1001', 'content': unpadded}), roomId: _room)!;
      expect(line.text, 'hi');
      expect(line.messageId, '1001:9');

      // The account is `payload.uid`, else the frame's `from_uid`, else nobody.
      final fromFrame = BigoDanmakuCodec.chat(
        _text({
          'tag': 1,
          'content': _content({'m': 'hi'}),
        }),
        roomId: _room,
      )!;
      expect(fromFrame.effectiveSender.userId, isEmpty);
      expect(fromFrame.messageId, isEmpty, reason: 'a chat with no account cannot be deduplicated');
      final byFallback = BigoDanmakuCodec.chat({
        'room_id': _room,
        'seqId': '9',
        'from_uid': '2002',
        'payload': {
          'tag': 1,
          'uid': 'n/a',
          'content': _content({'m': 'hi'}),
        },
      }, roomId: _room)!;
      expect(byFallback.effectiveSender.userId, '2002');
      expect(byFallback.messageId, '2002:9');
      // A level or a seqId written any other way is not shown as a number.
      final odd = BigoDanmakuCodec.chat(
        _text({
          'tag': 1,
          'uid': '1001',
          'grade': 'VIP31',
          'content': _content({'m': 'hi'}),
        }, seq: 'seq-9'),
        roomId: _room,
      )!;
      expect(odd.effectiveSender.userLevel, isEmpty);
      expect(odd.messageId, isEmpty);
    });
  });

  group('a gift and its line', () {
    test('the payload names the room the gift belongs to, and the frame names the gift', () {
      // `payload.room_id` wins over the frame's own room.
      expect(
        BigoDanmakuCodec.gift(_text({'vgift_name': 'Flower', 'room_id': '999'}), roomId: _room),
        isNull,
        reason: 'the payload says which room was gifted',
      );
      expect(
        BigoDanmakuCodec.gift(_text({'vgift_name': 'Flower', 'room_id': _room}, room: '999'), roomId: _room),
        isNotNull,
      );
      // Only a frame whose own `oriUri` is the gift's animation is read as one.
      final notAGift = BigoDanmakuCodec.decode(
        _frame(
          BigoDanmakuCodec.textUri,
          _text({'oriUri': BigoDanmakuCodec.giftOriUri, 'vgift_name': 'Flower', 'vgift_count': 1}),
        ),
        roomId: _room,
      );
      expect(notAGift.messages, isEmpty, reason: 'the frame says this is a chat broadcast');
      expect(notAGift.giftSender, isNull);

      final zero = BigoDanmakuCodec.gift(
        _text({'oriUri': BigoDanmakuCodec.giftOriUri, 'vgift_name': 'Flower', 'vgift_count': '0', 'send_times': 'x'}),
        roomId: _room,
      )!;
      final gift = zero.giftOrNull! as LiveGift;
      expect(gift.count, 1, reason: 'a gift with no readable count was still given once');
      expect(gift.combo.comboTotal, isNull);
      expect(zero.text, 'Flower x1');
    });

    test('a gift frame the socket sends arrives as one gift, not as chat', () {
      final frame = BigoDanmakuCodec.decode(
        _frame(
          BigoDanmakuCodec.textUri,
          _text({
            'oriUri': BigoDanmakuCodec.giftOriUri,
            'vgift_typeid': '77',
            'vgift_name': 'Flower',
            'vgift_count': 2,
            'send_times': 3,
            'from_uid': '1001',
          }, oriUri: BigoDanmakuCodec.giftOriUri),
        ),
        roomId: _room,
      );
      final line = frame.messages.single;
      expect(line.type, LiveMessageType.gift);
      expect(line.text, 'Flower x2');
      expect((line.payload! as LiveGift).combo.comboTotal, 6);
      expect(frame.giftSender, isNull);

      // The line that follows names the sender, and is not a message of its own.
      final withSender = BigoDanmakuCodec.decode(
        _frame(
          BigoDanmakuCodec.textUri,
          _text({
            'tag': '${BigoDanmakuCodec.giftLineTag}',
            'uid': '1001',
            'grade': '31',
            'content': _content({'n': 'Ann'}),
          }),
        ),
        roomId: _room,
      );
      expect(withSender.giftSender, (userId: '1001', name: 'Ann', level: '31'));
      expect(withSender.messages, isEmpty);
    });

    test('the gift line names nobody that cannot be identified', () {
      expect(
        BigoDanmakuCodec.giftLine(
          _text({
            'tag': '${BigoDanmakuCodec.giftLineTag}',
            'content': _content({'n': 'Ann'}),
          }, room: '999'),
          roomId: _room,
        ),
        isNull,
      );
      final noAccount = BigoDanmakuCodec.giftLine(_text({'tag': BigoDanmakuCodec.giftLineTag}), roomId: _room);
      expect(noAccount, isNull, reason: 'a line with no digits for an account cannot join a gift');
      // A line whose content does not read still gives the account.
      final unreadable = BigoDanmakuCodec.giftLine(
        _text({'tag': BigoDanmakuCodec.giftLineTag, 'uid': '1001', 'grade': '0', 'content': 'not base64 at all ☃'}),
        roomId: _room,
      )!;
      expect(unreadable.name, isEmpty);
      expect(unreadable.userId, '1001');
      expect(unreadable.level, '0');
    });
  });

  group('the audience figure', () {
    test('both frames count concurrent viewers, and only for this room', () {
      LiveAudienceUpdate figure(Map<String, Object?> frame, int uri) =>
          BigoDanmakuCodec.audience(frame, uri: uri, roomId: _room)!.payload! as LiveAudienceUpdate;

      expect(
        figure({'gid': _room, 'totalUserCount': '2472'}, BigoDanmakuCodec.audienceUri).kind,
        LiveAudienceSignalKind.onlineViewers,
      );
      expect(figure({'gid': _room, 'totalUserCount': '2472'}, BigoDanmakuCodec.audienceUri).value, 2472);
      expect(figure({'room_id': _room, 'total': 2513}, BigoDanmakuCodec.usersReplyUri).value, 2513);
      // The 43|24 answer is read by `total`, not by the change frame's key.
      expect(figure({'room_id': _room, 'totalUserCount': '1', 'total': '2'}, BigoDanmakuCodec.usersReplyUri).value, 2);
      for (final frame in <Map<String, Object?>>[
        {},
        {'gid': _room},
        {'gid': _room, 'totalUserCount': '-1'},
        {'gid': _room, 'totalUserCount': '2 4'},
        {'gid': _room, 'totalUserCount': '1.5'},
        {'gid': '999', 'totalUserCount': '10'},
      ]) {
        expect(BigoDanmakuCodec.audience(frame, uri: BigoDanmakuCodec.audienceUri, roomId: _room), isNull);
      }
      expect(
        BigoDanmakuCodec.audience(
          {'gid': _room, 'totalUserCount': '0'},
          uri: BigoDanmakuCodec.audienceUri,
          roomId: _room,
        )!.type,
        LiveMessageType.audienceUpdate,
      );
    });

    test('an audience frame reaches the room through decode', () {
      final frame = BigoDanmakuCodec.decode(
        _frame(BigoDanmakuCodec.audienceUri, {'gid': _room, 'totalUserCount': '2472'}),
        roomId: _room,
      );
      expect(frame.messages.single.type, LiveMessageType.audienceUpdate);
      expect(
        BigoDanmakuCodec.decode(
          _frame(BigoDanmakuCodec.audienceUri, {'gid': '999', 'totalUserCount': '1'}),
          roomId: _room,
        ).messages,
        isEmpty,
      );
    });
  });

  group('what the client writes', () {
    test("the challenge answer is the page's sign over its last eight characters", () {
      final now = DateTime.fromMillisecondsSinceEpoch(1790519893202, isUtc: true);
      final frame = BigoDanmakuCodec.answer('ABCDEFGHIJ12345678', now);
      expect(frame.startsWith('${BigoDanmakuCodec.answerUri}'), isTrue);
      final body = jsonDecode(frame.substring('${BigoDanmakuCodec.answerUri}'.length)) as Map<String, Object?>;
      expect(body.keys, [
        'appId',
        'osType',
        'clientVersion',
        'timeStamp',
        'nonce',
        'reservedForSecurity',
        'appSign',
        'redundancy',
        'sign',
      ]);
      expect(body['timeStamp'], '1790519893', reason: 'the sign is over seconds, not milliseconds');
      final tail = 'ABCDEFGHIJ12345678'.substring(10);
      expect(
        body['sign'],
        md5.convert(utf8.encode('60#4#5#1790519893#1#1#1#1#$tail')).toString(),
        reason: 'the last eight characters are what the server echoes',
      );
      // A short challenge is signed whole.
      final short = jsonDecode(
        BigoDanmakuCodec.answer('AB', now).substring('${BigoDanmakuCodec.answerUri}'.length),
      ) as Map<String, Object?>;
      expect(short['sign'], md5.convert(utf8.encode('60#4#5#1790519893#1#1#1#1#AB')).toString());
    });

    test('login, enter, users and ping put the JSON straight behind the uri', () {
      const visitor = BigoChatVisitor(userId: '1001', token: 'tok', deviceId: 'web_x', userName: 'Ann');
      final now = DateTime.fromMillisecondsSinceEpoch(1790519893202, isUtc: true);
      Map<String, Object?> body(String frame, int uri) {
        final prefix = '$uri';
        expect(frame.startsWith(prefix), isTrue, reason: '$frame is not a $uri');
        return jsonDecode(frame.substring(prefix.length)) as Map<String, Object?>;
      }

      final login = body(BigoDanmakuCodec.login(visitor), BigoDanmakuCodec.loginUri);
      expect(login['uid'], '1001');
      expect(login['cookie'], 'tok');
      expect(login['userName'], 'Ann');
      expect(login['deviceId'], 'web_x');
      expect(login['clientType'], '7', reason: 'client type 7 is the web visitor the page logs in as');
      expect(login['lang'], 'cn');
      expect((login['netConf']! as Map<String, Object?>)['countryCode'], 'CN');

      final enter = body(BigoDanmakuCodec.enter(_room, visitor, now), BigoDanmakuCodec.enterUri);
      expect(enter['roomId'], _room);
      expect(enter['secretKey'], '0', reason: 'a room entered without a password says so');
      expect(enter['seqId'], '1790519893202');
      expect(enter['deviceid'], 'web_x');

      final users = body(
        BigoDanmakuCodec.users(const BigoDanmakuArgs(siteId: 'abc', ownerId: 5, roomId: _room), now),
        BigoDanmakuCodec.usersUri,
      );
      expect(users['roomid'], _room);
      expect(users['uid'], '5');

      final ping = body(BigoDanmakuCodec.ping(now), BigoDanmakuCodec.pingUri);
      expect(ping['seqid'], '1790519893202');
      expect(BigoDanmakuCodec.loginDelay, const Duration(seconds: 1), reason: 'the page waits a second, then logs in');
    });

    test('a device id is web_, a fingerprint hash, six letters and the time', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1790519893202, isUtc: true);
      final first = BigoDanmakuCodec.deviceId(Random(7), now);
      expect(first, matches(RegExp(r'^web_[0-9a-f]{32}_[0-9A-Za-z]{6}_1790519893202$')));
      expect(first, BigoDanmakuCodec.deviceId(Random(7), now), reason: 'one seed is one device');
      expect(first, isNot(BigoDanmakuCodec.deviceId(Random(8), now)));
    });

    test('the visitor account is read from the link answer, or refused', () {
      final answer = {
        'code': 0,
        'data': {'userId': '1001', 'uidToken': 'tok###VER2', 'userName': 'Ann', 'deviceId': 'web_x'},
      };
      final visitor = BigoDanmakuCodec.visitor(jsonEncode(answer), status: 200, deviceId: 'mine');
      expect(visitor.userId, '1001');
      expect(visitor.token, 'tok', reason: 'the page strips the version marker');
      expect(visitor.userName, 'Ann');
      expect(visitor.deviceId, 'web_x');

      // The names and ids that will not survive a JSON frame are replaced.
      final odd = BigoDanmakuCodec.visitor(
        jsonEncode({
          'code': 0,
          'data': {'userId': '1001', 'uidToken': 'tok', 'userName': 'a ☃ name', 'deviceId': 'a space'},
        }),
        status: 200,
        deviceId: 'mine',
      );
      expect(odd.userName, '0');
      expect(odd.deviceId, 'mine', reason: 'the page keeps the device id it asked with');

      Map<String, Object?> withData(Map<String, Object?> data) => {'code': 0, 'data': data};
      for (final body in [
        jsonEncode(withData({'userId': 'abc', 'uidToken': 'tok'})),
        jsonEncode(withData({'userId': '1001'})),
        jsonEncode(withData({'userId': '1001', 'uidToken': 'a space'})),
        jsonEncode(withData({'userId': '1001', 'uidToken': '###VER2'})),
        jsonEncode({
          'code': 500,
          'data': {'userId': '1001', 'uidToken': 'tok'},
        }),
        jsonEncode({
          'data': {'userId': '1001', 'uidToken': 'tok'},
        }),
        jsonEncode([1, 2]),
        'not json',
      ]) {
        expect(
          () => BigoDanmakuCodec.visitor(body, status: 200, deviceId: 'mine'),
          throwsA(isA<FormatException>()),
          reason: '$body hands no account',
        );
      }
      expect(
        () => BigoDanmakuCodec.visitor(jsonEncode(answer), status: 500, deviceId: 'mine'),
        throwsA(isA<FormatException>()),
        reason: 'a refused request is not a visitor',
      );
    });

    test('a room is a Bigo id, a real owner account and a room id of digits', () {
      bool checks({String siteId = 'abc_1', int ownerId = 5, String roomId = _room}) =>
          BigoDanmakuCodec.checks(BigoDanmakuArgs(siteId: siteId, ownerId: ownerId, roomId: roomId));

      expect(checks(), isTrue);
      for (final siteId in ['', '-', 'a' * 65, '☃', 'a b']) {
        expect(checks(siteId: siteId), isFalse, reason: '"$siteId" is not a Bigo id');
      }
      for (final ownerId in [0, -1, 9007199254740992]) {
        expect(checks(ownerId: ownerId), isFalse, reason: 'owner $ownerId is not an account the page can ask for');
      }
      for (final roomId in ['', '0', '0123', 'a', '1' * 21, '1 2']) {
        expect(checks(roomId: roomId), isFalse, reason: '"$roomId" is not a room id');
      }
      expect(checks(roomId: ' 123 '), isTrue, reason: 'the ids are trimmed before they are checked');
    });
  });
}
