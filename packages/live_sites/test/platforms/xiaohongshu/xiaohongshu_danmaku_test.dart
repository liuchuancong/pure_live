import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/xiaohongshu/danmaku/xiaohongshu_danmaku_codec.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:test/test.dart';

const String _room = '570000000000000017';
const XiaohongshuPushIdentity _identity = XiaohongshuPushIdentity(
  sid: 'synthetic-visitor-sid',
  uid: 'synthetic-visitor',
  deviceId: 'synthetic-device',
  fingerprint: 'synthetic-fingerprint',
  userAgent: 'Synthetic browser',
);

Map<String, Object?> _item(
  Map<String, Object?> custom, {
  String room = _room,
  String id = 'synthetic-message',
  Object? ts = 1793753000000,
  bool stringify = true,
}) => {
  'd': base64Encode(
    utf8.encode(
      jsonEncode({
        'roomId': room,
        'roomType': 'LIVE',
        'msgId': id,
        'ts': ?ts,
        'customData': stringify ? jsonEncode(custom) : custom,
      }),
    ),
  ),
};

Map<String, Object?> _chat({String nick = '测试昵称', String text = '真实文本🙂'}) => {
  'type': 'text',
  'profile': {'nickname': nick, 'user_id': 'synthetic-sender'},
  'desc': text,
};

String _push(List<Object?> items, {String biz = 'room'}) => jsonEncode({
  'v': 1,
  't': 4,
  'b': {
    'd': {'biz': biz, 'b': items},
  },
});

List<LiveMessage> _decode(String data) =>
    XiaohongshuDanmakuCodec.messages(XiaohongshuDanmakuCodec.envelope(data) ?? {}, _room);

Map<String, Object?> _sent(String frame) => jsonDecode(frame)! as Map<String, Object?>;

