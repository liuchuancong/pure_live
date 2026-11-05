import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_codec.dart';
import 'package:test/test.dart';

const int _channel = 42;

/// One frame of the chat socket, as the site writes it.
String _frame(Object? root) => jsonEncode(root);

/// A `c`/`ct`/`system` frame of these lines ([moderator] is the site's `c`,
/// which names the audience of a system frame).
String _lines(List<Object?> messages, {String type = 'c', Object? paginated, String? moderator}) =>
    _frame({'type': type, 'messages': messages, 'c': ?moderator, 'paginated': ?paginated});

/// A chat line: `n` name, `u` id, `m` text, `d` time, `k` colour, `id`.
Map<String, Object?> _chatLine({
  String type = 'c',
  Object? text = 'hello',
  Object? name = 'Ann',
  Object? id = 'l1',
  Object? userId = 7,
  Object? at,
  Object? color,
}) => {'t': type, 'm': text, 'n': name, 'u': userId, 'id': ?id, 'd': ?at, 'k': ?color};

/// The messages of one frame of [_channel].
List<LiveMessage> _read(String text, {DateTime? now, String channelName = ''}) =>
    PicartoDanmakuCodec.decode(text, channelId: _channel, channelName: channelName, now: now).messages;

LiveMessage? _one(String text, {DateTime? now, String channelName = ''}) =>
    _read(text, now: now, channelName: channelName).single;

