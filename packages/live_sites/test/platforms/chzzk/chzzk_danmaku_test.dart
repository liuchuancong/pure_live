import 'dart:convert';

import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/danmaku/chzzk_danmaku_codec.dart';
import 'package:test/test.dart';

/// A pushed line (`msg`, `uid`, `msgTime`, `msgTypeCode`, `msgStatusType`).
Map<String, Object?> _pushed({
  String text = 'hello',
  String user = 'u1',
  Object? at = 1790733600000,
  Object? type,
  Object? status,
  Map<String, Object?>? extras,
  Map<String, Object?>? profile,
}) => {
  'msg': text,
  'uid': user,
  'msgTime': ?at,
  'msgTypeCode': ?type,
  'msgStatusType': ?status,
  'extras': ?extras,
  'profile': ?profile,
};

/// A recent line (`content`, `userId`, `messageTime`, `messageTypeCode`).
Map<String, Object?> _recent({
  String text = 'hello',
  String user = 'u1',
  Object? at = 1790733600000,
  Object? type,
  Object? status,
  Map<String, Object?>? extras,
  Map<String, Object?>? profile,
}) => {
  'content': text,
  'userId': user,
  'messageTime': ?at,
  'messageTypeCode': ?type,
  'messageStatusType': ?status,
  'extras': ?extras,
  'profile': ?profile,
};

/// One socket frame.
String _cmd(Object? cmd, {Object? body, Object? retCode, Object? retMsg}) =>
    jsonEncode({'cmd': cmd, 'bdy': ?body, 'retCode': ?retCode, 'retMsg': ?retMsg});

List<LiveMessage> _messages(String text, {DateTime? at}) => ChzzkDanmakuCodec.decode(text, receivedAt: at).messages;

LiveMessage? _single(String text, {DateTime? at}) => _messages(text, at: at).singleOrNull;

LiveMessage? _pushedLine(Map<String, Object?> line) => ChzzkDanmakuCodec.line(line);