void main() {
  group('frames the session sends', () {
    test('handshake, register, join, pings and the viewing heart are the site’s own', () {
      final handshake = _sent(XiaohongshuDanmakuCodec.handshake('m0', _identity));
      expect(handshake['v'], 1);
      expect(handshake['t'], 2);
      expect(handshake['m'], 'm0');
      final auth = ((handshake['b']! as Map)['d']! as Map)['b']! as Map;
      expect(((handshake['b']! as Map)['d']! as Map)['s'], 0);
      expect(auth['appId'], 'xhs-pc');
      expect((auth['authInfo']! as Map)['sid'], _identity.sid);
      expect((auth['authInfo']! as Map)['uid'], _identity.uid);
      expect((auth['authInfo']! as Map)['domain'], 'red');
      expect((auth['authInfo']! as Map)['authType'], 'generic');
      final device = auth['deviceInfo']! as Map;
      expect(device['deviceId'], _identity.deviceId);
      expect(device['fingerprint'], _identity.fingerprint);
      expect(device['userAgent'], _identity.userAgent);
      expect(jsonEncode(auth), isNot(contains('sendMessage')));

      final register = _sent(XiaohongshuDanmakuCodec.register('m1'));
      expect(((register['b']! as Map)['d']! as Map)['s'], 1);
      expect(((((register['b']! as Map)['d']! as Map)['b']! as Map)['bizInfo']! as Map)['bizName'], 'room');

      final join = _sent(XiaohongshuDanmakuCodec.join('m2', _room));
      expect(((join['b']! as Map)['d']! as Map)['s'], 8);
      final info = (((join['b']! as Map)['d']! as Map)['b']! as Map)['info']! as Map;
      expect(info['roomId'], _room);
      expect(info['roomType'], 'LIVE');

      final control = _sent(XiaohongshuDanmakuCodec.control('m3', 6, {}));
      expect(((control['b']! as Map)['d']! as Map)['s'], 6);
      expect(((control['b']! as Map)['d']! as Map)['b']! as Map, isEmpty);

      final heart = _sent(XiaohongshuDanmakuCodec.viewerHeart('m4', _room, _identity.uid));
      expect(heart['t'], 3);
      final inner = ((heart['b']! as Map)['d']! as Map)['b']! as String;
      final decoded = jsonDecode(utf8.decode(base64Decode(inner)))! as Map<String, Object?>;
      expect(decoded['roomId'], _room);
      expect(decoded['roomType'], 'LIVE');
      final custom = jsonDecode(decoded['customData']! as String)! as Map<String, Object?>;
      expect(custom['type'], 'viewer_heart');
      expect((custom['profile']! as Map)['user_id'], _identity.uid);
    });

    test('the transport heartbeat is the bare text frame', () {
      expect(XiaohongshuDanmakuCodec.transportHeartbeat, '{"v":1,"t":0}');
    });

    test('handshake headers carry the origin and the visitor’s own agent, no cookie', () {
      final headers = XiaohongshuDanmakuCodec.handshakeHeaders(_identity);
      expect(headers['origin'], 'https://www.xiaohongshu.com');
      expect(headers['user-agent'], 'Synthetic browser');
      expect(headers.keys.where((key) => key.toLowerCase() == 'cookie'), isEmpty);
    });
  });

  group('bounded public room decoder', () {
    test('text with actual nickname, masked nickname, Unicode and exact ids', () {
      final messages = _decode(_push([_item(_chat()), _item(_chat(nick: '游****客'), id: 'second', stringify: false)]));
      expect(messages.map((message) => message.sender?.userName), ['测试昵称', '游****客']);
      expect(messages.first.text, '真实文本🙂');
      expect(messages.first.messageId, 'synthetic-message');
      expect(messages.first.sender?.userId, 'synthetic-sender');
      expect(messages.first.sourceRoomId, _room);
      expect(messages.first.type, LiveMessageType.chat);
      expect(messages.first.sentAt, DateTime.fromMillisecondsSinceEpoch(1793753000000, isUtc: true));
    });

    test('one broken item cannot hide following messages; room and service are filtered', () {
      expect(
        _decode(
          _push([
            null,
            {'d': 'invalid base64!'},
            _item(_chat(), room: '570000000000000018'),
            _item(_chat()),
          ]),
        ).length,
        1,
      );
      expect(_decode(_push([_item(_chat())], biz: 'im')), isEmpty);
      expect(_decode('{"v":1,"t":0}'), isEmpty);
    });

    test('the message id falls back to the comment id', () {
      final item = _item(_chat(), id: '');
      final wrapped = jsonDecode(utf8.decode(base64Decode(item['d']! as String)))! as Map<String, Object?>;
      wrapped['msgId'] = '';
      wrapped['customData'] = jsonEncode({..._chat(), 'commentId': 'comment-9'});
      item['d'] = base64Encode(utf8.encode(jsonEncode(wrapped)));
      expect(_decode(_push([item])).single.messageId, 'comment-9');
    });

    test('refresh separates online and cumulative counts; heat and praise are not online', () {
      final messages = _decode(
        _push([
          _item({
            'type': 'refresh',
            'room_data': {'member_count': 0, 'uv': '92', 'hot_value': 900000, 'praise_count': 8000},
          }),
        ]),
      );
      final online = messages[0].payload! as LiveAudienceUpdate;
      final total = messages[1].payload! as LiveAudienceUpdate;
      expect(messages[0].type, LiveMessageType.audienceUpdate);
      expect(online.kind, LiveAudienceSignalKind.onlineViewers);
      expect(online.value, 0);
      expect(total.kind, LiveAudienceSignalKind.totalViewers);
      expect(total.value, 92);
      expect(
        _decode(
          _push([
            _item({
              'type': 'refresh',
              'room_data': {'viewers': 10, 'display_count': 10, 'member_count': -1, 'uv': 'NaN'},
            }),
          ]),
        ),
        isEmpty,
      );
    });

    test('joins, likes and unknown notifications are never fabricated chat', () {
      for (final type in ['audience_join_v2', 'praise', 'follow_emcee', 'light', 'live_banner_resource']) {
        expect(
          _decode(
            _push([
              _item({..._chat(), 'type': type}),
            ]),
          ),
          isEmpty,
        );
      }
    });

    test('oversized and malformed inputs are bounded; invalid time does not lose text', () {
      expect(XiaohongshuDanmakuCodec.envelope('x' * (1024 * 1024 + 1)), isNull);
      expect(XiaohongshuDanmakuCodec.envelope('{'), isNull);
      expect(_decode(_push(List.filled(257, _item(_chat())))), isEmpty);
      expect(
        _decode(
          _push([
            _item(_chat(text: 'x' * 8193)),
            {'d': 'x' * (128 * 1024 + 1)},
          ]),
        ),
        isEmpty,
      );
      expect(_decode(_push([_item(_chat(), ts: 9007199254740991)])).single.sentAt, isNull);
      expect(_decode(_push([_item(_chat(text: ' '))])), isEmpty, reason: 'blank text is not chat');
      expect(_decode(_push([_item(_chat(nick: 'x' * 513))])), isEmpty, reason: 'an overlong name is dropped whole');
    });

    test('the acknowledgement code is the integer in b.a.c of a matched answer', () {
      expect(
        XiaohongshuDanmakuCodec.ackCode(
          jsonDecode('{"v":1,"t":2,"m":"m0","b":{"a":{"c":0}}}')! as Map<Object?, Object?>,
        ),
        0,
      );
      expect(
        XiaohongshuDanmakuCodec.ackCode(
          jsonDecode('{"v":1,"t":2,"m":"m0","b":{"a":{"c":3100001}}}')! as Map<Object?, Object?>,
        ),
        3100001,
      );
      expect(
        XiaohongshuDanmakuCodec.ackCode(
          jsonDecode('{"v":1,"t":2,"m":"m0","b":{"a":{"c":"0"}}}')! as Map<Object?, Object?>,
        ),
        isNull,
      );
      expect(
        XiaohongshuDanmakuCodec.ackCode(jsonDecode('{"v":1,"t":2,"m":"m0","b":{"a":{}}}')! as Map<Object?, Object?>),
        isNull,
      );
      expect(XiaohongshuDanmakuCodec.ackCode(jsonDecode('{"v":1,"t":4,"b":{}}')! as Map<Object?, Object?>), isNull);
    });
  });
}