void main() {
  group('the token and the socket', () {
    test('the GraphQL question asks the channel by name', () {
      expect(PicartoDanmakuCodec.tokenBody('Ann'), {
        'query': PicartoDanmakuCodec.tokenQuery,
        'variables': {'name': 'Ann'},
      });
      expect(PicartoDanmakuCodec.tokenQuery, contains(r'generateJwtToken(channel_name: $name)'));
    });

    test('only a real JWT is a token', () {
      String? tokenOf(Object? answer) => PicartoDanmakuCodec.token(answer);
      expect(
        tokenOf({
          'data': {
            'generateJwtToken': {'key': 'aaa.bbb.ccc'},
          },
        }),
        'aaa.bbb.ccc',
      );
      expect(
        tokenOf({
          'data': {
            'generateJwtToken': {'key': 'aaa-b_1.ccc.d-d'},
          },
        }),
        'aaa-b_1.ccc.d-d',
      );
      expect(
        tokenOf({
          'data': {
            'generateJwtToken': {'key': null},
          },
        }),
        isNull,
        reason: 'an unknown channel',
      );
      expect(
        tokenOf({
          'data': {'generateJwtToken': <String, Object?>{}},
        }),
        isNull,
      );
      expect(tokenOf({'data': <String, Object?>{}}), isNull);
      expect(tokenOf(<String, Object?>{}), isNull);
      expect(tokenOf(null), isNull);
      expect(
        tokenOf({
          'data': {
            'generateJwtToken': {'key': 'two.parts'},
          },
        }),
        isNull,
        reason: 'not three parts',
      );
      expect(
        tokenOf({
          'data': {
            'generateJwtToken': {'key': 'aaa.bbb.ccc!'},
          },
        }),
        isNull,
        reason: 'not base64url',
      );
      expect(
        tokenOf({
          'data': {
            'generateJwtToken': {'key': 7},
          },
        }),
        isNull,
      );
    });

    test('the socket address carries the token in its path', () {
      final uri = PicartoDanmakuCodec.endpoint('a.b.c');
      expect(uri.scheme, 'wss');
      expect(uri.host, PicartoEndpoints.chatHost);
      expect(uri.path, '/chat/token=a.b.c');
      expect(PicartoDanmakuCodec.handshakeHeaders, {
        'origin': PicartoEndpoints.origin,
        'user-agent': PicartoEndpoints.userAgent,
      });
    });

    test('the keep-alive and the budgets', () {
      expect(PicartoDanmakuCodec.heartbeat, '{"type":"ping","message":"__ping__"}');
      expect(PicartoDanmakuCodec.heartbeatInterval, const Duration(seconds: 50));
      expect(PicartoDanmakuCodec.silenceTimeout, const Duration(seconds: 150));
      expect(PicartoDanmakuCodec.joinTimeout, const Duration(seconds: 10));
      expect(PicartoDanmakuCodec.tipDuration, const Duration(seconds: 60));
      expect(PicartoDanmakuCodec.refusedCode, 'JWT_TOKEN');
      expect(PicartoDanmakuCodec.maxTokenRefreshes, 3);
      expect(PicartoDanmakuCodec.maxReconnects, 8);
      expect(PicartoDanmakuCodec.tokenAttempts, 3);
      expect(PicartoDanmakuCodec.tokenRetryDelay, const Duration(milliseconds: 500));
      expect(PicartoDanmakuCodec.tokenTimeout, const Duration(seconds: 5));
      expect(PicartoDanmakuCodec.imageBase, 'https://images.picarto.tv/');
      expect(PicartoDanmakuCodec.tipUnit, 'Kudos');
    });
  });

  group('one frame of the socket', () {
    test('a refused token is said, and is not a message', () {
      final frame = PicartoDanmakuCodec.decode(_frame({'success': false, 'code': 'JWT_TOKEN'}), channelId: _channel);
      expect(frame.tokenRefused, isTrue);
      expect(frame.messages, isEmpty);
      expect(
        PicartoDanmakuCodec.decode(_frame({'success': true, 'code': 'PONG'}), channelId: _channel).tokenRefused,
        isFalse,
        reason: 'the keep-alive answer is not a refusal',
      );
      expect(
        PicartoDanmakuCodec.decode(_frame({'success': false, 'code': 'OTHER'}), channelId: _channel).tokenRefused,
        isFalse,
      );
    });

    test('the short spellings of the type and the payload are the same frame', () {
      expect(
        _read(
          _frame({
            't': 'c',
            'm': [_chatLine(text: 'short')],
          }),
        ).single.text,
        'short',
      );
      expect(
        _read(
          _frame({
            't': 'c',
            'messages': [_chatLine(text: 'long')],
          }),
        ).single.text,
        'long',
        reason: 'messages wins, then m',
      );
    });

    test('a page of history is skipped, as the site’s client skips it', () {
      for (final flag in [true, 1, 'yes']) {
        expect(_read(_lines([_chatLine()], paginated: flag)), isEmpty, reason: '$flag');
      }
      expect(_read(_lines([_chatLine()], paginated: false)), hasLength(1), reason: 'false is not a page');
      expect(
        _read(
          _frame({
            't': 'c',
            'p': true,
            'm': [_chatLine()],
          }),
        ),
        isEmpty,
      );
    });

    test('a system frame for moderators only is not shown', () {
      expect(
        _read(
          _lines(
            [
              {'t': 'system', 'm': 'a mod notice'},
            ],
            type: 'system',
            moderator: 'b',
          ),
        ),
        isEmpty,
      );
      expect(
        _read(
          _lines([
            {'t': 'system', 'm': 'a public notice'},
          ], type: 'system'),
        ),
        isNotEmpty,
      );
      expect(
        _read(
          _lines([
            {'m': 'no type at all'},
          ], type: 'system'),
        ),
        isEmpty,
        reason: 'the site shows no line without a type, except in a chat frame',
      );
      expect(
        _read(
          _lines([
            {'m': 'no type at all'},
          ]),
        ),
        hasLength(1),
        reason: 'a chat frame’s typeless line is chat',
      );
    });

    test('an unknown frame, a broken one and a non-object hold nothing', () {
      expect(
        _read(
          _frame({
            'type': 'userlist',
            'messages': [1, 2],
          }),
        ),
        isEmpty,
      );
      expect(_read('not json'), isEmpty);
      expect(_read('[1,2]'), isEmpty);
      expect(
        _read(
          _frame({
            'type': 'c',
            'messages': {'not': 'a list'},
          }),
        ),
        isEmpty,
      );
      expect(_read(_frame({'type': 'ct'})), isEmpty);
      expect(PicartoDanmakuFrame.empty.messages, isEmpty);
    });

    test('a bad field costs that field, and a bad line costs that line', () {
      final messages = _read(
        _lines([_chatLine(text: 7), _chatLine(text: 'kept', at: 'not a time', color: 'nothex', id: 12), 'not a line']),
      );
      expect(messages.map((message) => message.text), ['kept']);
      expect(messages.single.sentAt, isNull, reason: 'a time that is not a number is no time');
      expect(messages.single.color, LiveMessageColor.white, reason: 'a colour that is not hex is white');
      expect(messages.single.messageId, isEmpty, reason: 'an id that is not text names nothing');
    });
  });

  group('chat lines', () {
    test('a chat line carries its name, id, time and colour', () {
      final message = _one(_lines([_chatLine(at: 1790733600000, color: '66AFFF')]))!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, '7');
      expect(message.sender?.nameColor, const LiveMessageColor(0x66, 0xAF, 0xFF));
      expect(message.color, LiveMessageColor.white, reason: 'the text stays white; the name is coloured');
      expect(message.messageId, 'l1');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000));
    });

    test('the id may be the site’s other spelling, and the name a number', () {
      final line = {'t': 'c', 'm': 'x', '_id': 'other', 'n': 12, 'u': null};
      final message = _one(_lines([line]))!;
      expect(message.messageId, 'other', reason: 'id, else _id');
      expect(message.sender?.userName, '12');
      expect(message.sender?.userId, isEmpty);
      expect(
        _one(
          _lines([
            {'t': 'c', 'm': 'x', 'id': 'first', '_id': 'second'},
          ]),
        )!.messageId,
        'first',
      );
    });

    test('a line with no text, another type, or a text that is not text is not shown', () {
      expect(_read(_lines([_chatLine(text: '   ')])), isEmpty);
      expect(_read(_lines([_chatLine(text: null)])), isEmpty);
      expect(_read(_lines([_chatLine(type: 'w')])), isEmpty, reason: 'a whisper is not public chat');
      expect(_read(_lines([_chatLine(type: 'poll')])), isEmpty);
      expect(
        _read(_lines([_chatLine(text: 'x', id: '  ')])),
        hasLength(1),
        reason: 'a blank id is still a line',
      );
    });

    test('a time must be a whole number DateTime can hold', () {
      DateTime? at(Object? value) => _one(_lines([_chatLine(at: value)]))?.sentAt;
      expect(at(1790733600000), DateTime.fromMillisecondsSinceEpoch(1790733600000));
      expect(
        at(1790733600),
        DateTime.fromMillisecondsSinceEpoch(1790733600),
        reason: 'the field is milliseconds: no seconds guess',
      );
      expect(at(0), DateTime.fromMillisecondsSinceEpoch(0), reason: 'only its range is checked, not its meaning');
      expect(at(-1), DateTime.fromMillisecondsSinceEpoch(-1));
      expect(at(1.5), isNull, reason: 'a fractional time is not read');
      expect(at(8640000000000001), isNull, reason: 'beyond any clock');
      expect(at('1790733600000'), isNull, reason: 'only a number is a time here');
    });

    test('the name colour is the site’s hex, in either length, with or without the hash', () {
      LiveMessageColor colorOf(Object? value) => PicartoDanmakuCodec.color(value);
      expect(colorOf('66AFFF'), const LiveMessageColor(0x66, 0xAF, 0xFF));
      expect(colorOf('#66afff'), const LiveMessageColor(0x66, 0xAF, 0xFF));
      expect(colorOf(' 66AFFF '), const LiveMessageColor(0x66, 0xAF, 0xFF), reason: 'trimmed first');
      expect(colorOf('abc'), const LiveMessageColor(0xAA, 0xBB, 0xCC), reason: 'the CSS short form is doubled');
      expect(colorOf('#abc'), const LiveMessageColor(0xAA, 0xBB, 0xCC));
      expect(colorOf('66AFF'), LiveMessageColor.white);
      expect(colorOf('66AFFF7'), LiveMessageColor.white);
      expect(colorOf(''), LiveMessageColor.white);
      expect(colorOf(0x66AFFF), LiveMessageColor.white, reason: 'the site writes it as text');
      expect(colorOf(null), LiveMessageColor.white);
    });

    test('an avatar path gets the site’s prefix, and a full address stays', () {
      expect(PicartoDanmakuCodec.avatar('u/7.png'), 'https://images.picarto.tv/u/7.png');
      expect(PicartoDanmakuCodec.avatar(' https://cdn.test/a.png '), 'https://cdn.test/a.png');
      expect(PicartoDanmakuCodec.avatar('http://cdn.test/a.png'), 'http://cdn.test/a.png');
      expect(PicartoDanmakuCodec.avatar('data:image/png;base64,AAA'), 'data:image/png;base64,AAA');
      expect(PicartoDanmakuCodec.avatar(''), isEmpty);
      expect(PicartoDanmakuCodec.avatar(null), isEmpty);
      expect(PicartoDanmakuCodec.avatar(7), isEmpty);
    });
  });

  group('tips', () {
    test('a tip line is recognised by its chips, under either spelling of the type', () {
      final tipped = _one(
        _lines([
          {'t': 'c', 'm': 'thanks', 'n': 'Ann', 'v': 1, 'x': 120},
        ], type: 'ct'),
      )!;
      expect(tipped.type, LiveMessageType.superChat);
      final chip = _one(
        _frame({
          'type': 'ct',
          'messages': [
            {'t': 'ct', 'm': 'x', 'n': 'Ann', 'x': 3},
          ],
        }),
      )!;
      expect(chip.type, LiveMessageType.superChat);
      expect(chip.text, 'x');
      expect(
        _one(
          _lines([
            {'t': 'c', 'm': 'no chips', 'n': 'Ann'},
          ], type: 'ct'),
        )!.type,
        LiveMessageType.chat,
        reason: 'a ct frame may also carry plain lines',
      );
    });

    test('chips must be a whole number above zero', () {
      for (final chips in <Object?>[null, '120', 0, -5, 1.5]) {
        expect(
          PicartoDanmakuCodec.tip({'t': 'ct', 'n': 'Ann', 'x': chips}, receivedAt: DateTime.utc(2026)),
          isNull,
          reason: 'x: $chips',
        );
      }
    });

    test('a tip without a time starts when the frame came, and lasts the minute', () {
      final now = DateTime.utc(2026, 11, 5, 12);
      final paid = PicartoDanmakuCodec.decode(
        _lines([
          {'t': 'ct', 'n': 'Ann', 'x': 10, 'm': 'hi'},
        ], type: 'ct'),
        channelId: _channel,
        now: now,
      ).messages.single;
      final superChat = paid.payload! as LiveSuperChatMessage;
      expect(paid.sentAt, isNull, reason: 'the line itself is not dated');
      expect(superChat.startTime, now);
      expect(superChat.endTime, now.add(PicartoDanmakuCodec.tipDuration));
    });

    test('a tip to another channel of a multistream says who it is for', () {
      expect(
        _one(
          _lines([
            {'t': 'ct', 'n': 'Ann', 'x': 5, 'rn': 'Bea'},
          ], type: 'ct'),
          channelName: 'ann',
        )!.text,
        '打赏给 Bea',
        reason: 'no words: only the receiver',
      );
      expect(
        _one(
          _lines([
            {'t': 'ct', 'n': 'Ann', 'x': 5, 'rn': 'Bea', 'm': 'go'},
          ], type: 'ct'),
          channelName: 'Bea',
        )!.text,
        'go',
        reason: 'the room is the receiver’s own, case aside',
      );
      expect(
        _one(
          _lines([
            {'t': 'ct', 'n': 'Ann', 'x': 5, 'rn': 'Bea'},
          ], type: 'ct'),
        )!.text,
        '',
        reason: 'without the room’s name nothing is claimed',
      );
    });
  });

  group('the notices', () {
    test('a system notice fills the site’s placeholders and joins its lines', () {
      LiveMessage? systemOf(Map<String, Object?> line) => PicartoDanmakuCodec.system(line);
      expect(
        systemOf({'t': 'system', 'm': 'Welcome to {link}!'})?.text,
        'Welcome to {link}!',
        reason: 'a placeholder stays when its list is missing',
      );
      expect(
        systemOf({
          't': 'system',
          'm': 'a\n  \nb {link} {icon}',
          'ic': <Object?>[],
          'l': [
            null,
            {'text': 'the channel'},
          ],
        })!.text,
        'a b the channel',
      );
      expect(
        systemOf({
          't': 'system',
          'm': '{link} and {link}',
          'l': [
            {'text': 'first'},
            {'text': 'second'},
            {'text': 'third'},
            {'text': 'fourth'},
          ],
        })!.text,
        'second and fourth',
        reason: 'the site counts the pieces around the placeholders',
      );
      expect(
        systemOf({
          't': 'system',
          'm': '{link} {link} {link}',
          'l': [
            {'text': 'only'},
          ],
        })!.text,
        'only only only',
        reason: 'past the list the first link stands in',
      );
      expect(
        systemOf({
          't': 'system',
          'm': '{icon} gone',
          'ic': <Object?>[1],
        })!.text,
        'gone',
      );
      expect(systemOf({'t': 'system', 'm': '  '}), isNull, reason: 'nothing left to say');
      expect(systemOf({'t': 'system', 'm': 7}), isNull, reason: 'text that is not text');
      expect(systemOf({'t': 'system', 'm': 'x'})!.payload, LiveNoticeKind.system);
    });

    test('a raid names itself, or the two channels the server left to say it', () {
      LiveMessage? raidOf(Map<String, Object?> body) => _one(_frame({'type': 'raid', 'messages': body}));
      expect(raidOf({'m': 'RAID from Ann'})?.text, 'RAID from Ann');
      expect(raidOf({'m': '  x  '})?.text, 'x', reason: 'trimmed');
      expect(raidOf({'n': 'Ann', 'rn': 'Bea'})?.text, 'Ann 突袭了 Bea');
      expect(
        _read(
          _frame({
            'type': 'raid',
            'messages': {'n': 'Ann'},
          }),
        ),
        isEmpty,
        reason: 'no channel raided',
      );
      expect(_read(_frame({'type': 'raid', 'messages': 'not a map'})), isEmpty);
      expect(raidOf({'n': 'Ann', 'rn': 'Bea'})!.payload, LiveNoticeKind.raid);
    });

    test('a subscription notice, its months default to one', () {
      final notice = _one(
        _frame({
          'type': 'ns',
          'messages': {'sn': 'Ann', 'n': 'Bea', 'md': '3'},
        }),
      )!;
      expect(notice.text, 'Ann 订阅了 Bea，3 个月');
      expect(notice.payload, LiveNoticeKind.subscription);
      expect(
        _one(
          _frame({
            'type': 'ns',
            'messages': {'sn': 'Ann', 'n': 'Bea'},
          }),
        )!.text,
        'Ann 订阅了 Bea，1 个月',
      );
      expect(
        _read(
          _frame({
            'type': 'ns',
            'messages': {'n': 'Bea'},
          }),
        ),
        isEmpty,
        reason: 'no subscriber',
      );
      expect(
        _read(
          _frame({
            'type': 'ns',
            'messages': {'sn': 'Ann'},
          }),
        ),
        isEmpty,
        reason: 'no channel',
      );
    });

    test('a deletion takes the message back by its id, and a clearance by the user', () {
      final deleted = _one(
        _frame({
          'type': 'rm',
          'messages': {'id': 'l9'},
        }),
      )!;
      expect(deleted.type, LiveMessageType.retraction);
      expect((deleted.payload! as LiveRetraction).messageId, 'l9');
      expect(deleted.messageId, isEmpty, reason: 'a retraction claims no id of its own');
      expect(
        _read(
          _frame({
            'type': 'rm',
            'messages': {'id': '   '},
          }),
        ),
        isEmpty,
      );
      expect(
        _read(
          _frame({
            'type': 'rm',
            'messages': {'id': 9},
          }),
        ),
        isEmpty,
        reason: 'an id that is not text',
      );
      expect(_read(_frame({'type': 'rm', 'messages': <String, Object?>{}})), isEmpty);

      final cleared = _one(
        _frame({
          'type': 'cm',
          'messages': {'u': 'Ann'},
        }),
      )!;
      expect((cleared.payload! as LiveRetraction).userId, 'Ann');
      expect((cleared.payload! as LiveRetraction).messageId, isNull);
      expect(
        _read(
          _frame({
            'type': 'cm',
            'messages': {'u': '  '},
          }),
        ),
        isEmpty,
      );
      expect(
        _read(
          _frame({
            'type': 'cm',
            'messages': {'u': 7},
          }),
        ),
        hasLength(1),
        reason: 'a numeric user is still one',
      );
    });
  });

  group('the audience', () {
    test('a stream frame says who is watching, and only of this channel', () {
      LiveMessage? viewersOf(Map<String, Object?> state) => PicartoDanmakuCodec.decode(
        _frame({'type': 'stream', 'messages': state}),
        channelId: _channel,
      ).messages.singleOrNull;
      final message = viewersOf({'id': _channel, 'viewers': 30})!;
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.kind, LiveAudienceSignalKind.onlineViewers);
      expect(audience.value, 30);
      expect(viewersOf({'viewers': 0}), isNotNull, reason: 'nobody watching is still a figure');
      expect(viewersOf({'id': '42', 'viewers': 1}), isNotNull, reason: 'the id may be written as text');
      expect(viewersOf({'id': 99, 'viewers': 1}), isNull, reason: 'another channel’s state is not ours');
      expect(viewersOf({'viewers': '30'}), isNull, reason: 'a figure written as text is not read');
      expect(viewersOf({'viewers': -1}), isNull);
      expect(viewersOf({'viewers': 1.5}), isNull);
      expect(viewersOf(<String, Object?>{}), isNull);
      expect(
        _read(
          _frame({
            'type': 'stream',
            'messages': {'viewers': 3},
            'paginated': true,
          }),
        ),
        hasLength(1),
        reason: 'the state is read before the page rule, as the site does',
      );
    });
  });
}