void main() {
  group('the address of a chat', () {
    test('a chat channel id is base64url and at most sixty-four characters', () {
      expect(ChzzkDanmakuCodec.isChatChannelId('N2l_uf'), isTrue);
      expect(ChzzkDanmakuCodec.isChatChannelId('a' * 64), isTrue);
      expect(ChzzkDanmakuCodec.isChatChannelId('a' * 65), isFalse);
      expect(ChzzkDanmakuCodec.isChatChannelId(''), isFalse);
      expect(ChzzkDanmakuCodec.isChatChannelId('a.b'), isFalse, reason: 'the site never writes a dot');
      expect(ChzzkDanmakuCodec.isChatChannelId('a b'), isFalse);
      expect(ChzzkDanmakuCodec.isChatChannelId('a한'), isFalse);
    });

    test('the token answer must be 200 with something in it', () {
      expect(
        ChzzkDanmakuCodec.accessToken({
          'code': 200,
          'content': {'accessToken': 't'},
        }),
        't',
      );
      expect(
        ChzzkDanmakuCodec.accessToken({
          'code': 200,
          'content': {'accessToken': ''},
        }),
        isNull,
      );
      expect(
        ChzzkDanmakuCodec.accessToken({
          'code': 401,
          'content': {'accessToken': 't'},
        }),
        isNull,
      );
      expect(ChzzkDanmakuCodec.accessToken({'code': 200, 'content': <String, Object?>{}}), isNull);
      expect(ChzzkDanmakuCodec.accessToken({'code': 200}), isNull);
      expect(
        ChzzkDanmakuCodec.accessToken({
          'content': {'accessToken': 't'},
        }),
        isNull,
        reason: 'no code',
      );
      expect(
        ChzzkDanmakuCodec.accessToken({
          'code': '200',
          'content': {'accessToken': 't'},
        }),
        isNull,
        reason: 'the code is a number on this API',
      );
    });

    test('the routing answer keeps usable hosts, in order and once each', () {
      List<String>? of(Object? answer) => ChzzkDanmakuCodec.servers(answer);
      expect(
        of({
          'code': 200,
          'result': {
            'sessionServerList': ['a.chat.naver.com', 'b.chat.naver.com'],
          },
        }),
        ['a.chat.naver.com', 'b.chat.naver.com'],
      );
      expect(
        of({
          'code': 200,
          'result': {
            'sessionServerList': ['a.chat.naver.com', 'a.chat.naver.com'],
          },
        }),
        ['a.chat.naver.com'],
      );
      expect(
        of({
          'code': 200,
          'result': {
            'sessionServerList': ['A.chat.naver.com', 'evil.test', 'x.y.chat.naver.com', 7],
          },
        }),
        isNull,
        reason: 'only a lowercase host directly under chat.naver.com counts, and none left is none to try',
      );
      expect(
        of({
          'code': 200,
          'result': {'sessionServerList': <String>[]},
        }),
        isNull,
        reason: 'none to try',
      );
      expect(
        of({
          'code': 500,
          'result': {
            'sessionServerList': ['a.chat.naver.com'],
          },
        }),
        isNull,
      );
      expect(of({'code': 200, 'result': <String, Object?>{}}), isNull);
      expect(of(<String, Object?>{}), isNull);
      final many = [for (var index = 0; index < 40; index++) 's$index.chat.naver.com'];
      expect(
        of({
          'code': 200,
          'result': {'sessionServerList': many},
        }),
        hasLength(ChzzkDanmakuCodec.maxServers),
      );
    });

    test('the sockets go round from the one the last run used', () {
      final hosts = ['a.chat.naver.com', 'b.chat.naver.com', 'c.chat.naver.com'];
      expect(ChzzkDanmakuCodec.endpoints(hosts, 0).map((uri) => uri.host), hosts);
      expect(ChzzkDanmakuCodec.endpoints(hosts, 2).map((uri) => uri.host), [
        'c.chat.naver.com',
        'a.chat.naver.com',
        'b.chat.naver.com',
      ]);
      expect(ChzzkDanmakuCodec.endpoints(hosts, 99).map((uri) => uri.host), [
        'a.chat.naver.com',
        'b.chat.naver.com',
        'c.chat.naver.com',
      ], reason: 'ninety-nine of three rounds back to the first');
      expect(ChzzkDanmakuCodec.endpoints(hosts, 1).first.scheme, 'wss');
      expect(ChzzkDanmakuCodec.endpoints(const [], 0), isEmpty);
    });

    test('the join is read-only and the recent ask names its count', () {
      expect(jsonDecode(ChzzkDanmakuCodec.join('chan', 'tok')), {
        'ver': '3',
        'cmd': 100,
        'svcid': 'game',
        'cid': 'chan',
        'bdy': {'uid': null, 'devType': 2001, 'accTkn': 'tok', 'auth': 'READ'},
        'tid': 1,
      });
      expect(jsonDecode(ChzzkDanmakuCodec.recent('chan', 'sid-1')), {
        'ver': '3',
        'cmd': 5101,
        'svcid': 'game',
        'cid': 'chan',
        'sid': 'sid-1',
        'bdy': {'recentMessageCount': 50},
        'tid': 2,
      });
      expect(ChzzkDanmakuCodec.recentCount, 50);
      expect(ChzzkDanmakuCodec.ping, '{"ver":"3","cmd":0}');
      expect(ChzzkDanmakuCodec.pong, '{"ver":"3","cmd":10000}');
    });

    test('the live state, and only while the live is open', () {
      expect(
        ChzzkDanmakuCodec.liveChatChannel({
          'code': 200,
          'content': {'status': 'OPEN', 'chatChannelId': 'chan'},
        }),
        'chan',
      );
      expect(
        ChzzkDanmakuCodec.liveChatChannel({
          'code': 200,
          'content': {'status': 'CLOSE', 'chatChannelId': 'chan'},
        }),
        isNull,
      );
      expect(
        ChzzkDanmakuCodec.liveChatChannel({
          'code': 200,
          'content': {'status': 'OPEN'},
        }),
        isNull,
      );
      expect(
        ChzzkDanmakuCodec.liveChatChannel({
          'code': 200,
          'content': {'status': 'OPEN', 'chatChannelId': 'a.b'},
        }),
        isNull,
      );
      expect(
        ChzzkDanmakuCodec.liveChatChannel({
          'code': 404,
          'content': {'status': 'OPEN', 'chatChannelId': 'chan'},
        }),
        isNull,
      );
    });

    test('the budgets, the kinds and the cheese', () {
      expect(ChzzkDanmakuCodec.heartbeatInterval, const Duration(seconds: 20));
      expect(ChzzkDanmakuCodec.inactivityTimeout, const Duration(seconds: 30));
      expect(ChzzkDanmakuCodec.joinTimeout, const Duration(seconds: 5));
      expect(ChzzkDanmakuCodec.retryCodes, {302, 303, 304});
      expect(ChzzkDanmakuCodec.defaultServers, isNotEmpty);
      expect(
        ChzzkDanmakuCodec.defaultServers.first.endsWith('.chat.naver.com'),
        isTrue,
        reason: 'the fallback is the site’s own chat host',
      );
      expect(ChzzkDanmakuCodec.handshakeHeaders['user-agent'], ChzzkEndpoints.userAgent);
      expect(ChzzkDanmakuCodec.textType, 1);
      expect(ChzzkDanmakuCodec.donationType, 10);
      expect(ChzzkDanmakuCodec.subscriptionType, 11);
      expect(ChzzkDanmakuCodec.subscriptionGiftType, 12);
      expect(ChzzkDanmakuCodec.systemType, 30);
      expect(ChzzkDanmakuCodec.anonymousDonor, '익명의 후원자');
      expect(ChzzkDanmakuCodec.cheese, '치즈');
      expect(ChzzkDanmakuCodec.cheeseCurrency, 'KRW');
    });

    test('the amount is written the site’s way and shown for its tier', () {
      expect(ChzzkDanmakuCodec.cheeseText(0), '0 치즈');
      expect(ChzzkDanmakuCodec.cheeseText(999), '999 치즈');
      expect(ChzzkDanmakuCodec.cheeseText(1000), '1,000 치즈');
      expect(ChzzkDanmakuCodec.cheeseText(1234567), '1,234,567 치즈');
      expect(ChzzkDanmakuCodec.cheeseText(-2000), '-2,000 치즈');
      expect(ChzzkDanmakuCodec.superChatDuration(9999), const Duration(minutes: 1));
      expect(ChzzkDanmakuCodec.superChatDuration(10000), const Duration(minutes: 2));
      expect(ChzzkDanmakuCodec.superChatDuration(100000), const Duration(minutes: 5));
      expect(ChzzkDanmakuCodec.superChatDuration(500000), const Duration(minutes: 30));
      expect(ChzzkDanmakuCodec.superChatDuration(1000000), const Duration(hours: 1));
    });
  });

  group('one frame', () {
    test('the ping, the close and the join answer', () {
      expect(ChzzkDanmakuCodec.decode(_cmd(0)).ping, isTrue);
      expect(ChzzkDanmakuCodec.decode(_cmd(90102)).closed, isTrue);

      final joined = ChzzkDanmakuCodec.decode(_cmd(10100, body: {'sid': 's-1'}, retCode: 0));
      expect(joined.joined, isTrue);
      expect(joined.sessionId, 's-1');
      expect(joined.refusal, isNull);
      expect(ChzzkDanmakuCodec.decode(_cmd(10100, retCode: 0)).sessionId, isEmpty, reason: 'a body without a sid');
      expect(
        ChzzkDanmakuCodec.decode(_cmd(10100, body: {'sid': 7}, retCode: 0)).sessionId,
        isEmpty,
        reason: 'only text is a session id',
      );

      final refused = ChzzkDanmakuCodec.decode(_cmd(10100, retCode: 200, retMsg: 'bad token'));
      expect(refused.joined, isFalse);
      expect(refused.retry, isFalse);
      expect(refused.refusal, '200 bad token');
      expect(ChzzkDanmakuCodec.decode(_cmd(10100, retCode: 200)).refusal, '200');
      expect(ChzzkDanmakuCodec.decode(_cmd(10100)).refusal, isEmpty, reason: 'no code is no refusal');

      for (final code in ChzzkDanmakuCodec.retryCodes) {
        expect(ChzzkDanmakuCodec.decode(_cmd(10100, retCode: code)).retry, isTrue, reason: '$code');
      }
    });

    test('the pushes give their lines and say they were pushed', () {
      for (final cmd in [93101, 93102]) {
        final frame = ChzzkDanmakuCodec.decode(
          _cmd(
            cmd,
            body: [
              _pushed(text: 'one'),
              _pushed(text: 'two'),
            ],
          ),
        );
        expect(frame.pushed, isTrue, reason: '$cmd');
        expect(frame.messages.map((message) => message.text), ['one', 'two']);
      }
      expect(ChzzkDanmakuCodec.decode(_cmd(93101)).messages, isEmpty, reason: 'no body');
      expect(ChzzkDanmakuCodec.decode(_cmd(93101, body: {'not': 'a list'})).messages, isEmpty);
      expect(
        ChzzkDanmakuCodec.decode(
          _cmd(
            93101,
            body: [
              'not a line',
              _pushed(text: 'kept'),
            ],
          ),
        ).messages.single.text,
        'kept',
      );
    });

    test('the recent answer is its lines then the notice pinned now', () {
      final frame = ChzzkDanmakuCodec.decode(
        _cmd(
          15101,
          retCode: 0,
          body: {
            'messageList': [_recent(text: 'history')],
            'notice': _recent(text: 'pinned words', user: 'u9', at: 111),
          },
        ),
      );
      expect(frame.messages.map((message) => message.text), ['history', '置顶消息：pinned words']);
      expect(frame.messages.last.type, LiveMessageType.notice);
      expect(frame.pushed, isFalse);

      expect(ChzzkDanmakuCodec.decode(_cmd(15101, retCode: 6, body: {'messageList': <Object?>[]})).messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode(_cmd(15101, retCode: 0, body: {'messageList': 'not a list'})).messages, isEmpty);
      expect(
        ChzzkDanmakuCodec.decode(_cmd(15101, retCode: 0, body: {'notice': _recent(at: 111)})).messages,
        isEmpty,
        reason: 'a pinned line without text is not pinned',
      );
    });

    test('a pin made live and a blinding afterwards', () {
      expect(
        _single(
          _cmd(
            94010,
            body: _recent(text: 'pinned', user: 'u9', at: 111),
          ),
        )!.type,
        LiveMessageType.notice,
      );
      expect(_messages(_cmd(94010, body: _recent(text: 'pinned', at: 0))), isEmpty);
      expect(_messages(_cmd(94010, body: 'not a map')), isEmpty);

      final blinded = _single(_cmd(94008, body: {'userId': 'u1', 'messageTime': 111, 'blindType': 'BLIND'}))!;
      expect(blinded.type, LiveMessageType.retraction);
      expect((blinded.payload! as LiveRetraction).messageId, 'u1:111');
      expect(blinded.messageId, isEmpty);
      expect(
        _messages(_cmd(94008, body: {'userId': 'u1', 'messageTime': 111, 'blindType': 'CANCEL'})),
        isEmpty,
        reason: 'the site shows the line again, which cannot be undone here',
      );
    });

    test('everything else, and everything unreadable, holds nothing', () {
      for (final cmd in [10000, 5101, 93006, 94005, 94015, 'x', null]) {
        expect(ChzzkDanmakuCodec.decode(_cmd(cmd, body: [_pushed()])).messages, isEmpty, reason: '$cmd');
      }
      expect(ChzzkDanmakuCodec.decode('not json').messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode('[1,2]').messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode(null).messages, isEmpty);
      expect(ChzzkDanmakuCodec.decode(utf8.encode(_cmd(0))).ping, isTrue, reason: 'bytes are decoded');
      expect(ChzzkDanmakuCodec.decode([0xFF, 0xFF]).messages, isEmpty, reason: 'malformed bytes are replaced');
    });
  });

  group('the two spellings of a line', () {
    test('a pushed line is read by its short names, a recent one by its long', () {
      expect(ChzzkDanmakuCodec.line(_pushed())!.messageId, 'u1:1790733600000');
      expect(ChzzkDanmakuCodec.line(_recent(), recent: true)!.messageId, 'u1:1790733600000');
      expect(ChzzkDanmakuCodec.line(_pushed(), recent: true), isNull, reason: 'the recent names are absent');
      expect(ChzzkDanmakuCodec.line(_recent()), isNull, reason: 'the pushed names are absent');
      expect(ChzzkDanmakuCodec.line(_recent(), recent: true)!.sender?.userId, 'u1');
    });

    test('a status the site does not show hides the line', () {
      expect(_pushedLine(_pushed(status: 'NORMAL')), isNotNull);
      expect(_pushedLine(_pushed(status: 'BLIND')), isNull);
      expect(_pushedLine(_pushed(status: 'CBOTBLIND')), isNull);
      expect(_pushedLine(_pushed(status: 'HIDDEN')), isNull);
      expect(_pushedLine(_pushed()), isNotNull, reason: 'no status is the site’s normal one');
      expect(ChzzkDanmakuCodec.line(_recent(status: 'BLIND')), isNull);
    });

    test('the time is milliseconds, in whichever shape the site sent it', () {
      DateTime? at(Object? value) => _pushedLine(_pushed(at: value))?.sentAt;
      expect(at(1790733600000), DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(at('1790733600000'), DateTime.fromMillisecondsSinceEpoch(1790733600000), reason: 'text digits');
      expect(at(1790733600000.0), DateTime.fromMillisecondsSinceEpoch(1790733600000), reason: 'a whole double');
      expect(at(1790733600000.5), isNull, reason: 'a fractional time is not read');
      expect(at(0), isNull);
      expect(at(-1), isNull);
      expect(at(8640000000000001), isNull);
      expect(at(null), isNull);
      expect(at('x'), isNull);
    });

    test('a line without a user, a time, or text claims no id', () {
      expect(_pushedLine(_pushed(user: ''))!.messageId, isEmpty);
      expect(_pushedLine(_pushed(at: null))!.messageId, isEmpty);
      expect(_pushedLine(_pushed(text: '   ')), isNull, reason: 'nothing to show');
      expect(_pushedLine(_pushed(text: ' x '))!.text, 'x', reason: 'trimmed');
      expect(_pushedLine(_pushed(type: 99)), isNull, reason: 'an unknown kind is not shown');
    });

    test('a system line says its title and its description, unless it is for the streamer', () {
      final notice = _pushedLine(_pushed(type: 30, text: '이모티콘 모드 ON'))!;
      expect(notice.type, LiveMessageType.notice);
      expect(notice.text, '이모티콘 모드 ON');
      expect(notice.payload, LiveNoticeKind.system);
      expect(_pushedLine(_pushed(type: 30, text: 'title', extras: {'description': 'beneath'}))!.text, 'title：beneath');
      expect(_pushedLine(_pushed(type: 30, text: '', extras: {'description': 'only that'}))!.text, 'only that');
      expect(_pushedLine(_pushed(type: 30, text: '', extras: {'visibleRoles': <Object?>[]})), isNull);
      expect(
        _pushedLine(
          _pushed(
            type: 30,
            text: 'x',
            extras: {
              'visibleRoles': ['STREAMER'],
            },
          ),
        ),
        isNull,
        reason: 'this client is anonymous',
      );
      expect(_pushedLine(_pushed(type: 30, text: '')), isNull, reason: 'nothing to say');
    });

    test('a subscription gift names the giver, the pass and who receives it', () {
      LiveMessage? gift(Map<String, Object?> extras, {String user = 'g1', Map<String, Object?>? profile}) =>
          _pushedLine(_pushed(type: 12, text: '구독권 선물', user: user, extras: extras, profile: profile));

      expect(
        gift({'giftType': 'SUBSCRIPTION_GIFT', 'quantity': 5, 'giftTierName': '팬'}, profile: {'nickname': 'Ann'})!.text,
        'Ann 向频道赠送了 5 张「팬」订阅券',
      );
      expect(
        gift({'giftType': 'SUBSCRIPTION_GIFT', 'quantity': 5, 'anonymousToken': 'x'})!.text,
        '익명의 후원자 向频道赠送了 5 张订阅券',
        reason: 'a channel gift carrying the anonymous token has no named giver',
      );
      expect(
        gift({'giftType': 'SUBSCRIPTION_GIFT', 'quantity': 0}, profile: {'nickname': 'Ann'})!.text,
        'Ann 向频道赠送了订阅券',
        reason: 'no quantity: the pass alone',
      );
      expect(
        gift({'receiverNickname': 'Bea', 'giftTierName': '팬'}, profile: {'nickname': 'Ann'})!.text,
        'Ann 向 Bea 赠送了「팬」订阅券',
      );
      expect(
        gift({'receiverNickname': 'Bea'})!.text,
        '익명의 후원자 向 Bea 赠送了订阅券',
        reason: 'a gift to a viewer with no profile is shown anonymous',
      );
      expect(gift({'receiverNickname': 'Bea'}, user: 'anonymous')!.sender?.userId, isEmpty);
      expect(gift({})!.text, '익명의 후원자 赠送了订阅券', reason: 'no receiver named');
      expect(
        gift({'receiverNickname': 'Bea'}, profile: {'nickname': ' '})!.text,
        '向 Bea 赠送了订阅券',
        reason: 'a giver with no name is not repeated in the sentence',
      );
      expect(gift({'receiverNickname': 'Bea'})!.payload, LiveNoticeKind.giftedSubscription);
    });
  });

  group('the pinned line, the blinding and the emotes', () {
    test('the pin says who pinned it', () {
      LiveMessage? pinOf(Map<String, Object?>? notice) => ChzzkDanmakuCodec.pinned(notice);
      expect(pinOf(null), isNull);
      expect(
        pinOf(_recent(text: 'x', user: 'u9', at: 111))!.text,
        '置顶消息：x',
        reason: 'no profile names no author',
      );
      expect(pinOf(_recent(text: 'x', user: 'u9', at: 111, profile: {'nickname': 'Ann'}))!.text, 'Ann 置顶了消息：x');
      expect(
        pinOf({
          'content': 'x',
          'messageTime': 111,
          'userId': 'u9',
          'profile': {'nickname': 'Ann', 'userIdHash': 'h1'},
          'extras': {
            'registerProfile': {'nickname': 'Mod', 'userIdHash': 'h1'},
          },
        })!.text,
        'Ann 置顶了消息：x',
        reason: 'the same hash is the author pinning their own line',
      );
      expect(
        pinOf({
          'content': 'x',
          'messageTime': 111,
          'userId': 'u9',
          'profile': {'nickname': 'Ann', 'userIdHash': 'h1'},
          'extras': {
            'registerProfile': {'nickname': 'Mod', 'userIdHash': 'h2'},
          },
        })!.text,
        'Mod 置顶了 Ann 的消息：x',
      );
      expect(pinOf({'content': 'x', 'messageTime': 111})!.text, '置顶消息：x', reason: 'the site names no author');
      expect(pinOf({'content': 'x', 'messageTime': 111})!.messageId, 'notice:111');
      expect(pinOf(_recent(text: 'x', user: 'u9', at: 111))!.messageId, 'notice:u9:111');
      expect(
        pinOf(_recent(text: 'x', user: 'u9', at: 0)),
        isNull,
        reason: 'the site’s “nothing pinned” has no time',
      );
      expect(
        ChzzkDanmakuCodec.pinned(_recent(text: 'x', user: 'u9', at: 111)),
        isNotNull,
        reason: 'a pin carries no time of its own',
      );
      expect(ChzzkDanmakuCodec.pinned(_recent(text: 'x', user: 'u9', at: 111))!.sentAt, isNull);
      expect(pinOf(_recent(text: '  ', user: 'u9', at: 111)), isNull);
      expect(pinOf(_recent(text: 'x', user: 'u9', at: 0)), isNull);
    });

    test('every kind the site hides retracts, and only a named line does', () {
      LiveMessage? blindOf(Map<String, Object?>? body) => ChzzkDanmakuCodec.blind(body);
      for (final kind in ['BLIND', 'CBOTBLIND', 'HIDDEN', null]) {
        expect(blindOf({'userId': 'u1', 'messageTime': 111, 'blindType': kind}), isNotNull, reason: '$kind');
        expect(
          (blindOf({'userId': 'u1', 'messageTime': 111, 'blindType': kind})!.payload! as LiveRetraction).messageId,
          'u1:111',
        );
      }
      expect(blindOf({'messageTime': 111}), isNull, reason: 'no user');
      expect(blindOf({'userId': 'u1'}), isNull, reason: 'no time');
      expect(blindOf({'userId': 'u1', 'messageTime': 0}), isNull);
      expect(blindOf({'userId': 'u1', 'messageTime': 8640000000000001}), isNull);
      expect(blindOf({'userId': 'u1', 'messageTime': '111'}), isNotNull, reason: 'text digits are the same clock');
    });

    test('the emoji codes are matched with the line’s own table', () {
      const table = {
        'heart': 'https://static.naver.com/heart.png',
        'sad': 'http://cdn.test/sad.png',
        'no': '/local.png',
      };
      List<String> codesOf(String text) => ChzzkDanmakuCodec.emotes(text, table).map((emote) => emote.code).toList();
      expect(codesOf('a {:heart:} b {:sad:}'), ['{:heart:}', '{:sad:}']);
      expect(codesOf('a {:heart:} and {:heart:}'), ['{:heart:}'], reason: 'each code once');
      expect(codesOf('a {:no:}'), isEmpty, reason: 'only an http(s) picture counts');
      expect(codesOf('a {:unknown:}'), isEmpty);
      expect(codesOf('no codes here'), isEmpty);
      expect(codesOf('{:heart:}'), ['{:heart:}']);
      expect(codesOf('{:he art:}'), isEmpty, reason: 'the code holds no space');
      expect(codesOf('{:}{:heart:}'), ['{:heart:}']);
      expect(ChzzkDanmakuCodec.emotes('a {:heart:}', const {}), isEmpty, reason: 'no table, no pictures');
      expect(ChzzkDanmakuCodec.emotes('a {:heart:}', null), isEmpty);
      expect(ChzzkDanmakuCodec.emotes('a {:heart:}', {'heart': 7}), isEmpty, reason: 'an address is text');
      expect(ChzzkDanmakuCodec.emotes('a {:heart:}', table).first.url, 'https://static.naver.com/heart.png');
      expect(
        _pushedLine(_pushed(text: 'a {:heart:}', extras: {'emojis': table}))!.emotes,
        hasLength(1),
        reason: 'the code stays in the text, as on the site',
      );
    });
  });

  group('a donation', () {
    test('an anonymous donor is the site’s name with no id and no picture', () {
      final paid = _pushedLine(
        _pushed(
          type: 10,
          text: 'go',
          extras: {'payAmount': 5000, 'isAnonymous': true},
          profile: {'nickname': 'Ann', 'profileImageUrl': 'https://pstatic.net/a.jpg'},
        ),
      )!;
      expect(paid.type, LiveMessageType.superChat);
      expect(paid.sender?.userName, ChzzkDanmakuCodec.anonymousDonor);
      expect(paid.sender?.userId, isEmpty);
      final message = paid.payload! as LiveSuperChatMessage;
      expect(message.faceUrl, isEmpty, reason: 'an anonymous donor shows no face');
      expect(message.price.amount, 5000);
      expect(message.price.currency, 'KRW');
      expect(message.price.displayText, '5,000 치즈');
      expect(
        message.endTime!.difference(message.startTime!),
        const Duration(minutes: 1),
        reason: '5,000 cheese is below the first tier',
      );
    });

    test('the user “anonymous” is anonymous too, and a picture off NAVER’s hosts is not one', () {
      LiveMessage? donated(Map<String, Object?> profile, {String user = 'u1', Map<String, Object?>? extras}) =>
          ChzzkDanmakuCodec.line(
            _pushed(type: 10, text: 'x', user: user, profile: profile, extras: extras ?? {'payAmount': 1}),
          );
      String faceOf(String? url) =>
          (donated({'nickname': 'Ann', 'profileImageUrl': url})!.payload! as LiveSuperChatMessage).faceUrl;
      expect(faceOf('https://evil.test/a.jpg'), isEmpty, reason: 'not one of the platform’s hosts');
      expect(faceOf('http://pstatic.net/a.jpg'), isEmpty, reason: 'https only');
      expect(faceOf('https://a.pstatic.net/a.jpg#1'), isEmpty, reason: 'no fragment');
      expect(faceOf('https://a.pstatic.net/a.jpg'), 'https://a.pstatic.net/a.jpg');
      expect(faceOf('https://d1.akamaized.net/a.jpg'), 'https://d1.akamaized.net/a.jpg');
      expect(faceOf(null), isEmpty);
      expect(donated({'nickname': 'Ann'}, user: 'anonymous')!.sender?.userName, ChzzkDanmakuCodec.anonymousDonor);
    });

    test('a donation with neither words nor cheese shows nothing, and its window starts at the frame', () {
      final at = DateTime.utc(2026, 11, 5, 12);
      expect(ChzzkDanmakuCodec.line(_pushed(type: 10, text: '  ', at: null)), isNull);
      final paid = ChzzkDanmakuCodec.line(_pushed(type: 10, text: 'x', at: null), receivedAt: at)!;
      final message = paid.payload! as LiveSuperChatMessage;
      expect(paid.sentAt, isNull);
      expect(message.startTime, at);
      expect(message.endTime, at.add(const Duration(minutes: 1)));
      expect(
        (ChzzkDanmakuCodec.line(_pushed(type: 10, text: 'x', extras: {'payAmount': -5}))!.payload!
                as LiveSuperChatMessage)
            .price
            .amount,
        isNull,
        reason: 'a negative amount is read as none, never as a debt',
      );
    });
  });

  group('the line that says someone subscribed', () {
    test("a subscription is the site's notice and its words as chat", () {
      final frame = ChzzkDanmakuCodec.decode(
        _cmd(
          93101,
          body: [
            _pushed(type: 11, text: 'greetings', extras: {'tierName': '팬', 'month': 3}, profile: {'nickname': 'Ann'}),
          ],
        ),
      );
      expect(frame.messages.map((message) => message.type), [
        LiveMessageType.notice,
        LiveMessageType.chat,
      ], reason: 'the line is both what the site announces and what the viewer typed');
      final notice = frame.messages.first;
      expect(notice.text, 'Ann 订阅了「팬」，已订阅 3 个月');
      expect(notice.payload, LiveNoticeKind.subscription);
      expect(notice.effectiveSender.userId, 'u1');
      expect(notice.effectiveSender.userName, 'Ann');
      expect(notice.messageId, 'subscription:u1:1790733600000', reason: 'never the id of its own chat twin');
      expect(notice.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(frame.messages.last.text, 'greetings');
      expect(frame.messages.last.messageId, 'u1:1790733600000');
    });

    test('the tier and the months say only what the line carries', () {
      String textOf(Map<String, Object?> extras, {Map<String, Object?>? profile}) =>
          ChzzkDanmakuCodec.subscription(_pushed(type: 11, extras: extras, profile: profile))!.text;

      expect(textOf({'month': 2}, profile: {'nickname': 'Ann'}), 'Ann 订阅了频道，已订阅 2 个月');
      expect(textOf({'tierName': '팬'}, profile: {'nickname': 'Ann'}), 'Ann 订阅了「팬」');
      expect(textOf({'tierName': '팬', 'month': 0}, profile: {'nickname': 'Ann'}), 'Ann 订阅了「팬」');
      expect(textOf({'month': 'two'}, profile: {'nickname': 'Ann'}), 'Ann 订阅了频道', reason: 'no readable count');
      // The name is the profile's, else the extras' the site writes for a masked viewer.
      expect(textOf({'tierName': '팬', 'nickname': 'Bea'}, profile: {'nickname': '  '}), 'Bea 订阅了「팬」');
      expect(
        ChzzkDanmakuCodec.subscription(_pushed(type: 11, extras: {'tierName': '팬'}))!.text,
        '订阅了「팬」',
        reason: 'nobody named: the notice says what happened, not who',
      );
    });

    test('a subscription the site hides is neither notice nor chat', () {
      for (final status in ['BLIND', 'CBOTBLIND', 'DELETED']) {
        final frame = ChzzkDanmakuCodec.decode(
          _cmd(
            93101,
            body: [
              _pushed(type: 11, text: 'words', status: status, extras: {'tierName': '팬'}),
            ],
          ),
        );
        expect(frame.messages, isEmpty, reason: 'a $status line still carries its text and the site hides it');
      }
      expect(ChzzkDanmakuCodec.subscription(_pushed(type: 11, status: 'BLIND')), isNull);
      expect(
        ChzzkDanmakuCodec.subscription(_pushed(type: 12, extras: {'tierName': '팬'})),
        isNull,
        reason: 'a gift of passes is its own notice',
      );
    });

    test('a subscription in the recent chat is the same line as a pushed one', () {
      final recent = ChzzkDanmakuCodec.decode(
        _cmd(
          15101,
          retCode: 0,
          body: {
            'messageList': [
              _recent(type: 11, text: 'old words', extras: {'tierName': '팬', 'month': 2}, profile: {'nickname': 'Ann'}),
            ],
          },
        ),
      );
      expect(recent.messages.map((message) => message.type), [LiveMessageType.notice, LiveMessageType.chat]);
      expect(recent.messages.first.text, 'Ann 订阅了「팬」，已订阅 2 个月');
      expect(
        recent.messages.first.messageId,
        'subscription:u1:1790733600000',
        reason: 'the recent form names its account and time differently, and the notice must still have them',
      );
      expect(recent.messages.first.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(recent.messages.last.messageId, 'u1:1790733600000');
    });
  });
}
